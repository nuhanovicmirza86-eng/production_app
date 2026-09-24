import 'package:flutter/material.dart';
import 'package:production_app/core/ui/guarded_data_entry_dialog.dart';

/// NOTIF-M1-C3 — zatvaranje akcijske obavijesti bez izvršenja.
Future<String?> showMesInboxCloseWithoutActionDialog(BuildContext context) {
  return showGuardedDataEntryDialog<String>(
    context: context,
    builder: (ctx) => const _CloseWithoutActionDialog(),
  );
}

class _CloseWithoutActionDialog extends StatefulWidget {
  const _CloseWithoutActionDialog();

  @override
  State<_CloseWithoutActionDialog> createState() =>
      _CloseWithoutActionDialogState();
}

class _CloseWithoutActionDialogState extends State<_CloseWithoutActionDialog> {
  static const _presets = <String>[
    'Rok je usklađen',
    'Nalog je završen',
    'Rizik je praćen u planu',
  ];

  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _controller.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (reason.length < 8) {
      setState(() => _error = 'Unesite razlog (najmanje 8 znakova).');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zatvaranje bez akcije'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    label: Text(preset),
                    onPressed: () {
                      _controller.text = preset;
                      setState(() => _error = null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Razlog *',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Potvrdi'),
        ),
      ],
    );
  }
}
