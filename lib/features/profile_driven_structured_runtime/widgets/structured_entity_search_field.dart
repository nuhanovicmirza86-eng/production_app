import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';

import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../models/structured_entity_search_result.dart';
import '../services/production_evidence_entity_search_service.dart';

typedef StructuredEntitySearchFn =
    Future<List<StructuredEntitySearchResult>> Function(String query);

/// Search polje koje prihvata samo rezultat pretrage (bez slobodnog ID unosa).
class StructuredEntitySearchField extends StatefulWidget {
  const StructuredEntitySearchField({
    super.key,
    required this.field,
    required this.companyId,
    this.plantKey,
    required this.searchFn,
    this.initialSelection,
    this.enabled = true,
    this.onChanged,
    this.labelOverride,
    this.requiredOverride,
  });

  final ProductionStationProfileField field;
  final String companyId;
  final String? plantKey;
  final StructuredEntitySearchFn searchFn;
  final StructuredEntitySelection? initialSelection;
  final bool enabled;
  final ValueChanged<StructuredEntitySelection?>? onChanged;
  final String? labelOverride;
  final bool? requiredOverride;

  @override
  State<StructuredEntitySearchField> createState() =>
      _StructuredEntitySearchFieldState();
}

class _StructuredEntitySearchFieldState extends State<StructuredEntitySearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _searching = false;
  Object? _error;
  List<StructuredEntitySearchResult> _results = const [];
  StructuredEntitySelection? _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection;
    if (_selection != null) {
      _controller.text = _selection!.displayLabel;
    }
  }

  @override
  void didUpdateWidget(covariant StructuredEntitySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelection?.entityId != oldWidget.initialSelection?.entityId) {
      _selection = widget.initialSelection;
      _controller.text = _selection?.displayLabel ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scheduleSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(query));
    });
  }

  Future<void> _runSearch(String query) async {
    final minChars = widget.field.minSearchChars;
    if (query.trim().length < minChars) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final items = await widget.searchFn(query.trim());
      if (!mounted) return;
      setState(() {
        _results = items;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _searching = false;
        _results = const [];
      });
    }
  }

  void _selectResult(StructuredEntitySearchResult result) {
    final selection = StructuredEntitySelection.fromSearchResult(
      fieldKey: widget.field.key,
      result: result,
      valueField: widget.field.valueField,
    );
    setState(() {
      _selection = selection;
      _controller.text = selection.displayLabel;
      _results = const [];
    });
    widget.onChanged?.call(selection);
    _focusNode.unfocus();
  }

  void _clearSelection() {
    setState(() {
      _selection = null;
      _controller.clear();
      _results = const [];
    });
    widget.onChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final minChars = widget.field.minSearchChars;
    final label = widget.labelOverride ?? widget.field.label;
    final required = widget.requiredOverride ?? widget.field.required;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            border: const OutlineInputBorder(),
            helperText: widget.field.helperText ??
                'Unesite najmanje $minChars znaka za pretragu.',
            suffixIcon: _selection != null
                ? IconButton(
                    tooltip: 'Ukloni odabir',
                    onPressed: widget.enabled ? _clearSelection : null,
                    icon: const Icon(Icons.close),
                  )
                : _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
          ),
          onChanged: (value) {
            if (_selection != null && value.trim() != _selection!.displayLabel) {
              _selection = null;
              widget.onChanged?.call(null);
            }
            _scheduleSearch(value);
          },
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              productionEvidenceEntitySearchErrorMessage(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_results.isNotEmpty)
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return ListTile(
                    dense: true,
                    title: Text(item.displayLabel),
                    subtitle: item.secondaryLabel == null
                        ? null
                        : Text(item.secondaryLabel!),
                    onTap: widget.enabled ? () => _selectResult(item) : null,
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
