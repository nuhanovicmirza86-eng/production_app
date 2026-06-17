import 'package:flutter/material.dart';

import 'finance_assistant_context.dart';
import 'finance_module_assistant_scope.dart';

/// Kompatibilnost za sheetove — samo registrira kontekst i otvara panel preko scope-a.
class FinanceAssistantHost extends StatelessWidget {
  const FinanceAssistantHost({
    super.key,
    required this.contextData,
    required this.child,
    this.showFab = false,
  });

  final FinanceAssistantContext contextData;
  final Widget child;
  final bool showFab;

  @Deprecated('Koristi FinanceModuleAssistantScope.maybeOf(context)')
  static FinanceModuleAssistantScopeState? of(BuildContext context) {
    return FinanceModuleAssistantScope.maybeOf(context);
  }

  @override
  Widget build(BuildContext context) {
    return FinanceAssistantContextRegistrar(
      contextData: contextData,
      child: child,
    );
  }
}
