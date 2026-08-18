import 'package:flutter/material.dart';

/// Kanonski operator UX za company / catalog evidence (M1-I4-C2).
///
/// Primjenjuje se na sve nove evidencije: forma prva, pregled spušten,
/// kontrolisani izbor umjesto tipkanja gdje je moguće.
abstract final class OperatorEvidenceUxStandard {
  static const String inspectionLinesTableKey = 'inspection_lines';

  static bool isInspectionLinesTable(String tableKey) =>
      tableKey.trim() == inspectionLinesTableKey;

  /// Kontrolna tačka — vrijednost koja ide u payload (isti string kao label).
  static const List<String> inspectionCheckpointOptions = [
    'Vizuelna kontrola',
    'Dimenzijska kontrola',
    'Boja / nijansa',
    'Površina',
    'Oštećenje',
    'Pakovanje',
    'Oznaka / etiketa',
    'Količina',
    'Drugo',
  ];

  /// Kanonski redoslijed jedinica za operator UI (podskup kataloga + prioritet).
  static const List<String> preferredUnitOrder = [
    'kom',
    'set',
    'kg',
    'm',
    'm2',
    'l',
  ];

  /// Mapiranje katalog `defectReasonCode` → operator label (bez nove backend šeme).
  static const Map<String, String> inspectionDefectReasonLabels = {
    'DIMENZIJA': 'Dimenzija van tolerancije',
    'OŠTEĆENJE': 'Oštećenje površine',
    'BOJA_POVRŠINA': 'Pogrešna boja / nijansa',
    'NEUSKLADEN_BOM': 'Neispravno pakovanje',
    'VIZUELNA_GRESKA': 'Nedostaje oznaka',
    'KONTAMINACIJA': 'Prljavština / kontaminacija',
    'OSTALO': 'Drugo',
  };

  /// Redoslijed razloga u UI.
  static const List<String> inspectionDefectReasonOrder = [
    'DIMENZIJA',
    'OŠTEĆENJE',
    'BOJA_POVRŠINA',
    'NEUSKLADEN_BOM',
    'VIZUELNA_GRESKA',
    'KONTAMINACIJA',
    'OSTALO',
  ];

  static String defectReasonLabel(String code) {
    final c = code.trim();
    return inspectionDefectReasonLabels[c] ?? c;
  }

  /// Jedinice za dropdown: preferred ∩ allowed, zatim ostatak allowed.
  static List<String> orderedUnits(List<String> allowedUnits) {
    final allowed = allowedUnits
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (allowed.isEmpty) {
      return preferredUnitOrder
          .where((u) => u != 'set')
          .toList(growable: false);
    }
    final out = <String>[];
    for (final u in preferredUnitOrder) {
      if (allowed.contains(u)) out.add(u);
    }
    for (final u in allowed) {
      if (!out.contains(u)) out.add(u);
    }
    return out;
  }

  static double? parseQty(String? text) {
    final t = (text ?? '').trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  static String formatQty(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  /// Quick actions za qtyInspected / qtyPass / qtyFail.
  static void applyQtyQuickAction({
    required String action,
    required TextEditingController? inspected,
    required TextEditingController? pass,
    required TextEditingController? fail,
  }) {
    if (inspected == null || pass == null || fail == null) return;
    final key = action.trim().toLowerCase();
    if (key == 'reset') {
      inspected.clear();
      pass.clear();
      fail.clear();
      return;
    }
    final qty = parseQty(inspected.text) ?? 0;
    if (key == 'all_pass' || key == 'sve_prolazi') {
      if (qty <= 0) return;
      pass.text = formatQty(qty);
      fail.text = '0';
      return;
    }
    if (key == 'fail_1' || key == '1_ne_prolazi') {
      if (qty < 1) return;
      fail.text = '1';
      pass.text = formatQty(qty - 1);
      return;
    }
    if (key == 'fail_2' || key == '2_ne_prolazi') {
      if (qty < 2) return;
      fail.text = '2';
      pass.text = formatQty(qty - 2);
      return;
    }
    if (key == 'half' || key == '50_50') {
      if (qty <= 0) return;
      final failN = (qty / 2).floorToDouble();
      final passN = qty - failN;
      pass.text = formatQty(passN);
      fail.text = formatQty(failN);
    }
  }
}

/// Brze tipke ispod qty polja (inspection_lines).
class InspectionQtyQuickActionsBar extends StatelessWidget {
  const InspectionQtyQuickActionsBar({
    super.key,
    required this.enabled,
    required this.onAction,
  });

  final bool enabled;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final actions = <(String, String)>[
      ('all_pass', 'Sve prolazi'),
      ('fail_1', '1 ne prolazi'),
      ('fail_2', '2 ne prolazi'),
      ('half', '50/50'),
      ('reset', 'Reset'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in actions)
            ActionChip(
              label: Text(a.$2),
              onPressed: enabled ? () => onAction(a.$1) : null,
            ),
        ],
      ),
    );
  }
}
