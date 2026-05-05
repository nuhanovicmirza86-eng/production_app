import 'package:flutter/material.dart';

/// Zaslonski placeholder za funkcionalnost u izgradnji (sync, mapiranje, logovi, …).
class FinancePlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;

  const FinancePlaceholderScreen({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
