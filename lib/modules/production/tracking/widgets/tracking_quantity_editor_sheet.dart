import 'package:flutter/material.dart';

String _initialQuantityText(double? v) {
  if (v == null || v <= 0) return '';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// Bottom sheet: unos nenegativne količine (za pločice „dobro“ / tip škarta).
///
/// [TextEditingController] živi u [State] bottom sheeta da se ne dispose-a dok
/// ruta još drži zavisnosti (izbjegava assert `_dependents.isEmpty` pri zatvaranju).
Future<double?> openTrackingQuantitySheet(
  BuildContext context, {
  required String title,
  String? hint,
  double? initialValue,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TrackingQuantitySheetBody(
      title: title,
      hint: hint,
      initialValue: initialValue,
    ),
  );
}

class _TrackingQuantitySheetBody extends StatefulWidget {
  final String title;
  final String? hint;
  final double? initialValue;

  const _TrackingQuantitySheetBody({
    required this.title,
    this.hint,
    this.initialValue,
  });

  @override
  State<_TrackingQuantitySheetBody> createState() =>
      _TrackingQuantitySheetBodyState();
}

class _TrackingQuantitySheetBodyState extends State<_TrackingQuantitySheetBody> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: _initialQuantityText(widget.initialValue),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.hint != null && widget.hint!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(widget.hint!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            decoration: const InputDecoration(
              labelText: 'Količina',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final raw = _ctrl.text.trim().replaceAll(',', '.');
              final v = double.tryParse(raw);
              if (v == null || v < 0) return;
              Navigator.pop(context, v);
            },
            child: const Text('Potvrdi'),
          ),
        ],
      ),
    );
  }
}
