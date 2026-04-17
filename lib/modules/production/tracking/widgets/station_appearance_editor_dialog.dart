import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../../../core/theme/operonix_production_brand.dart';
import '../config/station_screen_theme.dart';

/// Dijalog: ugrađene teme ili tri boje (podloga, akcent, obrub polja).
/// Vlastite boje mogu mijenjati samo Admin (`allowCustomColors: true`).
Future<StationScreenAppearance?> showStationAppearanceEditorDialog({
  required BuildContext context,
  required StationScreenAppearance current,
  bool allowCustomColors = false,
}) {
  return showDialog<StationScreenAppearance>(
    context: context,
    builder: (ctx) => _StationAppearanceEditorBody(
      seed: current,
      allowCustomColors: allowCustomColors,
    ),
  );
}

class _StationAppearanceEditorBody extends StatefulWidget {
  const _StationAppearanceEditorBody({
    required this.seed,
    required this.allowCustomColors,
  });

  final StationScreenAppearance seed;
  final bool allowCustomColors;

  @override
  State<_StationAppearanceEditorBody> createState() =>
      _StationAppearanceEditorBodyState();
}

class _StationAppearanceEditorBodyState extends State<_StationAppearanceEditorBody> {
  late StationScreenThemeId _preset;
  StationScreenCustomColors? _custom;
  late bool _useCustomColors;
  /// Korisnik je eksplicitno odabrao predložak (npr. da ukloni admin custom boje).
  bool _presetPicked = false;

  late Color _bgColor;
  late Color _accentColor;
  late Color _outlineColor;

  @override
  void initState() {
    super.initState();
    _preset = widget.seed.preset;
    _custom = widget.seed.custom;
    _useCustomColors =
        widget.allowCustomColors && widget.seed.custom != null;
    final c = _custom ??
        StationScreenCustomColors(
          background: const Color(0xFFF5F8FB),
          primaryAccent: kOperonixProductionBrandGreen,
          fieldOutline: const Color(0xFF90A4AE),
        );
    _bgColor = c.background;
    _accentColor = c.primaryAccent;
    _outlineColor = c.fieldOutline;
  }

  void _syncCustomFromColors() {
    _custom = StationScreenCustomColors(
      background: _bgColor,
      primaryAccent: _accentColor,
      fieldOutline: _outlineColor,
    );
  }

  Future<void> _pickColor({
    required String title,
    required Color initial,
    required ValueChanged<Color> onDone,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        Color working = initial;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: working,
                  onColorChanged: (c) => setModalState(() => working = c),
                  pickerAreaHeightPercent: 0.65,
                  enableAlpha: false,
                  displayThumbColor: true,
                  hexInputBar: false,
                  labelTypes: const [],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: () {
                    onDone(working);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Gotovo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _colorRow({
    required String label,
    required Color color,
    required ValueChanged<Color> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Material(
        color: color,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
          ),
        ),
        child: InkWell(
          onTap: () => _pickColor(
            title: label,
            initial: color,
            onDone: (c) {
              setState(() {
                onChanged(c);
                _syncCustomFromColors();
              });
            },
          ),
          borderRadius: BorderRadius.circular(8),
          child: const SizedBox(width: 48, height: 36),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminCustom = widget.allowCustomColors;
    final StationScreenAppearance previewAppearance;
    if (!adminCustom && widget.seed.usesCustom) {
      previewAppearance = widget.seed;
    } else if (adminCustom && _useCustomColors) {
      previewAppearance = StationScreenAppearance(
        preset: _preset,
        custom: StationScreenCustomColors(
          background: _bgColor,
          primaryAccent: _accentColor,
          fieldOutline: _outlineColor,
        ),
      );
    } else {
      previewAppearance = StationScreenAppearance(preset: _preset);
    }
    final previewStationTheme =
        buildStationScreenTheme(theme, previewAppearance);

    return AlertDialog(
      title: const Text('Izgled ekrana stanice'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Predlošci prate Operonix brend i SCADA paletu (tamna noć = „Operonix grafit“).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Predlošci',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in StationScreenThemeId.values)
                  ChoiceChip(
                    avatar: Icon(t.menuIcon, size: 18),
                    label: Text(t.label),
                    selected: !_useCustomColors &&
                        (!widget.seed.usesCustom || _presetPicked) &&
                        _preset == t,
                    onSelected: (_) {
                      setState(() {
                        _preset = t;
                        _custom = null;
                        _useCustomColors = false;
                        _presetPicked = true;
                      });
                    },
                  ),
              ],
            ),
            if (!_useCustomColors &&
                (!widget.seed.usesCustom || _presetPicked)) ...[
              const SizedBox(height: 6),
              Text(
                StationScreenThemeId.values
                    .firstWhere((e) => e == _preset)
                    .description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!adminCustom && widget.seed.usesCustom) ...[
              const SizedBox(height: 12),
              Material(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.85,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aktivna je paleta prilagođenih boja (Admin). Odaberi predložak ispod za standardni izgled.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (adminCustom) ...[
              const Divider(height: 24),
              Text(
                'Vlastite boje (samo Admin)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Koristi vlastite boje'),
                subtitle: const Text(
                  'Podloga, akcent gumba i obrub polja — sprema se na ovom uređaju.',
                ),
                value: _useCustomColors,
                onChanged: (v) => setState(() {
                  _useCustomColors = v;
                  if (v) {
                    _syncCustomFromColors();
                  } else {
                    _custom = null;
                  }
                }),
              ),
              if (_useCustomColors) ...[
                Text(
                  'Odaberi boju dotikom na kvadrat.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _colorRow(
                  label: 'Podloga',
                  color: _bgColor,
                  onChanged: (c) => _bgColor = c,
                ),
                _colorRow(
                  label: 'Akcent (gumbi)',
                  color: _accentColor,
                  onChanged: (c) => _accentColor = c,
                ),
                _colorRow(
                  label: 'Obrub polja',
                  color: _outlineColor,
                  onChanged: (c) => _outlineColor = c,
                ),
              ],
            ],
            const SizedBox(height: 12),
            Text('Pregled', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            AnimatedTheme(
              duration: const Duration(milliseconds: 200),
              data: previewStationTheme,
              child: Builder(
                builder: (ctx) {
                  final t = Theme.of(ctx);
                  final cs = t.colorScheme;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Gumb'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Polje',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () {
            if (adminCustom && _useCustomColors) {
              _syncCustomFromColors();
              Navigator.pop(
                context,
                StationScreenAppearance(
                  preset: _preset,
                  custom: _custom,
                ),
              );
              return;
            }
            if (!adminCustom) {
              if (widget.seed.usesCustom) {
                if (!_presetPicked) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(
                  context,
                  StationScreenAppearance(preset: _preset),
                );
                return;
              }
              if (widget.seed.preset == _preset) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(
                context,
                StationScreenAppearance(preset: _preset),
              );
              return;
            }
            Navigator.pop(
              context,
              StationScreenAppearance(preset: _preset),
            );
          },
          child: const Text('Spremi'),
        ),
      ],
    );
  }
}
