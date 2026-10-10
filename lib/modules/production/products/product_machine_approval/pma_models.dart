class PmaPlantOption {
  const PmaPlantOption({required this.plantKey, required this.plantName});

  final String plantKey;
  final String plantName;
}

class PmaMachineOption {
  const PmaMachineOption({
    required this.machineId,
    required this.machineCode,
    required this.machineName,
  });

  final String machineId;
  final String machineCode;
  final String machineName;

  String get label {
    if (machineCode.isEmpty) return machineName;
    if (machineName.isEmpty) return machineCode;
    return '$machineCode · $machineName';
  }
}

class PmaApprovalView {
  const PmaApprovalView({
    required this.omNumber,
    required this.revision,
    required this.title,
    required this.statusLabel,
    required this.plantName,
    required this.productScopeLabel,
    required this.products,
    required this.machineScopeLabel,
    required this.machines,
    required this.createdAtLabel,
    required this.creatorLabel,
    this.state = '',
    this.technologyApproverLabel = '',
    this.technologyApprovedAtLabel = '',
    this.qualityApproverLabel = '',
    this.qualityApprovedAtLabel = '',
  });

  final String omNumber;
  final int revision;
  final String title;
  final String statusLabel;
  final String plantName;
  final String productScopeLabel;
  final List<String> products;
  final String machineScopeLabel;
  final List<String> machines;
  final String createdAtLabel;
  final String creatorLabel;
  final String state;
  final String technologyApproverLabel;
  final String technologyApprovedAtLabel;
  final String qualityApproverLabel;
  final String qualityApprovedAtLabel;

  bool get isDraft =>
      !isTechnologyApproved &&
      !isQualityConfirmed &&
      !isQualityReturned &&
      (state == 'draft' || (state.isEmpty && statusLabel == 'Nacrt'));

  bool get isTechnologyApproved =>
      state == 'technology_approved' || statusLabel == 'Tehnologija odobrena';

  bool get isQualityConfirmed =>
      state == 'quality_confirmed' || statusLabel == 'Kvalitet potvrdio';

  bool get isQualityReturned =>
      state == 'cancelled' || statusLabel == 'Otkazano';

  String get technologySignatureLabel => _signatureLabel(
        technologyApproverLabel,
        technologyApprovedAtLabel,
      );

  String get qualitySignatureLabel => _signatureLabel(
        qualityApproverLabel,
        qualityApprovedAtLabel,
      );

  String _signatureLabel(String person, String whenLabel) {
    final when = whenLabel == '—' ? '' : whenLabel;
    if (person.isEmpty) return when;
    if (when.isEmpty) return person;
    return '$person · $when';
  }

  factory PmaApprovalView.fromCallable(Map<String, dynamic> raw) {
    String s(dynamic value) => (value ?? '').toString().trim();
    List<String> labels(dynamic value, String codeKey, String nameKey) {
      if (value is! List) return const [];
      return value.map((item) {
        if (item is! Map) return '';
        final code = s(item[codeKey]);
        final name = s(item[nameKey]);
        if (code.isEmpty) return name;
        if (name.isEmpty) return code;
        return '$code · $name';
      }).where((item) => item.isNotEmpty).toList();
    }

    final creatorName = s(raw['creatorName']);
    final creatorRole = s(raw['creatorRoleLabel']);
    final creator = creatorName.isEmpty
        ? (creatorRole.isEmpty ? '—' : creatorRole)
        : (creatorRole.isEmpty ? creatorName : '$creatorName · $creatorRole');
    final technology = raw['technologyApproval'];
    var technologyName = '';
    var technologyRole = '';
    var technologyAt = '';
    if (technology is Map) {
      technologyName = s(technology['displayName']);
      technologyRole = s(technology['roleLabel']);
      technologyAt = _formatCreatedAt(s(technology['approvedAt']));
    }
    final technologyApprover = technologyName.isEmpty
        ? technologyRole
        : (technologyRole.isEmpty
              ? technologyName
              : '$technologyName · $technologyRole');
    final quality = raw['qualityApproval'];
    var qualityName = '';
    var qualityRole = '';
    var qualityAt = '';
    if (quality is Map) {
      qualityName = s(quality['displayName']);
      qualityRole = s(quality['roleLabel']);
      qualityAt = _formatCreatedAt(s(quality['approvedAt']));
    }
    final qualityApprover = qualityName.isEmpty
        ? qualityRole
        : (qualityRole.isEmpty ? qualityName : '$qualityName · $qualityRole');
    return PmaApprovalView(
      omNumber: s(raw['omNumber']),
      revision: raw['revision'] is num ? (raw['revision'] as num).toInt() : 0,
      title: s(raw['title']),
      statusLabel: s(raw['statusLabel']),
      plantName: s(raw['plantName']),
      productScopeLabel: s(raw['productScopeLabel']),
      products: labels(raw['products'], 'productCode', 'productName'),
      machineScopeLabel: s(raw['machineScopeLabel']),
      machines: labels(raw['machines'], 'machineCode', 'machineName'),
      createdAtLabel: _formatCreatedAt(s(raw['createdAt'])),
      creatorLabel: creator,
      state: s(raw['state']),
      technologyApproverLabel: technologyApprover,
      technologyApprovedAtLabel: technologyAt,
      qualityApproverLabel: qualityApprover,
      qualityApprovedAtLabel: qualityAt,
    );
  }
}

String _formatCreatedAt(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}. ${two(local.hour)}:${two(local.minute)}';
}

class PmaDraftRequest {
  const PmaDraftRequest({
    required this.plantKey,
    required this.productId,
    required this.machineScopeMode,
    required this.machineIds,
  });

  final String plantKey;
  final String productId;
  final String machineScopeMode;
  final List<String> machineIds;
}
