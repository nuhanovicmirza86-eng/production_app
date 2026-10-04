import 'package:flutter/material.dart';

import 'operonix_premium_pictogram.dart';

/// Domenski Premium simbol. Oblik nosi značenje i bez boje.
enum OperonixPremiumGlyph {
  usersAccess,
  productionCell,
  productionOrder,
  planningFlow,
  liveTracking,
  qualityShield,
  aiInsight,
  chemicalDose,
  productionCount,
  processCheck,
  materialPrep,
  wastewater,
  packingSeal,
  firstPiece,
  finalInspection,
  machineClean,
  workspace5s,
  openActions,
  methodology,
  qualityOverview,
  controlledDocument,
  pfmea,
  controlPlan,
  inspectionRoute,
  managementReport,
  workDay,
  entryDate,
  plant,
  readyStatus,
  quickEntry,
  manualEntry,
  qrScan,
  closeBox,
  labelPrint,
  tableColumns,
  quantity,
  kpiTotal,
  kpiOpen,
  kpiRunning,
  kpiDone,
  products,
  workCenter,
  process,
  workforce,
  downtime,
  reports,
  logistics,
  orders,
  partners,
  finance,
  development,
  carbon,
  maintenance,
  station,
  deviceWorkMode,
  stationPreparation,
  stationFirstControl,
  stationFinalControl,
  stationNetwork,
  productionStations,
  analytics,
  attention,
  ncr,
  capa,
  audit,
  history,
  about,
  appearance,
  evidence,
}

/// Vektorski Premium piktogram. Nema mrežnog niti rasterskog izvora.
class OperonixPremiumIcon extends StatelessWidget {
  final OperonixPremiumGlyph glyph;
  final Color? color;
  final double size;

  const OperonixPremiumIcon({
    super.key,
    required this.glyph,
    this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final paintColor = color ?? IconTheme.of(context).color ?? const Color(0xFFE6EDF3);
    return CustomPaint(
      size: Size.square(size),
      painter: _PremiumGlyphPainter(glyph: glyph, color: paintColor),
    );
  }
}

class _PremiumGlyphPainter extends CustomPainter {
  final OperonixPremiumGlyph glyph;
  final Color color;

  const _PremiumGlyphPainter({required this.glyph, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    OperonixPremiumPictogram.paint(
      canvas: canvas,
      size: size,
      glyph: glyph,
      color: color,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
  }
}
