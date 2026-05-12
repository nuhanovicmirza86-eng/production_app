import 'package:flutter/material.dart';

bool financeLoadErrorHideTechnicalDetail(Object? error) {
  final s = (error ?? '').toString();
  return s.contains('permission-denied') ||
      s.contains('PERMISSION_DENIED') ||
      s.contains('[cloud_firestore/permission-denied]') ||
      s.contains('Missing or insufficient permissions');
}

/// Korisnički tekst za grešku učitavanja; tehnički detalj samo kroz [showFinanceTechnicalDetailDialog].
String financeUserFacingLoadError(Object? error) {
  final s = (error ?? '').toString();
  if (s.contains('permission-denied') ||
      s.contains('[cloud_firestore/permission-denied]')) {
    return 'Pristup ovim podacima u oblaku trenutno nije dozvoljen. '
        'Često to znači da postavke pristupa na poslužitelju još nisu ažurirane '
        'ili da modul financija nije u pretplati kompanije. Administrator može '
        'provjeriti pretplatu i usklađivanje pristupa; ako ste sigurni da imate '
        'pravo pristupa, pokušajte kasnije ponovo.';
  }
  if (s.contains('PERMISSION_DENIED') || s.contains('403')) {
    return 'Pristup je odbijen. Obratite se administratoru.';
  }
  if (s.contains('unavailable') ||
      s.contains('UNAVAILABLE') ||
      s.contains('network') ||
      s.contains('Network')) {
    return 'Privremena pogreška mreže. Pokušajte ponovo za trenutak.';
  }
  return 'Podaci se trenutno ne mogu učitati.';
}

Future<void> showFinanceTechnicalDetailDialog(
  BuildContext context, {
  required String title,
  required String detail,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SelectableText(
          detail.isEmpty ? '—' : detail,
          style: Theme.of(ctx).textTheme.bodySmall,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Zatvori'),
        ),
      ],
    ),
  );
}

/// Ikona „info” koja otvara tehnički detalj (npr. iznimku).
class FinanceTechnicalInfoIcon extends StatelessWidget {
  const FinanceTechnicalInfoIcon({
    super.key,
    required this.detail,
    this.dialogTitle = 'Tehnički detalj',
  });

  final String detail;
  final String dialogTitle;

  @override
  Widget build(BuildContext context) {
    final d = detail.trim();
    if (d.isEmpty || financeLoadErrorHideTechnicalDetail(d)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Više informacija',
      icon: Icon(
        Icons.info_outline,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: () => showFinanceTechnicalDetailDialog(
        context,
        title: dialogTitle,
        detail: d,
      ),
    );
  }
}
