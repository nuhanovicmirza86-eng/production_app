import 'package:flutter/material.dart';

import '../../../core/format/ba_formatted_date.dart';
import '../utils/structured_datetime_value.dart';

/// Polje datuma/vremena za structured evidenciju — brzi unos «Sada» + picker s trenutnim vremenom.
class StructuredDateTimeField extends StatelessWidget {
  const StructuredDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.helperText,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool required;
  final bool enabled;
  final String? helperText;

  DateTime get _now => DateTime.now();

  DateTime? get _displayLocal => value?.toLocal();

  void _setNow() {
    onChanged(_now);
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final initial = _displayLocal ?? _now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_now.year - 5),
      lastDate: DateTime(_now.year + 1),
    );
    if (picked == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    onChanged(
      DateTime(
        picked.year,
        picked.month,
        picked.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = _displayLocal;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: const OutlineInputBorder(),
        helperText: helperText,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              display == null
                  ? 'Nije odabrano'
                  : BaFormattedDate.formatDateTime(display),
            ),
          ),
          TextButton(
            onPressed: enabled ? _setNow : null,
            child: const Text('Sada'),
          ),
          TextButton(
            onPressed: enabled ? () => _pickDateTime(context) : null,
            child: const Text('Odaberi'),
          ),
        ],
      ),
    );
  }
}

/// Vrijednost za Firestore payload iz lokalnog [DateTime].
String structuredDateTimePayload(DateTime local) =>
    StructuredDateTimeValue.toPayload(local);
