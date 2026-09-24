import 'package:flutter/material.dart';

/// M1-I11-C — info tekstovi za lot / WMS / ručni unos (samo BS u UI).
abstract final class OmpLotTraceabilityHelp {
  static const title = 'Lot i sljedivost';

  /// Puni tekst info ikonice — bez engleskog „Warehouse Management System”.
  static const message = '''
WMS znači sistem za upravljanje skladištem.

WMS lot je lot/šarža koja postoji u skladišnoj evidenciji sistema. Za takav lot sistem može potvrditi materijal, količinu, jedinicu mjere, skladište i status.

Ručni unos lota znači da je operater upisao lot ručno, ali sistem nije potvrdio da taj lot postoji u skladištu.

Ako je BOM stavka označena kao lot-sljediva, lot je obavezan. Ako je stavka označena kao „Bez lota”, lot se ne traži.
''';
}

/// Info ikonica pored polja (Način sljedivosti / WMS lot / Ručni unos / Lot).
class OmpLotTraceabilityHelpIcon extends StatelessWidget {
  const OmpLotTraceabilityHelpIcon({
    super.key,
    this.size = 18,
    this.dense = true,
  });

  final double size;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final iconSize = dense ? (size * 0.95).clamp(14.0, 18.0) : size;
    return IconButton(
      icon: Icon(Icons.info_outline, size: iconSize),
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: dense ? 26 : 32,
        minHeight: dense ? 26 : 32,
      ),
      padding: EdgeInsets.zero,
      tooltip: OmpLotTraceabilityHelp.title,
      style: IconButton.styleFrom(foregroundColor: t.colorScheme.primary),
      onPressed: () {
        showDialog<void>(
          barrierDismissible: false,
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text(OmpLotTraceabilityHelp.title),
            content: const SingleChildScrollView(
              child: SelectableText(OmpLotTraceabilityHelp.message),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Zatvori'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Label + info ikonica (za InputDecoration.label / naslove sekcija).
class OmpLotTraceabilityLabeledTitle extends StatelessWidget {
  const OmpLotTraceabilityLabeledTitle({
    super.key,
    required this.label,
    this.style,
  });

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: style ?? Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const OmpLotTraceabilityHelpIcon(),
      ],
    );
  }
}
