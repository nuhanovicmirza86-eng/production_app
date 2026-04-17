import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Učitana prilagođena etiketa za ispis na stanici.
class CustomTrackingLabelPayload {
  const CustomTrackingLabelPayload({
    required this.bytes,
    required this.contentType,
  });

  final Uint8List bytes;
  final String contentType;
}

/// Upload prilagođene etikete za proizvod (kupčev dizajn / PDF ili slika).
/// Ispis na stanici koristi ovu datoteku ako je postavljena, inače sustavsku etiketu.
class ProductTrackingLabelService {
  ProductTrackingLabelService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const int maxBytes = 10 * 1024 * 1024;

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String _ext(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i < 0) return '';
    return fileName.substring(i).toLowerCase();
  }

  static bool allowedExtension(String ext) {
    return ext == '.pdf' || ext == '.png' || ext == '.jpg' || ext == '.jpeg';
  }

  static String contentTypeForExt(String ext) {
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  /// Sprema datoteku u [companies/{companyId}/products/{productId}/tracking_label/label.{ext}]
  /// i metapodatke na `products/{productId}`.
  Future<void> upload({
    required String companyId,
    required String productId,
    required Uint8List bytes,
    required String fileName,
    required String updatedBy,
  }) async {
    final cid = companyId.trim();
    final pid = productId.trim();
    final by = updatedBy.trim();
    if (cid.isEmpty || pid.isEmpty || by.isEmpty) {
      throw Exception('Nedostaju obavezni podaci za upload.');
    }
    if (bytes.isEmpty) {
      throw Exception('Datoteka je prazna.');
    }
    if (bytes.length > maxBytes) {
      throw Exception('Datoteka je prevelika (najviše 10 MB).');
    }
    final ext = _ext(fileName);
    if (!allowedExtension(ext)) {
      throw Exception('Dozvoljeni formati: PDF, PNG, JPG.');
    }

    final path = 'companies/$cid/products/$pid/tracking_label/label$ext';
    final ref = _storage.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentTypeForExt(ext)),
    );

    await _firestore.collection('products').doc(pid).update({
      'customTrackingLabelStoragePath': path,
      'customTrackingLabelFileName': fileName.trim(),
      'customTrackingLabelContentType': contentTypeForExt(ext),
      'customTrackingLabelUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': by,
    });
  }

  /// Briše datoteku iz Storage i polja na proizvodu.
  Future<void> remove({
    required String productId,
    required String updatedBy,
  }) async {
    final pid = productId.trim();
    final by = updatedBy.trim();
    if (pid.isEmpty || by.isEmpty) {
      throw Exception('Nedostaju obavezni podaci.');
    }

    final doc = await _firestore.collection('products').doc(pid).get();
    final path = _s(doc.data()?['customTrackingLabelStoragePath']);
    if (path.isNotEmpty) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {
        // Datoteka možda već obrisana ručno.
      }
    }

    await _firestore.collection('products').doc(pid).update({
      'customTrackingLabelStoragePath': FieldValue.delete(),
      'customTrackingLabelFileName': FieldValue.delete(),
      'customTrackingLabelContentType': FieldValue.delete(),
      'customTrackingLabelUpdatedAt': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': by,
    });
  }

  /// Učitava bajtove prilagođene etikete ako je postavljena (za ispis).
  static Future<CustomTrackingLabelPayload?> loadForPrint(String productId) async {
    final pid = productId.trim();
    if (pid.isEmpty) return null;

    final doc = await FirebaseFirestore.instance
        .collection('products')
        .doc(pid)
        .get();
    final data = doc.data();
    if (data == null) return null;

    final path = _s(data['customTrackingLabelStoragePath']);
    if (path.isEmpty) return null;

    var ct = _s(data['customTrackingLabelContentType']);
    if (ct.isEmpty) {
      ct = contentTypeForExt(_ext(_s(data['customTrackingLabelFileName'])));
    }

    final ref = FirebaseStorage.instance.ref(path);
    final bytes = await ref.getData(maxBytes);
    if (bytes == null || bytes.isEmpty) return null;

    return CustomTrackingLabelPayload(
      bytes: bytes,
      contentType: ct.isNotEmpty ? ct : 'application/pdf',
    );
  }
}
