import 'package:flutter/material.dart';

/// Zajednički izbornik za pregledne liste: CSV, PDF (sustavski pregled/ispis), dijeljenje PDF datoteke.
///
/// Koristi se npr. na listama proizvodnih naloga i narudžbi — isti tekstovi i ikona.
class ExportListPopupMenu extends StatelessWidget {
  const ExportListPopupMenu({
    super.key,
    required this.enabled,
    required this.onCsv,
    required this.onPdfPreview,
    required this.onPdfShare,
    this.tooltip,
  });

  final bool enabled;
  final VoidCallback onCsv;
  final VoidCallback onPdfPreview;
  final VoidCallback onPdfShare;

  /// Ako nije zadan, koristi se zadani opis u tooltipu.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip ??
          'Izvoz: CSV, PDF (pregled/ispis), slanje PDF-a',
      enabled: enabled,
      icon: const Icon(Icons.file_download_outlined),
      onSelected: (v) {
        switch (v) {
          case 'csv':
            onCsv();
            break;
          case 'pdf':
            onPdfPreview();
            break;
          case 'pdf_share':
            onPdfShare();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'csv',
          child: Text('CSV (tablica)'),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Text('PDF — pregled i ispis'),
        ),
        PopupMenuItem(
          value: 'pdf_share',
          child: Text('Pošalji PDF'),
        ),
      ],
    );
  }
}
