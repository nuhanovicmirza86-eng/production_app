import 'package:flutter/material.dart';

import '../../commercial/partners/models/partner_models.dart';
import '../../commercial/partners/services/customers_service.dart';

/// Odabir kupca iz `customers` za vezu na CSR / Launch Intelligence.
Future<CustomerModel?> showDevelopmentCustomerPickerSheet(
  BuildContext context, {
  required String companyId,
}) async {
  final cid = companyId.trim();
  if (cid.isEmpty) return null;

  return showModalBottomSheet<CustomerModel>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _DevelopmentCustomerPickerBody(companyId: cid),
  );
}

class _DevelopmentCustomerPickerBody extends StatefulWidget {
  const _DevelopmentCustomerPickerBody({required this.companyId});

  final String companyId;

  @override
  State<_DevelopmentCustomerPickerBody> createState() =>
      _DevelopmentCustomerPickerBodyState();
}

class _DevelopmentCustomerPickerBodyState extends State<_DevelopmentCustomerPickerBody> {
  final _svc = CustomersService();
  final _searchCtrl = TextEditingController();
  List<CustomerModel> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await _svc.listCustomers(companyId: widget.companyId, limit: 500);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<CustomerModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((c) {
      final hay =
          '${c.code.toLowerCase()} ${c.name.toLowerCase()} ${c.legalName.toLowerCase()}';
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Text(
                'Odaberi kupca iz šifrarnika',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Pretraga po šifri ili nazivu…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _load,
                          child: const Text('Pokušaj ponovo'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final c = _filtered[i];
                    return ListTile(
                      title: Text(c.name.isNotEmpty ? c.name : c.code),
                      subtitle: Text(
                        c.code.isNotEmpty
                            ? '${c.code} · ${c.status}'
                            : c.status,
                      ),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
