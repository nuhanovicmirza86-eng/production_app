import 'package:flutter/material.dart';

import '../planning_session_controller.dart';

/// Brzi filteri poola: chipovi + rok (segment), stroj i segment procesa (dropdown).
class PlanningFiltersBar extends StatelessWidget {
  const PlanningFiltersBar({super.key, required this.session});

  final PlanningSessionController session;

  static const _dueSegments = <int, String>{
    0: 'Svi rokovi',
    3: '≤3 d',
    7: '≤7 d',
    14: '≤14 d',
  };

  int _dueToSegment() {
    final d = session.poolFilterDueWithinDays;
    if (d == null) {
      return 0;
    }
    if (d == 3 || d == 7 || d == 14) {
      return d;
    }
    return 0;
  }

  int? _dueFromSegment(int key) {
    if (key == 0) {
      return null;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = session;
    final anyFilter = s.poolFilterHasMachine ||
        s.poolFilterDueWithinDays != null ||
        s.poolFilterNoMachine ||
        s.poolFilterMachineId != null ||
        s.poolFilterOperationName != null;

    final machineOpts = s.machineFilterOptions;
    final opNames = s.poolDistinctOperationNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Filteri poola', style: t.textTheme.titleSmall),
            const Spacer(),
            if (anyFilter)
              TextButton(
                onPressed: s.isLocked ? null : s.clearPoolFilters,
                child: const Text('Poništi filtere'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Rok (tražena isporuka u manje od N dana od sada, uklj. dospjele).',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: [0, 3, 7, 14].map((k) {
            return ButtonSegment<int>(
              value: k,
              label: Text(_dueSegments[k]!),
            );
          }).toList(),
          showSelectedIcon: false,
          selected: {_dueToSegment()},
          onSelectionChanged: s.isLocked
              ? null
              : (Set<int> n) {
                  final v = n.first;
                  s.setPoolFilterDueWithinDays(_dueFromSegment(v));
                },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            FilterChip(
              label: const Text('Samo s dodijeljenim strojem'),
              selected: s.poolFilterHasMachine,
              onSelected: s.isLocked ? null : s.setPoolFilterHasMachine,
            ),
            FilterChip(
              label: const Text('Bez stroja'),
              selected: s.poolFilterNoMachine,
              onSelected: s.isLocked ? null : s.setPoolFilterNoMachine,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Stroj (nalog)', style: t.textTheme.labelLarge),
        const SizedBox(height: 4),
        InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: s.poolFilterMachineId != null &&
                      machineOpts.any((e) => e.id == s.poolFilterMachineId)
                  ? s.poolFilterMachineId
                  : null,
              hint: const Text('Svi strojevi'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Svi strojevi'),
                ),
                ...machineOpts.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.id,
                    child: Text(e.label, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: s.isLocked || machineOpts.isEmpty
                  ? null
                  : s.setPoolFilterMachineId,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Segment (naziv operacije na nalogu)', style: t.textTheme.labelLarge),
        const SizedBox(height: 4),
        InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: s.poolFilterOperationName != null &&
                      opNames.contains(s.poolFilterOperationName)
                  ? s.poolFilterOperationName
                  : null,
              hint: Text(opNames.isEmpty ? 'Nema podataka u poolu' : 'Svi segmenti'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Svi segmenti'),
                ),
                ...opNames.map(
                  (name) => DropdownMenuItem<String?>(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: s.isLocked || opNames.isEmpty
                  ? null
                  : s.setPoolFilterOperationName,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Work centar, alat, kupac, ERP šifrarnik — mogu u sljedećoj fazi; stroj/segment/rok ovise o poljima proizvodnog naloga u poolu.',
          style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
