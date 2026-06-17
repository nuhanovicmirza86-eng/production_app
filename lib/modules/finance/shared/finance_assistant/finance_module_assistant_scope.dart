import 'package:flutter/material.dart';

import 'finance_assistant_context.dart';
import 'finance_module_assistant_session.dart';

/// Ulaz u Finance modul — pokreće zajedničku sesiju asistenta.
class FinanceModuleAssistantScope extends StatefulWidget {
  const FinanceModuleAssistantScope({
    super.key,
    required this.child,
    this.endSessionOnDispose = true,
  });

  final Widget child;
  final bool endSessionOnDispose;

  static FinanceModuleAssistantScopeState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<FinanceModuleAssistantScopeState>();
  }

  @override
  State<FinanceModuleAssistantScope> createState() =>
      FinanceModuleAssistantScopeState();
}

class FinanceModuleAssistantScopeState extends State<FinanceModuleAssistantScope> {
  late final FinanceModuleAssistantSession _session;

  @override
  void initState() {
    super.initState();
    _session = FinanceModuleAssistantSession.ensure();
  }

  @override
  void dispose() {
    if (widget.endSessionOnDispose) {
      FinanceModuleAssistantSession.end();
    }
    super.dispose();
  }

  FinanceModuleAssistantSession get session => _session;

  void registerContext(FinanceAssistantContext context) {
    _session.registerContext(context);
  }

  void openAssistant({String? questionKey}) {
    _session.openAssistant(context, questionKey: questionKey);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Registrira kontekst trenutnog ekrana u aktivnu Finance sesiju.
class FinanceAssistantContextRegistrar extends StatefulWidget {
  const FinanceAssistantContextRegistrar({
    super.key,
    required this.contextData,
    required this.child,
  });

  final FinanceAssistantContext contextData;
  final Widget child;

  @override
  State<FinanceAssistantContextRegistrar> createState() =>
      _FinanceAssistantContextRegistrarState();
}

class _FinanceAssistantContextRegistrarState
    extends State<FinanceAssistantContextRegistrar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  @override
  void didUpdateWidget(FinanceAssistantContextRegistrar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    final scope = FinanceModuleAssistantScope.maybeOf(context);
    if (scope != null) {
      scope.registerContext(widget.contextData);
      return;
    }
    FinanceModuleAssistantSession.currentOrNull
        ?.registerContext(widget.contextData);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
