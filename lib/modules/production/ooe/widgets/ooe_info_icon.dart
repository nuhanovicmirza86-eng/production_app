import 'package:flutter/material.dart';

/// Kompaktna info ikona: kratki [tooltip] + puni tekst u dijalogu na tap (ne zauzima tijekom rada ekrana).
class OoeInfoIcon extends StatelessWidget {
  const OoeInfoIcon({
    super.key,
    required this.tooltip,
    required this.dialogTitle,
    required this.dialogBody,
    this.iconSize = 20,
  });

  final String tooltip;
  final String dialogTitle;
  final String dialogBody;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: tooltip,
      icon: Icon(
        Icons.info_outline,
        size: iconSize,
        color: scheme.onSurfaceVariant,
      ),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(dialogTitle),
            content: SingleChildScrollView(
              child: Text(
                dialogBody,
                style: const TextStyle(height: 1.4, fontSize: 14),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Zatvori'),
              ),
            ],
          ),
        );
      },
    );
  }
}
