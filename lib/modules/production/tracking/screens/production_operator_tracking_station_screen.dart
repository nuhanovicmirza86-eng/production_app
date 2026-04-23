import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/format/ba_formatted_date.dart';
import '../../../../core/access/production_access_helper.dart'
    show ProductionAccessHelper, ProductionDashboardCard;
import '../../station/screens/station_tracking_setup_screen.dart';
import '../../station_pages/models/production_station_page.dart';
import '../../station_pages/screens/production_station_pages_admin_screen.dart';
import '../../station_pages/services/production_station_page_service.dart';
import '../config/station_screen_theme.dart';
import '../config/station_screen_theme_store.dart';
import '../models/production_operator_tracking_entry.dart';
import '../widgets/preparation_tracking_tab.dart';
import '../widgets/station_appearance_editor_dialog.dart';
import '../widgets/station_session_strip.dart';

/// Jedna operativna faza na cijelom zaslonu (npr. jedan monitor = jedna stanica).
///
/// Na **Windows / macOS / Linux** pri otvaranju ulazi u **OS puni zaslon** ([WindowManager.setFullScreen]);
/// pri zatvaranju stacije vraća se prozor u normalan način.
///
/// Otvara se s [MaterialPageRoute] i `fullscreenDialog: true` radi što većeg prostora u web/mobilnom okruženju.
class ProductionOperatorTrackingStationScreen extends StatefulWidget {
  final Map<String, dynamic> companyData;

  /// [ProductionOperatorTrackingEntry.phasePreparation] / `first_control` / `final_control`.
  final String phase;

  /// Traka „tko je prijavljen“ + placeholder QR — za operativne stanice na podu (npr. pripremna).
  final bool showOperativeSessionStrip;

  /// Kad je stanicu otvorio [AuthWrapper] u dedicated modu, zatvaranje ne radi `pop` nego ovaj callback.
  final VoidCallback? onCloseStation;

  /// Nakon što admin promijeni postavke stanice (pogon, klasifikacija, etiketa).
  final VoidCallback? onStationTrackingSetupSaved;

  const ProductionOperatorTrackingStationScreen({
    super.key,
    required this.companyData,
    required this.phase,
    this.showOperativeSessionStrip = false,
    this.onCloseStation,
    this.onStationTrackingSetupSaved,
  });

  static String phaseTitle(String phase) {
    switch (phase) {
      case ProductionOperatorTrackingEntry.phasePreparation:
        return 'Pripremna — stanica';
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prva kontrola — stanica';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Završna kontrola — stanica';
      default:
        return 'Praćenje — stanica';
    }
  }

  @override
  State<ProductionOperatorTrackingStationScreen> createState() =>
      _ProductionOperatorTrackingStationScreenState();
}

