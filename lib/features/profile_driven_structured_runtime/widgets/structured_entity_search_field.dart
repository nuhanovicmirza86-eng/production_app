import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';

import '../../../modules/production/station_pages/models/production_station_profile_field.dart';
import '../../catalog_evidence_runtime/utils/evidence_input_empty.dart';
import '../models/structured_entity_search_result.dart';
import '../services/production_evidence_entity_search_service.dart';
import '../utils/structured_entity_search_result_appearance.dart';

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
    this.recentSuggestions = const [],
    this.recentSuggestionsLabel,
    this.plantDisplayLabel,
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
  /// Brzi izbor (npr. zadnji korišteni operateri) — chips iznad rezultata pretrage.
  final List<StructuredEntitySearchResult> recentSuggestions;
  /// Naslov iznad chips (default: Zadnji korišteni).
  final String? recentSuggestionsLabel;
  /// Ljudski naziv pogona evidencije (npr. Brizganje (BR)) — ne plantKey.
  final String? plantDisplayLabel;

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

  StructuredEntitySelection? _sanitizedSelection(
    StructuredEntitySelection? raw,
  ) {
    if (raw == null) return null;
    if (!isUsableEvidenceEntityId(raw.entityId)) return null;
    final label = usableEvidenceDisplayLabel(
      raw.displayLabel,
      entityId: raw.entityId,
    );
    if (label == null) return null;
    if (label == raw.displayLabel) return raw;
    return StructuredEntitySelection(
      fieldKey: raw.fieldKey,
      entityId: raw.entityId,
      displayLabel: label,
      raw: raw.raw,
    );
  }

  void _bindSelection(StructuredEntitySelection? raw) {
    _selection = _sanitizedSelection(raw);
    _controller.text = _selection?.displayLabel ?? '';
  }

  @override
  void initState() {
    super.initState();
    _bindSelection(widget.initialSelection);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) return;
    if (_selection != null) return;
    if (widget.field.minSearchChars > 0) return;
    unawaited(_runSearch(_controller.text));
  }

  @override
  void didUpdateWidget(covariant StructuredEntitySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelection?.entityId != oldWidget.initialSelection?.entityId ||
        widget.initialSelection?.displayLabel !=
            oldWidget.initialSelection?.displayLabel) {
      _bindSelection(widget.initialSelection);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
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
            hintText: evidenceSearchHint(),
            border: const OutlineInputBorder(),
            helperText: widget.field.helperText ??
                (minChars <= 0
                    ? 'Dodirnite polje ili unesite dio šifre / naziva.'
                    : 'Unesite najmanje $minChars znaka za pretragu.'),
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
        if (widget.recentSuggestions.isNotEmpty && _selection == null) ...[
          const SizedBox(height: 8),
          Text(
            widget.recentSuggestionsLabel ?? 'Zadnji korišteni',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in widget.recentSuggestions)
                ActionChip(
                  label: Text(item.displayLabel),
                  onPressed: widget.enabled ? () => _selectResult(item) : null,
                ),
            ],
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              productionEvidenceEntitySearchErrorMessage(_error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.45),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return _SearchResultCard(
                        field: widget.field,
                        item: item,
                        plantDisplayLabel: widget.plantDisplayLabel,
                        enabled: widget.enabled,
                        onTap: () => _selectResult(item),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  const _SearchResultCard({
    required this.field,
    required this.item,
    required this.plantDisplayLabel,
    required this.enabled,
    required this.onTap,
  });

  final ProductionStationProfileField field;
  final StructuredEntitySearchResult item;
  final String? plantDisplayLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = StructuredEntitySearchResultAppearance.title(widget.item);
    final badge = StructuredEntitySearchResultAppearance.badgeLabel(
      field: widget.field,
      item: widget.item,
    );
    final trailing = StructuredEntitySearchResultAppearance.trailingMeta(
      field: widget.field,
      plantDisplayLabel: widget.plantDisplayLabel,
    );
    final highlight = _hovered || _focused;
    final fill = highlight
        ? cs.primaryContainer
        : cs.primaryContainer.withValues(alpha: 0.55);
    final border = highlight
        ? cs.primary
        : cs.primary.withValues(alpha: 0.35);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (show) => setState(() => _focused = show),
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(12),
            hoverColor: cs.primary.withValues(alpha: 0.08),
            focusColor: cs.primary.withValues(alpha: 0.12),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: highlight ? 1.5 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 5, color: cs.primary),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface,
                                    ),
                              ),
                              if (badge != null || trailing != null) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (badge != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          badge,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: cs.onPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                    if (trailing != null)
                                      Text(
                                        badge != null
                                            ? '· $trailing'
                                            : trailing,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: cs.onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
