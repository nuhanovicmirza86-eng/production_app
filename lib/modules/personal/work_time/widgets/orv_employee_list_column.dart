import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/orv_demo_data.dart';

class OrvEmployeeListColumn extends StatelessWidget {
  const OrvEmployeeListColumn({
    super.key,
    required this.employees,
    required this.selectedId,
    required this.onSelect,
  });

  final List<OrvDemoEmployee> employees;
  final String? selectedId;
  final void Function(OrvDemoEmployee e) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Text('Radnici', style: theme.textTheme.titleSmall),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: _HeaderRow(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: employees.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = employees[i];
                final sel = e.id == selectedId;
                return Material(
                  color: sel
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : null,
                  child: InkWell(
                    onTap: () => onSelect(e),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 6,
                      ),
                      child: Row(
                        children: [
                          _cellId(theme, e),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              e.lastName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.firstName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellId(ThemeData theme, OrvDemoEmployee e) {
    if (e.rowHasDataError) {
      return Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          e.id,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onError,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return SizedBox(
      width: 56,
      child: Text(e.id, style: theme.textTheme.labelSmall),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.labelSmall;
    return Row(
      children: [
        SizedBox(width: 60, child: Text('Oznaka', style: t)),
        Expanded(child: Text('Prezime', style: t)),
        Expanded(child: Text('Ime', style: t)),
      ],
    );
  }
}