class _ProductionOperatorTrackingStationScreenState
    extends State<ProductionOperatorTrackingStationScreen> {
  bool _desktopOsFullscreen = false;
  StationScreenAppearance _appearance = const StationScreenAppearance();
  ProductionStationPage? _stationPageMeta;

  bool get _supportsOsWindowChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String get _companyLine {
    final n =
        (widget.companyData['name'] ?? widget.companyData['companyName'] ?? '')
            .toString()
            .trim();
    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    return cid.isNotEmpty ? cid : '—';
  }

  /// Postavke uređaja (pogon, ispis etikete) — samo [ProductionAccessHelper.roleAdmin].
  bool get _showStationSetupAction {
    final bound =
        (widget.companyData['stationBoundPlantKey'] ?? '').toString().trim();
    if (bound.isEmpty) return false;
    return ProductionAccessHelper.isAdminRole(widget.companyData['role']);
  }

  /// Isti pristup kao pločica „Stranice stanica“ na dashboardu.
  bool get _showStationPagesAdminAction {
    return ProductionAccessHelper.canManage(
      role: (widget.companyData['role'] ?? '').toString(),
      card: ProductionDashboardCard.stationPages,
    );
  }

  String get _plantLine {
    final pk = (widget.companyData['plantKey'] ?? '').toString().trim();
    final name =
        (widget.companyData['plantDisplayName'] ??
                widget.companyData['plantName'] ??
                '')
            .toString()
            .trim();
    if (pk.isEmpty && name.isEmpty) return 'Pogon: —';
    if (name.isNotEmpty) return 'Pogon: $name';
    return 'Pogon: $pk';
  }

  String _todayLine() => BaFormattedDate.formatFullDate(DateTime.now());

  Future<void> _loadStationTheme() async {
    final a = await StationScreenThemeStore.load();
    if (mounted) setState(() => _appearance = a);
  }

  Future<void> _loadStationPageMeta() async {
    final cid = (widget.companyData['companyId'] ?? '').toString().trim();
    final bound =
        (widget.companyData['stationBoundPlantKey'] ?? '').toString().trim();
    final pk = (widget.companyData['plantKey'] ?? '').toString().trim();
    final plantKey = bound.isNotEmpty ? bound : pk;
    if (cid.isEmpty || plantKey.isEmpty) return;
    final slot = ProductionStationPage.stationSlotForPhase(widget.phase);
    try {
      final page = await ProductionStationPageService().getPage(
        companyId: cid,
        plantKey: plantKey,
        stationSlot: slot,
      );
      if (mounted) setState(() => _stationPageMeta = page);
    } catch (_) {}
  }

  String get _appBarTitleLine {
    final d = _stationPageMeta?.displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    return ProductionOperatorTrackingStationScreen.phaseTitle(widget.phase);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadStationTheme());
    unawaited(_loadStationPageMeta());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterOsFullscreenIfDesktop();
    });
  }

  Future<void> _enterOsFullscreenIfDesktop() async {
    if (!_supportsOsWindowChrome || !mounted) return;
    try {
      await windowManager.setFullScreen(true);
      if (mounted) setState(() => _desktopOsFullscreen = true);
    } catch (_) {}
  }

  Future<void> _exitOsFullscreenIfNeeded() async {
    if (!_desktopOsFullscreen) return;
    try {
      await windowManager.setFullScreen(false);
    } catch (_) {}
    _desktopOsFullscreen = false;
  }

  Future<void> _closeStation() async {
    await _exitOsFullscreenIfNeeded();
    if (!mounted) return;
    if (widget.onCloseStation != null) {
      widget.onCloseStation!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    // Ako korisnik ne zatvori preko gumba, ipak vrati prozor.
    unawaited(_exitOsFullscreenIfNeeded());
    super.dispose();
  }

  Widget _phaseBody() {
    return PreparationTrackingTab(
      companyData: widget.companyData,
      phase: widget.phase,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentTheme = Theme.of(context);
    final stationTheme = buildStationScreenTheme(parentTheme, _appearance);

    return AnimatedTheme(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      data: stationTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;

          return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _appBarTitleLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _plantLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          tooltip: 'Zatvori stanicu',
          icon: const Icon(Icons.close),
          onPressed: _closeStation,
        ),
        actions: [
          if (_showStationPagesAdminAction)
            IconButton(
              tooltip: 'Ekrani stanica za ovaj pogon',
              icon: const Icon(Icons.settings_applications_outlined),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductionStationPagesAdminScreen(
                      companyData: widget.companyData,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: 'Izgled stanice (boje i predlošci)',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () async {
              final next = await showStationAppearanceEditorDialog(
                context: context,
                current: _appearance,
                allowCustomColors:
                    ProductionAccessHelper.canEditStationScreenCustomColors(
                  (widget.companyData['role'] ?? '').toString(),
                ),
              );
              if (next == null || !mounted) return;
              setState(() => _appearance = next);
              await StationScreenThemeStore.save(next);
            },
          ),
          if (_showStationSetupAction)
            IconButton(
              tooltip: 'Postavke stanice (pogon, klasifikacija, etiketa)',
              icon: const Icon(Icons.tune),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (ctx) => StationTrackingSetupScreen(
                      companyData: widget.companyData,
                      onSaved: () {
                        Navigator.of(ctx).pop();
                        widget.onStationTrackingSetupSaved?.call();
                      },
                    ),
                  ),
                );
              },
            ),
          if (_supportsOsWindowChrome)
            IconButton(
              tooltip: _desktopOsFullscreen
                  ? 'Izađi iz OS punog zaslona (ostani u stanici)'
                  : 'OS puni zaslon',
              icon: Icon(
                _desktopOsFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              ),
              onPressed: () async {
                if (_desktopOsFullscreen) {
                  await _exitOsFullscreenIfNeeded();
                } else {
                  await _enterOsFullscreenIfDesktop();
                }
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.business_outlined, size: 22, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _companyLine,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _todayLine(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showOperativeSessionStrip)
            StationSessionStrip(companyData: widget.companyData),
          Expanded(child: _phaseBody()),
        ],
      ),
    );
        },
      ),
    );
  }
}
