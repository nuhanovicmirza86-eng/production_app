import 'package:flutter/material.dart';

import 'finance_assistant/finance_assistant_context.dart';
import 'finance_assistant/finance_assistant_edge_handle.dart';
import 'finance_assistant/finance_module_assistant_scope.dart';
import 'finance_assistant/finance_module_assistant_session.dart';
import 'finance_system_bottom_inset.dart';

export 'finance_assistant/finance_assistant_context.dart';
export 'finance_assistant/finance_assistant_context_factory.dart';
export 'finance_assistant/finance_assistant_hub_context.dart';
export 'finance_assistant/finance_module_assistant_scope.dart';
export 'finance_assistant/finance_module_assistant_session.dart';

/// Finance modul — safe area, rubni Finance asistent, kontekst ekrana.
class FinanceScaffold extends StatelessWidget {
  const FinanceScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.assistantContext,
    this.showAssistantEdgeHandle = true,
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
  final bool showAssistantEdgeHandle;
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
      child: _FinanceAssistantEdgeOverlay(
        showHandle: showAssistantEdgeHandle,
        onOpenAssistant: () => _openAssistant(context),
        child: scaffold,
      ),
    );
  }

  Future<void> _openAssistant(BuildContext context) async {
    final scope = FinanceModuleAssistantScope.maybeOf(context);
    if (scope != null) {
      await scope.openAssistant();
      return;
    }
    await FinanceModuleAssistantSession.currentOrNull?.openAssistant(context);
  }
}

class _FinanceAssistantEdgeOverlay extends StatefulWidget {
  const _FinanceAssistantEdgeOverlay({
    required this.child,
    required this.showHandle,
    required this.onOpenAssistant,
  });

  final Widget child;
  final bool showHandle;
  final Future<void> Function() onOpenAssistant;

  @override
  State<_FinanceAssistantEdgeOverlay> createState() =>
      _FinanceAssistantEdgeOverlayState();
}

class _FinanceAssistantEdgeOverlayState
    extends State<_FinanceAssistantEdgeOverlay> {
  DateTime? _lastScrollAt;

  bool get _scrollCompact {
    final t = _lastScrollAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(milliseconds: 900);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification) {
      setState(() => _lastScrollAt = DateTime.now());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (widget.showHandle)
            FinanceAssistantEdgeHandle(
              scrollCompact: _scrollCompact,
              onPressed: widget.onOpenAssistant,
            ),
        ],
      ),
    );
  }
}
