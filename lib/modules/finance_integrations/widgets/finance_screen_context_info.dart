import 'package:flutter/material.dart';

import '../utils/finance_load_error_presenter.dart';

/// Kratko objašnjenje konteksta ekrana — samo kroz info ikonu (bez inženjerskog teksta u tijelu).
class FinanceScreenContextInfo extends StatelessWidget {
  const FinanceScreenContextInfo({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final b = body.trim();
    if (b.isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Pojašnjenje',
      icon: Icon(
        Icons.info_outline,
        size: 22,
        color: Theme.of(context).colorScheme.outline,
      ),
      onPressed: () => showFinanceTechnicalDetailDialog(
        context,
        title: title,
        detail: b,
      ),
    );
  }
}
