import 'package:cloud_firestore/cloud_firestore.dart';

/// Katalog razloga gubitaka (master). Polja [affectsAvailability] / [affectsPerformance]
/// / [affectsQuality] i [isPlanned] određuju kako se događaj mapira u OOE izračun —
/// bez hardkodiranja po nazivu.
class OoeLossReason {
  final String id;
  final String companyId;
  final String plantKey;
  final String code;
  final String name;
  final String? description;
  final String category;

  final bool isPlanned;
  final bool affectsAvailability;
  final bool affectsPerformance;
  final bool affectsQuality;

  final bool active;
  final int sortOrder;

  /// TPM OEE veliki gubitak — vidi [MesTpmLossKeys] (`mes_tpm_six_losses.dart`).
  /// Ako je null, UI/servis može koristiti heuristiku iz [category].
  final String? tpmLossKey;

  final DateTime createdAt;
  final DateTime updatedAt;

  const OoeLossReason({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.code,
    required this.name,
    this.description,
    required this.category,
    required this.isPlanned,
    required this.affectsAvailability,
    required this.affectsPerformance,
    required this.affectsQuality,
    required this.active,
    required this.sortOrder,
    this.tpmLossKey,
    required this.createdAt,
    required this.updatedAt,
  });

  // Predložene kategorije za MVP (slobodan string u Firestore-u).
  static const String categoryPlannedStop = 'planned_stop';
  static const String categoryUnplannedStop = 'unplanned_stop';
  static const String categorySetupChangeover = 'setup_changeover';
  static const String categoryMaterialWait = 'material_wait';
  static const String categoryOperatorWait = 'operator_wait';
  static const String categoryMaintenance = 'maintenance';
  static const String categoryQualityHold = 'quality_hold';
  static const String categoryMicroStop = 'micro_stop';
  static const String categoryReducedSpeed = 'reduced_speed';
  static const String categoryOther = 'other';

  static String? _trimOrNull(dynamic v) {
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  factory OoeLossReason.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final id = doc.id;
    final map = doc.data();
    if (map == null) {
      return OoeLossReason(
        id: id,
        companyId: '',
        plantKey: '',
        code: '',
        name: '',
        description: null,
        category: categoryOther,
        isPlanned: false,
        affectsAvailability: true,
        affectsPerformance: false,
        affectsQuality: false,
        active: true,
        sortOrder: 0,
        tpmLossKey: null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    return OoeLossReason.fromMap(id, map);
  }

  factory OoeLossReason.fromMap(String id, Map<String, dynamic> map) {
    return OoeLossReason(
      id: id,
      companyId: (map['companyId'] ?? '').toString(),
      plantKey: (map['plantKey'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      description: _trimOrNull(map['description']),
      category: (map['category'] ?? categoryOther).toString(),
      isPlanned: map['isPlanned'] == true,
      affectsAvailability: map['affectsAvailability'] != false,
      affectsPerformance: map['affectsPerformance'] == true,
      affectsQuality: map['affectsQuality'] == true,
      active: map['active'] != false,
      sortOrder: (map['sortOrder'] is num)
          ? (map['sortOrder'] as num).toInt()
          : int.tryParse((map['sortOrder'] ?? '0').toString()) ?? 0,
      tpmLossKey: _trimOrNull(map['tpmLossKey']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'plantKey': plantKey,
      'code': code,
      'name': name,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
      'category': category,
      'isPlanned': isPlanned,
      'affectsAvailability': affectsAvailability,
      'affectsPerformance': affectsPerformance,
      'affectsQuality': affectsQuality,
      'active': active,
      'sortOrder': sortOrder,
      if (tpmLossKey != null && tpmLossKey!.trim().isNotEmpty)
        'tpmLossKey': tpmLossKey!.trim(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
