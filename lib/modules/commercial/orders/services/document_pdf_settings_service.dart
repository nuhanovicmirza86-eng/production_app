import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_functions/cloud_functions.dart';



import '../models/document_pdf_settings.dart';



/// Učitavanje iz Firestore; **spremanje** preko Callable `updateCompanyDocumentPdfSettings`

/// (Admin SDK — izbjegava `permission-denied` na webu i drži tanka pravila).

class DocumentPdfSettingsService {

  DocumentPdfSettingsService({

    FirebaseFirestore? firestore,

    FirebaseFunctions? functions,

  }) : _firestore = firestore ?? FirebaseFirestore.instance,

       _functions =

           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');



  final FirebaseFirestore _firestore;

  final FirebaseFunctions _functions;



  Future<DocumentPdfSettings> load(String companyId) async {

    final cid = companyId.trim();

    if (cid.isEmpty) return const DocumentPdfSettings();



    final snap = await _firestore.collection('companies').doc(cid).get();

    final data = snap.data();

    if (data == null) return const DocumentPdfSettings();



    final raw = data['documentPdfSettings'];

    if (raw is! Map) return const DocumentPdfSettings();



    return DocumentPdfSettings.fromMap(Map<String, dynamic>.from(raw));

  }



  Future<void> save({

    required String companyId,

    required DocumentPdfSettings settings,

  }) async {

    final cid = companyId.trim();

    if (cid.isEmpty) {

      throw StateError('companyId je prazan.');

    }



    final res = await _functions

        .httpsCallable('updateCompanyDocumentPdfSettings')

        .call<Map<String, dynamic>>({

          'companyId': cid,

          'documentPdfSettings': settings.toMap(),

        });



    if (res.data['success'] != true) {

      throw StateError('Spremanje postavki dokumenta nije uspjelo.');

    }

  }

}

