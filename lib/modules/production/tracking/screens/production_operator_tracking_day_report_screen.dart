import 'package:flutter/material.dart';

import '../../../../core/company_plant_display_name.dart';
import '../../../../core/format/ba_formatted_date.dart';
import '../config/operator_tracking_column_labels.dart';
import '../config/platform_defect_codes.dart';
import '../export/production_operator_tracking_day_pdf_export.dart';
import '../models/production_operator_tracking_entry.dart';
import '../services/production_operator_tracking_service.dart';

/// Odabir dana i faze te ispis PDF dnevnog lista iz `production_operator_tracking`.
class ProductionOperatorTrackingDayReportScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const ProductionOperatorTrackingDayReportScreen({
    super.key,
    required this.companyData,
  });

  @override
  State<ProductionOperatorTrackingDayReportScreen> createState() =>
      _ProductionOperatorTrackingDayReportScreenState();
}

class _ProductionOperatorTrackingDayReportScreenState
    extends State<ProductionOperatorTrackingDayReportScreen> {
  final _service = ProductionOperatorTrackingService();

  DateTime _workDay = DateTime.now();
  String _phase = ProductionOperatorTrackingEntry.phasePreparation;
  bool _loading = false;

  String get _companyId =>
      (widget.companyData['companyId'] ?? '').toString().trim();

  String get _plantKey =>
      (widget.companyData['plantKey'] ?? '').toString().trim();

  String get _companyDisplayName {
    final n =
        (widget.companyData['name'] ?? widget.companyData['companyName'] ?? '')
            .toString()
            .trim();
    if (n.isNotEmpty) return n;
    return _companyId;
  }

  String _workDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _pickDay() async {
    final first = DateTime.now().subtract(const Duration(days: 120));
    final last = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDay,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _workDay = picked);
    }
  }

  Future<void> _printPdf() async {
    if (_companyId.isEmpty || _plantKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nedostaje podatak o kompaniji ili pogonu u sesiji.'),
        ),
      );
      return;
    }
    final workKey = _workDateKey(_workDay);
    setState(() => _loading = true);
    try {
      final entries = await _service.fetchDayPhase(
        companyId: _companyId,
        plantKey: _plantKey,
        phase: _phase,
        workDate: workKey,
      );
      if (!mounted) return;
      if (entries.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Nema unosa za $workKey.')));
        return;
      }
      final plantLabel = await CompanyPlantDisplayName.resolve(
        companyId: _companyId,
        plantKey: _plantKey,
      );
      final u = entries.isEmpty
          ? 'kom'
          : entries.first.unit.trim().isEmpty
          ? 'kom'
          : entries.first.unit.trim();
      await ProductionOperatorTrackingDayPdfExport.preview(
        entries: entries,
        workDate: workKey,
        phase: _phase,
        companyLine: _companyDisplayName,
        plantLine: 'Pogon: $plantLabel',
        defectDisplayNames: parseDefectDisplayNamesMap(widget.companyData),
        columnLabels: parseOperatorTrackingColumnLabels(widget.companyData),
        unitForHeaders: u,
        companyId: _companyId,
        companyData: widget.companyData,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workKey = _workDateKey(_workDay);

    return Scaffold(
      appBar: AppBar(title: const Text('Dnevni list praćenja')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Odaberi radni datum i fazu, zatim otvori dijalog ispisa (PDF).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Radni datum'),
            subtitle: Text(
              '${BaFormattedDate.formatFullDate(_workDay)} · $workKey',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: IconButton(
              tooltip: 'Promijeni datum',
              icon: const Icon(Icons.edit_calendar_outlined),
              onPressed: _loading ? null : _pickDay,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_phase),
            initialValue: _phase,
            decoration: const InputDecoration(labelText: 'Faza'),
            items: const [
              DropdownMenuItem(
                value: ProductionOperatorTrackingEntry.phasePreparation,
                child: Text('Pripremna'),
              ),
              DropdownMenuItem(
                value: ProductionOperatorTrackingEntry.phaseFirstControl,
                child: Text('Prva kontrola'),
              ),
              DropdownMenuItem(
                value: ProductionOperatorTrackingEntry.phaseFinalControl,
                child: Text('Završna kontrola'),
              ),
            ],
            onChanged: _loading
                ? null
                : (v) {
                    if (v != null) setState(() => _phase = v);
                  },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _printPdf,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              _loading ? 'Učitavanje…' : 'Ispis PDF (dijalog ispisa)',
            ),
          ),
        ],
      ),
    );
  }
}
