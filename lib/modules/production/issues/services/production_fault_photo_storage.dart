import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Jedna slika po kvaru — isti put kao Maintenance [FaultService.createFaultWithPhoto].
class ProductionFaultPhotoStorage {
  ProductionFaultPhotoStorage._();
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int _firestorePhotoUpdateMaxAttempts = 5;
  static const int _firestoreRetryBaseMs = 300;

  /// Nakon uspješnog [putData] + [getDownloadURL], pravila ili mreža ponekad odbiju prvi `update` — retry s backoffom.
  static Future<void> _updateFaultPhotoFieldsWithRetry({
    required String faultId,
    required String photoUrl,
    required String photoPath,
  }) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < _firestorePhotoUpdateMaxAttempts; attempt++) {
      try {
        await FirebaseFirestore.instance.collection('faults').doc(faultId).update({
          'photoUrl': photoUrl,
          'photoPath': photoPath,
        });
        if (attempt > 0) {
          developer.log(
            'photoUrl/photoPath zapisani u Firestore nakon ${attempt + 1}. pokušaja (faultId=$faultId)',
            name: 'ProductionFaultPhoto',
          );
        }
        return;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        final code = e is FirebaseException ? e.code : '';
        developer.log(
          'Firestore update photo polja pokušaj ${attempt + 1}/$_firestorePhotoUpdateMaxAttempts '
          '(faultId=$faultId)${code.isNotEmpty ? ' code=$code' : ''}: $e',
          name: 'ProductionFaultPhoto',
          error: e,
          stackTrace: st,
        );
        if (attempt >= _firestorePhotoUpdateMaxAttempts - 1) break;
        final delayMs = (_firestoreRetryBaseMs * (1 << attempt)).clamp(
          _firestoreRetryBaseMs,
          5000,
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    Error.throwWithStackTrace(
      Exception(
        'Snimanje photoUrl u Firestore nije uspjelo nakon $_firestorePhotoUpdateMaxAttempts pokušaja: $lastError',
      ),
      lastStack ?? StackTrace.current,
    );
  }

  /// Nakon kamere fajl na disku ponekad još nije flushan — drugi `readAsBytes` može pasti ili vratiti 0 bajtova.
  static Future<Uint8List> readBytesWithRetry(
    XFile photo, {
    int maxAttempts = 10,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final b = await photo.readAsBytes();
        if (b.isNotEmpty) return b;
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(Duration(milliseconds: 50 * (attempt + 1)));
    }
    if (lastError != null) {
      throw Exception('Čitanje slike nije uspjelo: $lastError');
    }
    throw Exception('Prazan fajl slike (0 bytes) — pokušaj ponovo za trenut.');
  }

  /// [preloadedBytes] — ako već imaš bajtove iz UI (npr. preview), uvijek ih koristi; izbjegava drugo čitanje s diska.
  static Future<String> uploadFaultPhoto({
    required String faultId,
    required XFile photo,
    Uint8List? preloadedBytes,
  }) async {
    final bytes = (preloadedBytes != null && preloadedBytes.isNotEmpty)
        ? preloadedBytes
        : await readBytesWithRetry(photo);
    if (bytes.isEmpty) {
      throw Exception('Prazan fajl slike.');
    }
    final nameLower = photo.name.toLowerCase();
    String ext = 'jpg';
    if (nameLower.endsWith('.png')) ext = 'png';
    if (nameLower.endsWith('.jpg') || nameLower.endsWith('.jpeg')) ext = 'jpg';

    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final photoPath = 'faults/$faultId/photo_$ts.$ext';
    final ref = _storage.ref().child(photoPath);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await _updateFaultPhotoFieldsWithRetry(
      faultId: faultId,
      photoUrl: url,
      photoPath: photoPath,
    );
    return url;
  }
}
