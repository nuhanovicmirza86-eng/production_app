import 'package:flutter/material.dart';

import 'operonix_visual_tokens.dart';

/// Prazno stanje. Classic ostaje tekst. Premium dodaje ikonu uz isti tekst.
class OperonixEmptyState extends StatelessWidget {
  final String message;
  final EdgeInsetsGeometry padding;

  const OperonixEmptyState({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = OperonixVisualTokens.of(context);
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tokens.isPremium) ...[
              Icon(
                Icons.inbox_outlined,
                size: 36,
                color: tokens.secondaryText,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.isPremium ? tokens.primaryText : null,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
