import 'package:flutter/material.dart';

class WasteReportErrorPanel extends StatelessWidget {
  const WasteReportErrorPanel({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final Object? message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final text = _format(message);
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.error_outline, size: 48, color: t.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: t.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Pokušaj ponovo'),
        ),
      ],
    );
  }
}

String wasteReportErrorMessage(Object? e) {
  return _format(e);
}

String _format(Object? e) {
  if (e == null) {
    return 'Došlo je do greške. Pokušaj ponovo.';
  }
  if (e is StateError) {
    return e.message;
  }
  return 'Došlo je do greške. Provjeri mrežu i pokušaj ponovo.';
}
