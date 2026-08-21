/// M1-I3-G — validiran payload za PDF „Odobrenje prvog komada“.
class FirstPieceApprovalReleaseDocument {
  const FirstPieceApprovalReleaseDocument({
    required this.documentTitle,
    required this.releaseBanner,
    required this.disposition,
    required this.dispositionLabel,
    required this.companyId,
    required this.companyName,
    required this.plantKey,
    required this.plantDisplayName,
    required this.processDisplayName,
    required this.sessionId,
    required this.status,
    required this.productCode,
    required this.productName,
    required this.machineName,
    required this.inspectorName,
    required this.inspectionStartedAt,
    required this.inspectionFinishedAt,
    this.processKey,
    this.phaseKey,
    this.productionOrderId,
    this.productionOrderCode,
    this.productId,
    this.productImageUrl,
    this.productImageStoragePath,
    this.machineId,
    this.machineCode,
    this.pieceSerialOrLot,
    this.qtySubmitted,
    this.measurementSummary,
    this.dispositionNote,
    this.endedAt,
    this.createdAt,
    this.startedAt,
    this.createdByDisplayName,
    this.createdByEmail,
    this.operatorDisplayName,
    this.operatorEmail,
    this.catalogVersion,
    this.qmsControlledFormDocumentCode,
    this.qmsControlledFormRevision,
    this.qmsControlledFormStatus,
    this.qmsControlledFormTitle,
  });

  final String documentTitle;
  final String releaseBanner;
  final String disposition;
  final String dispositionLabel;
  final String companyId;
  final String companyName;
  final String plantKey;
  final String plantDisplayName;
  final String processDisplayName;
  final String sessionId;
  final String status;
  final String productCode;
  final String productName;
  final String machineName;
  final String inspectorName;
  final DateTime inspectionStartedAt;
  final DateTime inspectionFinishedAt;
  final String? processKey;
  final String? phaseKey;
  final String? productionOrderId;
  final String? productionOrderCode;
  final String? productId;
  final String? productImageUrl;
  final String? productImageStoragePath;
  final String? machineId;
  final String? machineCode;
  final String? pieceSerialOrLot;
  final double? qtySubmitted;
  final String? measurementSummary;
  final String? dispositionNote;
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final String? createdByDisplayName;
  final String? createdByEmail;
  final String? operatorDisplayName;
  final String? operatorEmail;
  final int? catalogVersion;
  /// M1-I5-C6 — QMS oznaka obrasca (iz fieldValues sesije).
  final String? qmsControlledFormDocumentCode;
  final String? qmsControlledFormRevision;
  final String? qmsControlledFormStatus;
  final String? qmsControlledFormTitle;

  factory FirstPieceApprovalReleaseDocument.fromMap(Map<String, dynamic> m) {
    DateTime? ts(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      if (v is String && v.trim().isNotEmpty) {
        return DateTime.tryParse(v.trim())?.toLocal();
      }
      if (v is Map) {
        final seconds = v['seconds'] ?? v['_seconds'];
        if (seconds is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            (seconds * 1000).round(),
            isUtc: true,
          ).toLocal();
        }
      }
      return null;
    }

    String req(String key) {
      final t = (m[key] ?? '').toString().trim();
      if (t.isEmpty) {
        throw FormatException('Nedostaje polje u release dokumentu: $key');
      }
      return t;
    }

    String? opt(String key) {
      final t = (m[key] ?? '').toString().trim();
      return t.isEmpty ? null : t;
    }

    double? numOpt(String key) {
      final v = m[key];
      if (v is num) return v.toDouble();
      if (v is String && v.trim().isNotEmpty) return double.tryParse(v.trim());
      return null;
    }

    final started = ts(m['inspectionStartedAt']);
    final finished = ts(m['inspectionFinishedAt']);
    if (started == null || finished == null) {
      throw const FormatException(
        'Nedostaju vremena kontrole u release dokumentu.',
      );
    }

    return FirstPieceApprovalReleaseDocument(
      documentTitle: req('documentTitle'),
      releaseBanner: req('releaseBanner'),
      disposition: req('disposition'),
      dispositionLabel: req('dispositionLabel'),
      companyId: req('companyId'),
      companyName: req('companyName'),
      plantKey: (m['plantKey'] ?? '').toString().trim(),
      plantDisplayName: req('plantDisplayName'),
      processDisplayName: req('processDisplayName'),
      sessionId: req('sessionId'),
      status: req('status'),
      productCode: req('productCode'),
      productName: req('productName'),
      machineName: req('machineName'),
      inspectorName: req('inspectorName'),
      inspectionStartedAt: started,
      inspectionFinishedAt: finished,
      processKey: opt('processKey'),
      phaseKey: opt('phaseKey'),
      productionOrderId: opt('productionOrderId'),
      productionOrderCode: opt('productionOrderCode'),
      productId: opt('productId'),
      productImageUrl: opt('productImageUrl'),
      productImageStoragePath: opt('productImageStoragePath'),
      machineId: opt('machineId'),
      machineCode: opt('machineCode'),
      pieceSerialOrLot: opt('pieceSerialOrLot'),
      qtySubmitted: numOpt('qtySubmitted'),
      measurementSummary: opt('measurementSummary'),
      dispositionNote: opt('dispositionNote'),
      endedAt: ts(m['endedAt']),
      createdAt: ts(m['createdAt']),
      startedAt: ts(m['startedAt']),
      createdByDisplayName: opt('createdByDisplayName'),
      createdByEmail: opt('createdByEmail'),
      operatorDisplayName: opt('operatorDisplayName'),
      operatorEmail: opt('operatorEmail'),
      catalogVersion: (m['catalogVersion'] as num?)?.toInt(),
      qmsControlledFormDocumentCode: opt('qmsControlledFormDocumentCode'),
      qmsControlledFormRevision: opt('qmsControlledFormRevision'),
      qmsControlledFormStatus: opt('qmsControlledFormStatus'),
      qmsControlledFormTitle: opt('qmsControlledFormTitle'),
    );
  }
}
