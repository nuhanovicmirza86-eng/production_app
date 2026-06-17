import 'package:flutter/material.dart';

import 'finance_assistant/finance_assistant_context.dart';
import 'finance_assistant/finance_assistant_fab.dart';
import 'finance_assistant/finance_module_assistant_scope.dart';
import 'finance_assistant/finance_module_assistant_session.dart';
import 'finance_system_bottom_inset.dart';

export 'finance_assistant/finance_assistant_context.dart';
export 'finance_assistant/finance_assistant_context_factory.dart';
export 'finance_assistant/finance_assistant_hub_context.dart';
export 'finance_assistant/finance_module_assistant_scope.dart';
export 'finance_assistant/finance_module_assistant_session.dart';

/// Finance modul — safe area, jedan plutajući Finance asistent, kontekst ekrana.
class FinanceScaffold extends StatelessWidget {
  const FinanceScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.assistantContext,
    this.showAssistantFab = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final FinanceAssistantContext? assistantContext;
  final bool showAssistantFab;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? persistentFooterButtons;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: appBar,
      body: FinanceSystemBottomInset.safeBody(body),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      persistentFooterButtons: persistentFooterButtons,
      drawer: drawer,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );

    return _wrapAssistant(context, scaffold);
  }

  Widget _wrapAssistant(BuildContext context, Widget scaffold) {
    if (assistantContext == null) return scaffold;

    return FinanceAssistantContextRegistrar(
      contextData: assistantContext!,
      child: Stack(
        fit: StackFit.expand,
        children: [
          scaffold,
          if (showAssistantFab)
            FinanceAssistantFab(
              onPressed: () => _openAssistant(context),
            ),
        ],
      ),
    );
  }

  void _openAssistant(BuildContext context) {
    final scope = FinanceModuleAssistantScope.maybeOf(context);
    if (scope != null) {
      scope.openAssistant();
      return;
    }
    FinanceModuleAssistantSession.currentOrNull?.openAssistant(context);
  }
}
