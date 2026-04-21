import 'package:flutter/material.dart';

import '../models/machine_state_event.dart';

class OoeTimelineWidget extends StatelessWidget {
  final List<MachineStateEvent> events;

  const OoeTimelineWidget({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text(
        'Nema zapisanih segmenata stanja za ovaj kontekst.',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Column(
      children: events.map((e) {
        final dur = e.durationSeconds;
        final durLabel = dur != null ? '$dur s' : 'otvoren';
        return ListTile(
          dense: true,
          leading: const Icon(Icons.timeline, size: 20),
          title: Text(e.state),
          subtitle: Text(
            '${_fmt(e.startedAt)} → ${_fmt(e.endedAt)} · $durLabel',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: e.reasonCode != null && e.reasonCode!.trim().isNotEmpty
              ? Text(
                  e.reasonCode!,
                  style: const TextStyle(fontSize: 11),
                )
              : null,
        );
      }).toList(),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    final t = d.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
