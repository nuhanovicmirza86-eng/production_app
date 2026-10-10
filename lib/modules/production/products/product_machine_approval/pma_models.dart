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
