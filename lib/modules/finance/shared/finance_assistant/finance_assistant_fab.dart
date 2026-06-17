import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../finance_strings.dart';

/// Diskretna plutajuća ikona — donji desni ugao Finance ekrana.
class FinanceAssistantFab extends StatefulWidget {
  const FinanceAssistantFab({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  static const _hintPrefKey = 'finance_assistant_fab_hint_seen_v1';

  @override
  State<FinanceAssistantFab> createState() => _FinanceAssistantFabState();
}

class _FinanceAssistantFabState extends State<FinanceAssistantFab> {
  bool _showHint = false;
  bool _hintLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadHintState();
  }

  Future<void> _loadHintState() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(FinanceAssistantFab._hintPrefKey) ?? false;
    if (!mounted) return;
    setState(() {
      _hintLoaded = true;
      _showHint = !seen;
    });
    if (!seen) {
      Future<void>.delayed(const Duration(seconds: 6), () async {
        if (!mounted) return;
        setState(() => _showHint = false);
        await prefs.setBool(FinanceAssistantFab._hintPrefKey, true);
      });
    }
  }

  Future<void> _dismissHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(FinanceAssistantFab._hintPrefKey, true);
    if (mounted) setState(() => _showHint = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hintLoaded) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showHint) ...[
            Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              color: cs.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            FinanceStrings.t(
                              context,
                              'finance_assistant_fab_title',
                            ),
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            FinanceStrings.t(
                              context,
                              'finance_assistant_fab_subtitle',
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: _dismissHint,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: 52,
            height: 52,
            child: FloatingActionButton(
              heroTag: 'finance_assistant_fab',
              tooltip: FinanceStrings.t(
                context,
                'finance_assistant_fab_title',
              ),
              onPressed: widget.onPressed,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 26),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
