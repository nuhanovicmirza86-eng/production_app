import 'package:flutter/material.dart';

import '../company_plant_display_name.dart';

/// Jedan red teksta: ljudski naziv pogona iz šifrarnika, ne golim `plantKey`.
class CompanyPlantLabelText extends StatefulWidget {
  const CompanyPlantLabelText({
    super.key,
    required this.companyId,
    required this.plantKey,
    this.prefix = 'Pogon: ',
    this.style,
  });

  final String companyId;
  final String plantKey;
  final String prefix;
  final TextStyle? style;

  @override
  State<CompanyPlantLabelText> createState() => _CompanyPlantLabelTextState();
}

class _CompanyPlantLabelTextState extends State<CompanyPlantLabelText> {
  String _label = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CompanyPlantLabelText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.plantKey != widget.plantKey) {
      _load();
    }
  }

  Future<void> _load() async {
    final pk = widget.plantKey.trim();
    final cid = widget.companyId.trim();
    if (pk.isEmpty || cid.isEmpty) {
      if (mounted) setState(() => _label = '—');
      return;
    }
    final resolved = await CompanyPlantDisplayName.resolve(
      companyId: cid,
      plantKey: pk,
    );
    if (!mounted) return;
    setState(() => _label = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.plantKey.trim();
    if (pk.isEmpty) {
      return Text('${widget.prefix}—', style: widget.style);
    }
    if (_label.isEmpty) {
      return Text('${widget.prefix}…', style: widget.style);
    }
    return Text('${widget.prefix}$_label', style: widget.style);
  }
}
