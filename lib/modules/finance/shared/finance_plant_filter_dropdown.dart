import 'package:flutter/material.dart';

import '../../../core/company_plant_display_name.dart';
import 'finance_strings.dart';

/// Dropdown pogona za Finance AI filtere — keširani popis, sigurna vrijednost tijekom učitavanja.
class FinancePlantFilterDropdown extends StatefulWidget {
  const FinancePlantFilterDropdown({
    super.key,
    required this.companyId,
    required this.selectedPlantKey,
    required this.onChanged,
  });

  final String companyId;
  final String selectedPlantKey;
  final ValueChanged<String> onChanged;

  @override
  State<FinancePlantFilterDropdown> createState() =>
      _FinancePlantFilterDropdownState();
}

class _FinancePlantFilterDropdownState extends State<FinancePlantFilterDropdown> {
  late Future<List<({String plantKey, String label})>> _plantsFuture;

  @override
  void initState() {
    super.initState();
    _plantsFuture = CompanyPlantDisplayName.listSelectablePlants(
      companyId: widget.companyId,
    );
  }

  @override
  void didUpdateWidget(covariant FinancePlantFilterDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) {
      _plantsFuture = CompanyPlantDisplayName.listSelectablePlants(
        companyId: widget.companyId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<({String plantKey, String label})>>(
      future: _plantsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DropdownButton<String>(
            value: '',
            hint: Text(FinanceStrings.t(context, 'advisory_filter_plant')),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  FinanceStrings.t(context, 'advisory_filter_all_plants'),
                ),
              ),
            ],
            onChanged: null,
          );
        }

        final plants = snap.data ?? [];
        final items = <DropdownMenuItem<String>>[
          DropdownMenuItem(
            value: '',
            child: Text(
              FinanceStrings.t(context, 'advisory_filter_all_plants'),
            ),
          ),
          ...plants.map(
            (p) => DropdownMenuItem(
              value: p.plantKey,
              child: Text(p.label),
            ),
          ),
        ];

        var value = widget.selectedPlantKey;
        final known = items.any((e) => e.value == value);
        if (!known && value.isNotEmpty) {
          items.insert(
            1,
            DropdownMenuItem(
              value: value,
              child: const Text('Odabrani pogon (provjerite šifarnik)'),
            ),
          );
        }
        if (!items.any((e) => e.value == value)) {
          value = '';
        }

        return DropdownButton<String>(
          value: value,
          hint: Text(FinanceStrings.t(context, 'advisory_filter_plant')),
          items: items,
          onChanged: (v) => widget.onChanged(v ?? ''),
        );
      },
    );
  }
}
