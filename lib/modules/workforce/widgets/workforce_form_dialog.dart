import 'package:flutter/material.dart';

/// Dijalog s akcijama ✕ / ✓ u gornjem desnom uglu (bez donjih tekstualnih gumba).
class WorkforceFormDialog extends StatelessWidget {
  const WorkforceFormDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onSave,
    this.extraActions = const [],
  });

  final String title;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ...extraActions,
                    IconButton(
                      tooltip: 'Odustani',
                      icon: const Icon(Icons.close),
                      onPressed: onCancel,
                    ),
                    IconButton(
                      tooltip: 'Spremi',
                      icon: const Icon(Icons.check),
                      onPressed: onSave,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
