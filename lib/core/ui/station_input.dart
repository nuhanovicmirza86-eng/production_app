import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:production_app/core/theme/operonix_production_brand.dart';

/// Pri [FocusNode.hasFocus] poziva [Scrollable.ensureVisible] da roditeljski
/// [ListView] / [SingleChildScrollView] (uključivo ugniježđeni) pokaže polje.
class ScrollIntoViewOnFocus extends StatefulWidget {
  const ScrollIntoViewOnFocus({
    super.key,
    required this.focusNode,
    required this.child,
    this.alignment = 0.35,
    this.duration = const Duration(milliseconds: 220),
  });

  final FocusNode focusNode;
  final Widget child;
  final double alignment;
  final Duration duration;

  @override
  State<ScrollIntoViewOnFocus> createState() => _ScrollIntoViewOnFocusState();
}

class _ScrollIntoViewOnFocusState extends State<ScrollIntoViewOnFocus> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(ScrollIntoViewOnFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = widget.focusNode.context;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: widget.alignment,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Zajednički izgled i ponašanje polja za operativne / stanice ekrane.
///
/// - Konzistentan [InputDecoration] (tablica, formular, dijalog).
/// - [StationTextField]: Enter prelazi na [StationTextField.nextFocus] kad je jedan red.
class StationInputDecoration {
  StationInputDecoration._();

  /// Polje u tabličnoj ćeliji (gusto, bez „pill“ obruba).
  static InputDecoration tableCell(BuildContext context, String hint) {
    final cs = Theme.of(context).colorScheme;
    final none = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 11,
        color: cs.onSurfaceVariant.withValues(alpha: 0.78),
      ),
      filled: true,
      fillColor: Colors.transparent,
      border: none,
      enabledBorder: none,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: kOperonixProductionBrandGreen.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    );
  }

  /// Standardno polje na cijelom ekranu ili u dijalogu (veći dodir, vidljiv label).
  static InputDecoration formField(
    BuildContext context, {
    required String labelText,
    String? hintText,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      isDense: false,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: kOperonixProductionBrandGreen.withValues(alpha: 0.75),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

/// Tekstualno polje za pod: isti vizualni jezik + Enter → sljedeće polje ([nextFocus]).
///
/// Za [maxLines] > 1 Enter dodaje novi red; lanac se ne koristi.
class StationTextField extends StatelessWidget {
  const StationTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.nextFocus,
    required this.decoration,
    this.style,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,

    /// Ako je postavljeno, zamjenjuje zadano ponašanje (fokus na [nextFocus]).
    this.onSubmitted,
    this.inputFormatters,
    this.scrollIntoViewOnFocus = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Sljedeće polje pri Enteru (jednoredni unos). Ignorira se ako je [onSubmitted] postavljen.
  final FocusNode? nextFocus;

  final InputDecoration decoration;
  final TextStyle? style;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Primjer: zatvaranje bottom sheeta, validacija.
  final ValueChanged<String>? onSubmitted;

  final List<TextInputFormatter>? inputFormatters;

  /// Pomiče roditeljski scroll da polje bude vidljivo (Tab, strelice, skener…).
  final bool scrollIntoViewOnFocus;

  bool get _multiline => maxLines > 1;

  @override
  Widget build(BuildContext context) {
    final action = _multiline
        ? TextInputAction.newline
        : (nextFocus != null ? TextInputAction.next : TextInputAction.done);

    void defaultSubmit(String value) {
      if (nextFocus != null) {
        FocusScope.of(context).requestFocus(nextFocus);
      } else {
        FocusScope.of(context).unfocus();
      }
    }

    Widget field = TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      textCapitalization: textCapitalization,
      keyboardType:
          keyboardType ??
          (_multiline ? TextInputType.multiline : TextInputType.text),
      maxLines: maxLines,
      minLines: _multiline ? null : 1,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: action,
      decoration: decoration,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: _multiline
          ? null
          : (value) {
              if (onSubmitted != null) {
                onSubmitted!(value);
              } else {
                defaultSubmit(value);
              }
            },
    );
    if (focusNode != null && scrollIntoViewOnFocus) {
      field = ScrollIntoViewOnFocus(focusNode: focusNode!, child: field);
    }
    return field;
  }
}
