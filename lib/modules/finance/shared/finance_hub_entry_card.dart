import 'package:flutter/material.dart';

import 'finance_help_info_button.dart';

/// Ulaz u podmodul Finance huba — naslov na kartici; pojašnjenje isključivo preko ⓘ.
class FinanceHubEntryCard extends StatelessWidget {
  const FinanceHubEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    required this.helpTitleKey,
    required this.helpBodyKey,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String helpTitleKey;
  final String helpBodyKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Row(
                  children: [
                    Icon(icon, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FinanceHelpInfoButton(
              titleKey: helpTitleKey,
              bodyKey: helpBodyKey,
            ),
            InkWell(
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
