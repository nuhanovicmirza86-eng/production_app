import 'services/packing_box_service.dart';

/// Ljudski prikaz kutije — bez Firestore ID / UID u UI (IATF / operater).
class PackingBoxDisplayLabel {
  PackingBoxDisplayLabel._();

  static String classificationLabel(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'TRANSPORT':
        return 'Pripremna (transport)';
      case 'PRIMARY':
        return 'Primarna';
      case 'SECONDARY':
        return 'Sekundarna';
      default:
        return raw.trim().isEmpty ? '—' : raw.trim();
    }
  }

  static String title(PackingBoxRecord box) {
    return titleFromLines(lines: box.lines, createdAt: box.createdAt);
  }

  static String titleFromLines({
    required List<PackingBoxLine> lines,
    DateTime? createdAt,
  }) {
    if (lines.isEmpty) {
      if (createdAt != null) {
        return 'Kutija · ${formatDateTime(createdAt)}';
      }
      return 'Kutija priprema';
    }

    final orders = <String>{};
    for (final line in lines) {
      final pn = line.productionOrderCode?.trim();
      if (pn != null && pn.isNotEmpty) orders.add(pn);
    }

    final totalQty = lines.fold<double>(0, (sum, l) => sum + l.qtyGood);
    final unit = lines.first.unit.trim().isEmpty ? 'kom' : lines.first.unit.trim();
    final qtyText = formatQty(totalQty);

    if (orders.length == 1) {
      return 'Kutija · nalog ${orders.first}';
    }

    if (lines.length == 1) {
      final line = lines.first;
      return 'Kutija · ${line.productCode} · $qtyText $unit';
    }

    return 'Kutija · $qtyText $unit · ${lines.length} stavki';
  }

  static String subtitle(PackingBoxRecord box) {
    final parts = <String>[
      '${box.lines.length} ${_stavkaLabel(box.lines.length)}',
      classificationLabel(box.classification),
    ];
    if (box.createdAt != null) {
      parts.add(formatDateTime(box.createdAt!));
    }
    return parts.join(' · ');
  }

  /// Jedna linija sa proizvodom kad postoji jedna stavka (ispod naslova).
  static String? productSummary(PackingBoxRecord box) {
    if (box.lines.length != 1) return null;
    final line = box.lines.first;
    if (line.productCode.isEmpty && line.productName.isEmpty) return null;
    if (line.productName.isEmpty) return line.productCode;
    return '${line.productCode} · ${line.productName}';
  }

  static String formatQty(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  static String formatDateTime(DateTime value) {
    final d = value.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year. $hour:$minute';
  }

  static String _stavkaLabel(int count) {
    if (count == 1) return 'stavka';
    if (count >= 2 && count <= 4) return 'stavke';
    return 'stavki';
  }
}
