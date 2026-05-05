import 'package:flutter/material.dart';

import '../utils/finance_permissions.dart';
import '../widgets/finance_connections_inline_list.dart';
import 'finance_connection_edit_screen.dart';

class FinanceConnectionsScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;
  final bool debugUnlockModule;

  const FinanceConnectionsScreen({
    super.key,
    required this.companyData,
    this.debugUnlockModule = false,
  });

  @override
  State<FinanceConnectionsScreen> createState() =>
      _FinanceConnectionsScreenState();
}

class _FinanceConnectionsScreenState extends State<FinanceConnectionsScreen> {
  String get _role =>
      (widget.companyData['role'] ?? '').toString().trim();

  bool get _canManage => FinancePermissions.canManageConnections(
        companyData: widget.companyData,
        role: _role,
        debugUnlockModule: widget.debugUnlockModule,
      );

  Future<void> _openEditor() async {
    if (!_canManage) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => FinanceConnectionEditScreen(
          companyData: widget.companyData,
          debugUnlockModule: widget.debugUnlockModule,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ERP veze'),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _openEditor,
              icon: const Icon(Icons.add),
              label: const Text('Nova veza'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          FinanceConnectionsInlineList(
            companyData: widget.companyData,
            debugUnlockModule: widget.debugUnlockModule,
          ),
        ],
      ),
    );
  }
}
