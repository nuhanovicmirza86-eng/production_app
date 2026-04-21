import 'package:flutter/material.dart';

class OoeKpiCard extends StatelessWidget {
  final String title;
  final String valueLabel;
  final Color? accent;
  final Widget? titleTrailing;

  const OoeKpiCard({
    super.key,
    required this.title,
    required this.valueLabel,
    this.accent,
    this.titleTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final ac = accent ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (titleTrailing != null) titleTrailing!,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              valueLabel,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: ac,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
