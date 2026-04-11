import 'package:flutter/material.dart';

import '../date/date_range_utils.dart' show formatCalendarDay;

/// Dva datuma (od–do) + očisti; roditelj otvara [showDatePicker] i ažurira stanje.
class DateRangeFilterControls extends StatelessWidget {
  final String sectionTitle;
  final String helpText;
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClear;

  const DateRangeFilterControls({
    super.key,
    required this.sectionTitle,
    required this.helpText,
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          helpText,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onPickFrom,
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('Od: ${formatCalendarDay(from)}'),
            ),
            OutlinedButton.icon(
              onPressed: onPickTo,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('Do: ${formatCalendarDay(to)}'),
            ),
            if (from != null || to != null)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Očisti datume'),
              ),
          ],
        ),
      ],
    );
  }
}
