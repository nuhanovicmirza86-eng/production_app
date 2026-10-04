import 'package:flutter/material.dart';

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

/// Vektorski Premium simbol. Nema mrežnog niti rasterskog izvora.
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
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final pen = _Pen(canvas, color, color.withValues(alpha: 0.55));
    _drawGlyph(pen, glyph);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PremiumGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph || oldDelegate.color != color;
  }
}

class _Pen {
  _Pen(this.canvas, this.primary, this.secondary);

  final Canvas canvas;
  final Color primary;
  final Color secondary;
  static const double sw = 1.65;

  Paint _paint(Color c, {bool fill = false, double width = sw}) {
    return Paint()
      ..color = c
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  void line(double x1, double y1, double x2, double y2, {bool alt = false}) {
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      _paint(alt ? secondary : primary),
    );
  }

  void circle(
    double x,
    double y,
    double r, {
    bool alt = false,
    bool fill = false,
  }) {
    canvas.drawCircle(
      Offset(x, y),
      r,
      _paint(alt ? secondary : primary, fill: fill),
    );
  }

  void oval(Rect rect, {bool alt = false, bool fill = false}) {
    canvas.drawOval(rect, _paint(alt ? secondary : primary, fill: fill));
  }

  void rrect(
    Rect rect,
    double radius, {
    bool alt = false,
    bool fill = false,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      _paint(alt ? secondary : primary, fill: fill),
    );
  }

  void path(Path path, {bool alt = false, bool fill = false}) {
    canvas.drawPath(path, _paint(alt ? secondary : primary, fill: fill));
  }

  void dot(double x, double y, {bool alt = false, double r = 1.15}) {
    circle(x, y, r, alt: alt, fill: true);
  }

  void check(double x, double y, double s, {bool alt = false}) {
    final p = Path()
      ..moveTo(x, y + s * 0.45)
      ..lineTo(x + s * 0.35, y + s)
      ..lineTo(x + s, y);
    path(p, alt: alt);
  }
}

void _drawGlyph(_Pen pen, OperonixPremiumGlyph glyph) {
  switch (glyph) {
    case OperonixPremiumGlyph.usersAccess:
      pen.circle(8.2, 8, 2.3);
      pen.path(
        Path()
          ..moveTo(4.2, 16.5)
          ..quadraticBezierTo(8.2, 12.2, 12.2, 16.5),
      );
      _shield(pen, 13.2, 11.2, 8.2, 10.2);
      pen.check(15.2, 14.6, 3.2);
    case OperonixPremiumGlyph.productionCell:
      pen.line(4, 19.5, 12.5, 19.5);
      pen.line(8.2, 19.5, 8.2, 12.2);
      pen.circle(8.2, 11, 1.5);
      pen.line(9.4, 10.2, 16.2, 7.2);
      pen.circle(16.6, 6.8, 1.2);
      pen.line(16.6, 8, 15.2, 10.4);
      pen.line(16.6, 8, 18.4, 9.6);
      pen.rrect(const Rect.fromLTWH(3.2, 16.6, 3.2, 2.6), 0.4, alt: true);
    case OperonixPremiumGlyph.productionOrder:
      pen.rrect(const Rect.fromLTWH(3.2, 4.2, 11.2, 15.6), 1.4);
      pen.rrect(const Rect.fromLTWH(6.2, 2.6, 5.2, 2.8), 0.8, alt: true);
      pen.line(5.6, 9, 12, 9, alt: true);
      pen.line(5.6, 12.2, 11, 12.2, alt: true);
      pen.dot(17.2, 7.2);
      pen.dot(17.2, 13);
      pen.dot(20.2, 17.2);
      pen.line(17.2, 8.4, 17.2, 11.6, alt: true);
      pen.line(17.2, 14.2, 19.4, 16.2, alt: true);
    case OperonixPremiumGlyph.planningFlow:
      pen.line(3, 14, 21, 14);
      pen.circle(6, 14, 1.7);
      pen.circle(12, 14, 1.7);
      pen.circle(18, 14, 1.7, alt: true);
      pen.circle(16.5, 6.5, 3);
      pen.line(16.5, 6.5, 16.5, 4.8, alt: true);
      pen.line(16.5, 6.5, 18.2, 7.4, alt: true);
    case OperonixPremiumGlyph.liveTracking:
      pen.rrect(const Rect.fromLTWH(2.6, 7.5, 11, 10.5), 1.4);
      pen.rrect(const Rect.fromLTWH(4.2, 9.2, 4.2, 3.2), 0.6, alt: true);
      pen.line(4.6, 15.2, 11.2, 15.2, alt: true);
      pen.path(
        Path()
          ..moveTo(15, 14.5)
          ..lineTo(16.8, 9.2)
          ..lineTo(18.6, 15.4)
          ..lineTo(20.8, 10.4),
      );
    case OperonixPremiumGlyph.qualityShield:
      _shield(pen, 4, 2.8, 16, 18.2);
      pen.check(8.2, 10.2, 6.2);
      pen.line(16.2, 5.2, 18.6, 5.2, alt: true);
      pen.line(17.4, 4, 17.4, 6.4, alt: true);
    case OperonixPremiumGlyph.aiInsight:
      pen.path(
        Path()
          ..moveTo(12, 4.2)
          ..lineTo(15.2, 10)
          ..lineTo(12, 15.8)
          ..lineTo(8.8, 10)
          ..close(),
      );
      pen.dot(4.2, 7.2, alt: true);
      pen.dot(19.6, 8.4, alt: true);
      pen.dot(16.8, 18.6, alt: true);
      pen.line(8.8, 9.2, 5.2, 7.6, alt: true);
      pen.line(15.2, 10.2, 18.4, 8.8, alt: true);
      pen.line(13.2, 14.6, 16, 17.6, alt: true);
    case OperonixPremiumGlyph.chemicalDose:
      pen.line(10, 3, 10, 6.2);
      pen.line(14, 3, 14, 6.2);
      pen.line(9.2, 3, 14.8, 3, alt: true);
      pen.path(
        Path()
          ..moveTo(8.2, 7)
          ..lineTo(15.8, 7)
          ..lineTo(18.2, 19.5)
          ..quadraticBezierTo(12, 21.4, 5.8, 19.5)
          ..close(),
      );
      pen.path(
        Path()
          ..moveTo(7.4, 15)
          ..quadraticBezierTo(10, 13.6, 12, 15)
          ..quadraticBezierTo(14.4, 16.4, 16.6, 15),
        alt: true,
      );
    case OperonixPremiumGlyph.productionCount:
      pen.circle(12, 12, 7.2);
      pen.line(12, 12, 12, 7.2);
      pen.line(12, 12, 15.4, 14.2, alt: true);
      pen.dot(12, 12);
      pen.line(12, 5.6, 12, 6.8, alt: true);
      pen.line(18.2, 12, 17, 12, alt: true);
      pen.line(12, 18.4, 12, 17.2, alt: true);
    case OperonixPremiumGlyph.processCheck:
      pen.rrect(const Rect.fromLTWH(3.2, 3.2, 12.2, 17.2), 1.4);
      pen.line(6, 8, 12.2, 8, alt: true);
      pen.line(6, 11.2, 10.4, 11.2, alt: true);
      pen.circle(16.6, 16.2, 4.2);
      pen.check(14.4, 15.2, 3.4);
    case OperonixPremiumGlyph.materialPrep:
      pen.path(
        Path()
          ..moveTo(4, 3.5)
          ..lineTo(20, 3.5)
          ..lineTo(15.2, 10)
          ..lineTo(8.8, 10)
          ..close(),
      );
      pen.rrect(const Rect.fromLTWH(6.2, 11.2, 11.6, 8.6), 1.2);
      pen.line(8.4, 14.2, 15.6, 14.2, alt: true);
      pen.line(12, 11.2, 12, 16.4, alt: true);
    case OperonixPremiumGlyph.wastewater:
      pen.line(4.2, 5, 4.2, 14);
      pen.line(7.2, 5, 7.2, 14);
      pen.line(10.2, 5, 10.2, 14);
      pen.line(3, 5, 11.4, 5, alt: true);
      pen.path(
        Path()
          ..moveTo(12.2, 15)
          ..quadraticBezierTo(15, 12.6, 17.6, 15)
          ..quadraticBezierTo(20.2, 17.4, 21.2, 15.6),
        alt: true,
      );
      pen.path(
        Path()
          ..moveTo(12.2, 18.6)
          ..quadraticBezierTo(15, 16.2, 17.6, 18.6)
          ..quadraticBezierTo(20.2, 21, 21.2, 19.2),
        alt: true,
      );
    case OperonixPremiumGlyph.packingSeal:
      pen.path(
        Path()
          ..moveTo(4, 8)
          ..lineTo(12, 4.2)
          ..lineTo(20, 8)
          ..lineTo(12, 11.8)
          ..close(),
      );
      pen.path(
        Path()
          ..moveTo(4, 8)
          ..lineTo(4, 16.2)
          ..lineTo(12, 20)
          ..lineTo(12, 11.8),
      );
      pen.path(
        Path()
          ..moveTo(20, 8)
          ..lineTo(20, 16.2)
          ..lineTo(12, 20),
        alt: true,
      );
      pen.check(13.2, 13.4, 4.2);
    case OperonixPremiumGlyph.firstPiece:
      pen.rrect(const Rect.fromLTWH(3.2, 3.2, 17.6, 17.6), 2);
      pen.line(11, 7, 11, 16);
      pen.line(8.6, 9.2, 11, 7);
      pen.line(8.8, 16, 13.4, 16, alt: true);
      pen.dot(17.2, 6.2, r: 1.3);
    case OperonixPremiumGlyph.finalInspection:
      _shield(pen, 3.4, 2.6, 17.2, 18.6);
      pen.circle(12, 12, 4.2, alt: true);
      pen.check(9.6, 11.2, 4.4);
    case OperonixPremiumGlyph.machineClean:
      pen.rrect(const Rect.fromLTWH(2.8, 12.2, 12.4, 7.2), 1.2);
      pen.line(5, 15.2, 12.4, 15.2, alt: true);
      pen.line(8, 4, 16.8, 12.2);
      pen.line(10.2, 3.2, 13.4, 6.2, alt: true);
      pen.line(13.2, 6.2, 16.4, 9.4, alt: true);
      pen.line(16.2, 9.2, 19.2, 12.2, alt: true);
    case OperonixPremiumGlyph.workspace5s:
      pen.rrect(const Rect.fromLTWH(3, 3, 8, 8), 1.2);
      pen.rrect(const Rect.fromLTWH(13, 3, 8, 8), 1.2, alt: true);
      pen.rrect(const Rect.fromLTWH(3, 13, 8, 8), 1.2, alt: true);
      pen.rrect(const Rect.fromLTWH(13, 13, 8, 8), 1.2);
      pen.check(14.6, 15.4, 4.2);
    case OperonixPremiumGlyph.openActions:
      pen.path(
        Path()
          ..moveTo(3, 9)
          ..lineTo(7.2, 9)
          ..lineTo(9, 11.6)
          ..lineTo(15, 11.6)
          ..lineTo(16.8, 9)
          ..lineTo(21, 9)
          ..lineTo(19.2, 18.8)
          ..lineTo(4.8, 18.8)
          ..close(),
      );
      pen.circle(17.4, 5.6, 2.3);
      pen.dot(17.4, 5.6, r: 0.9);
    case OperonixPremiumGlyph.methodology:
      pen.path(
        Path()
          ..moveTo(12, 5)
          ..lineTo(4.2, 7.2)
          ..lineTo(4.2, 18.6)
          ..lineTo(12, 16.2)
          ..close(),
      );
      pen.path(
        Path()
          ..moveTo(12, 5)
          ..lineTo(19.8, 7.2)
          ..lineTo(19.8, 18.6)
          ..lineTo(12, 16.2),
        alt: true,
      );
      pen.line(7, 10, 9.6, 9.4, alt: true);
      pen.line(14.4, 9.4, 17, 10, alt: true);
    case OperonixPremiumGlyph.qualityOverview:
      pen.rrect(const Rect.fromLTWH(3, 3.2, 18, 17.6), 2);
      pen.line(7, 16, 7, 11);
      pen.line(12, 16, 12, 8);
      pen.line(17, 16, 17, 12.4, alt: true);
    case OperonixPremiumGlyph.controlledDocument:
      pen.path(
        Path()
          ..moveTo(5, 3)
          ..lineTo(14, 3)
          ..lineTo(19, 8)
          ..lineTo(19, 21)
          ..lineTo(5, 21)
          ..close(),
      );
      pen.path(
        Path()
          ..moveTo(14, 3)
          ..lineTo(14, 8)
          ..lineTo(19, 8),
        alt: true,
      );
      pen.circle(8.6, 14.2, 2.2, alt: true);
      pen.line(7.6, 12.2, 8.6, 10.2, alt: true);
    case OperonixPremiumGlyph.pfmea:
      pen.circle(6, 7, 2);
      pen.circle(17.2, 8.2, 2, alt: true);
      pen.circle(11.2, 17.2, 2);
      pen.line(7.8, 8, 15.4, 8.4, alt: true);
      pen.line(7.2, 8.6, 10, 15.6, alt: true);
      pen.line(16, 10, 12.6, 15.6, alt: true);
      pen.path(
        Path()
          ..moveTo(17.6, 13.2)
          ..lineTo(20.6, 18.4)
          ..lineTo(14.6, 18.4)
          ..close(),
      );
    case OperonixPremiumGlyph.controlPlan:
      pen.path(
        Path()
          ..moveTo(3, 16)
          ..lineTo(8, 16)
          ..lineTo(12, 8)
          ..lineTo(16, 8)
          ..lineTo(21, 14),
      );
      _diamond(pen, 8, 16, 2.1);
      _diamond(pen, 12, 8, 2.1);
      _diamond(pen, 16, 8, 2.1, alt: true);
    case OperonixPremiumGlyph.inspectionRoute:
      pen.line(6.2, 4, 6.2, 20, alt: true);
      pen.circle(6.2, 6, 1.8);
      pen.circle(6.2, 12, 1.8);
      pen.circle(6.2, 18, 1.8, alt: true);
      pen.check(4.8, 5.2, 2.2);
      pen.line(10, 6, 19, 6, alt: true);
      pen.line(10, 12, 17, 12, alt: true);
      pen.line(10, 18, 15, 18, alt: true);
    case OperonixPremiumGlyph.managementReport:
      pen.line(4, 19, 20, 19);
      pen.line(7, 19, 7, 12);
      pen.line(12, 19, 12, 8);
      pen.line(17, 19, 17, 5, alt: true);
      pen.path(
        Path()
          ..moveTo(14.2, 3.2)
          ..lineTo(20.2, 3.2)
          ..lineTo(20.2, 8.2),
        alt: true,
      );
    case OperonixPremiumGlyph.workDay:
      _calendar(pen);
      pen.rrect(
        const Rect.fromLTWH(6.2, 12.2, 11.6, 3.2),
        0.8,
        alt: true,
        fill: true,
      );
    case OperonixPremiumGlyph.entryDate:
      _calendar(pen);
      pen.line(14.2, 12.2, 18.6, 16.6);
      pen.line(13.2, 16.8, 16.2, 16.8, alt: true);
    case OperonixPremiumGlyph.plant:
      pen.path(
        Path()
          ..moveTo(2.6, 20)
          ..lineTo(2.6, 10)
          ..lineTo(10.4, 6.2)
          ..lineTo(10.4, 20),
      );
      pen.rrect(const Rect.fromLTWH(10.4, 9.2, 10.6, 10.8), 0.6, alt: true);
      pen.line(14.2, 4, 14.2, 9.2);
      pen.line(17.2, 5.2, 17.2, 9.2, alt: true);
      pen.rrect(const Rect.fromLTWH(5, 14.2, 2.8, 5.8), 0.4);
    case OperonixPremiumGlyph.readyStatus:
      pen.circle(12, 12, 7.4);
      pen.check(8.4, 11.2, 6);
      pen.path(
        Path()
          ..moveTo(18.2, 6.4)
          ..arcToPoint(const Offset(20.4, 12), radius: const Radius.circular(6)),
        alt: true,
      );
    case OperonixPremiumGlyph.quickEntry:
      pen.path(
        Path()
          ..moveTo(13, 3)
          ..lineTo(6.2, 13)
          ..lineTo(11.2, 13)
          ..lineTo(9.4, 21)
          ..lineTo(17.8, 10.2)
          ..lineTo(12.6, 10.2)
          ..close(),
      );
    case OperonixPremiumGlyph.manualEntry:
      pen.line(4, 7, 13, 7, alt: true);
      pen.line(4, 11.5, 12, 11.5, alt: true);
      pen.line(4, 16, 10, 16, alt: true);
      pen.path(
        Path()
          ..moveTo(14, 14.5)
          ..lineTo(19.4, 5.2)
          ..lineTo(20.6, 6)
          ..lineTo(15.2, 15.4)
          ..close(),
      );
    case OperonixPremiumGlyph.qrScan:
      _corner(pen, 3, 3, 1, 1);
      _corner(pen, 21, 3, -1, 1);
      _corner(pen, 3, 21, 1, -1);
      _corner(pen, 21, 21, -1, -1);
      pen.rrect(const Rect.fromLTWH(9.2, 9.2, 5.6, 5.6), 0.8);
    case OperonixPremiumGlyph.closeBox:
      pen.rrect(const Rect.fromLTWH(3.2, 8, 17.6, 12), 1.2);
      pen.path(
        Path()
          ..moveTo(3.2, 8)
          ..lineTo(7.2, 4)
          ..lineTo(16.8, 4)
          ..lineTo(20.8, 8),
      );
      pen.line(12, 4, 12, 12.4, alt: true);
      pen.line(9.2, 10.2, 12, 12.6, alt: true);
      pen.line(14.8, 10.2, 12, 12.6, alt: true);
    case OperonixPremiumGlyph.labelPrint:
      pen.path(
        Path()
          ..moveTo(4, 6)
          ..lineTo(15, 6)
          ..lineTo(20, 11)
          ..lineTo(20, 18)
          ..lineTo(4, 18)
          ..close(),
      );
      pen.circle(8.2, 12, 1.5, alt: true);
      pen.line(11.2, 11, 16.4, 11, alt: true);
      pen.line(11.2, 14.2, 15, 14.2, alt: true);
    case OperonixPremiumGlyph.tableColumns:
      pen.rrect(const Rect.fromLTWH(3, 4, 18, 16), 1.4);
      pen.line(9, 4, 9, 20);
      pen.line(15, 4, 15, 20, alt: true);
      pen.line(3, 9, 21, 9, alt: true);
    case OperonixPremiumGlyph.quantity:
      pen.rrect(const Rect.fromLTWH(3, 13, 4.2, 6.5), 0.8);
      pen.rrect(const Rect.fromLTWH(9, 9, 4.2, 10.5), 0.8);
      pen.rrect(const Rect.fromLTWH(15, 4.5, 4.2, 15), 0.8, alt: true);
      pen.line(5, 6.2, 5, 10, alt: true);
      pen.line(3.2, 8.1, 6.8, 8.1, alt: true);
    case OperonixPremiumGlyph.kpiTotal:
      _kpiPlate(pen);
      pen.dot(15.2, 9.2);
      pen.dot(18.6, 9.2, alt: true);
      pen.dot(15.2, 13.2, alt: true);
      pen.dot(18.6, 13.2);
    case OperonixPremiumGlyph.kpiOpen:
      _kpiPlate(pen);
      pen.circle(16.8, 11.2, 3.1);
      pen.circle(16.8, 11.2, 1.2, alt: true);
    case OperonixPremiumGlyph.kpiRunning:
      _kpiPlate(pen);
      pen.path(
        Path()
          ..moveTo(14.6, 8.2)
          ..lineTo(19.6, 11.4)
          ..lineTo(14.6, 14.6)
          ..close(),
      );
    case OperonixPremiumGlyph.kpiDone:
      _kpiPlate(pen);
      pen.check(14.2, 10, 4.6);
    case OperonixPremiumGlyph.products:
      pen.rrect(const Rect.fromLTWH(3, 12, 8, 7.2), 1);
      pen.rrect(const Rect.fromLTWH(12.2, 12, 8.4, 7.2), 1, alt: true);
      pen.rrect(const Rect.fromLTWH(7.4, 4.2, 8.6, 7), 1);
    case OperonixPremiumGlyph.workCenter:
      pen.rrect(const Rect.fromLTWH(2.8, 10, 12.4, 9.2), 1.2);
      pen.line(5.2, 13.2, 12.2, 13.2, alt: true);
      pen.circle(17.2, 7.2, 3.4);
      pen.circle(17.2, 7.2, 1.2, alt: true);
      pen.line(17.2, 3.2, 17.2, 4.4, alt: true);
      pen.line(20.4, 7.2, 19.2, 7.2, alt: true);
    case OperonixPremiumGlyph.process:
      pen.circle(6, 6.5, 2);
      pen.circle(18, 6.5, 2, alt: true);
      pen.circle(12, 17.2, 2.2);
      pen.line(7.6, 7.6, 10.6, 15.4, alt: true);
      pen.line(16.4, 7.6, 13.4, 15.4, alt: true);
    case OperonixPremiumGlyph.workforce:
      pen.circle(8, 8, 2.2);
      pen.circle(15.6, 8.4, 2, alt: true);
      pen.path(
        Path()
          ..moveTo(3.6, 17.8)
          ..quadraticBezierTo(8, 13, 12.2, 17.8),
      );
      pen.path(
        Path()
          ..moveTo(12.4, 18)
          ..quadraticBezierTo(15.6, 14, 20.4, 17.6),
        alt: true,
      );
    case OperonixPremiumGlyph.downtime:
      pen.rrect(const Rect.fromLTWH(4, 4, 4.2, 16), 1);
      pen.rrect(const Rect.fromLTWH(11, 4, 4.2, 16), 1, alt: true);
      pen.path(
        Path()
          ..moveTo(18.2, 12)
          ..lineTo(21.4, 17.6)
          ..lineTo(15, 17.6)
          ..close(),
      );
    case OperonixPremiumGlyph.reports:
      pen.line(4, 19, 20, 19);
      pen.line(6.5, 19, 6.5, 13);
      pen.line(11, 19, 11, 8);
      pen.line(15.5, 19, 15.5, 11, alt: true);
      pen.line(12, 5, 19, 5, alt: true);
      pen.line(19, 5, 19, 10, alt: true);
    case OperonixPremiumGlyph.logistics:
      pen.rrect(const Rect.fromLTWH(3, 3.2, 18, 17.6), 1.2);
      pen.line(3, 9, 21, 9);
      pen.line(3, 14.6, 21, 14.6, alt: true);
      pen.line(9, 3.2, 9, 20.8, alt: true);
    case OperonixPremiumGlyph.orders:
      pen.rrect(const Rect.fromLTWH(5, 2.8, 14, 18.4), 1.4);
      pen.line(8, 8, 16, 8, alt: true);
      pen.line(8, 12, 16, 12, alt: true);
      pen.line(8, 16, 13, 16, alt: true);
    case OperonixPremiumGlyph.partners:
      pen.circle(8, 12, 3.2);
      pen.circle(16, 12, 3.2, alt: true);
      pen.line(10.6, 12, 13.4, 12);
    case OperonixPremiumGlyph.finance:
      pen.path(
        Path()
          ..moveTo(3, 9)
          ..lineTo(12, 4)
          ..lineTo(21, 9),
      );
      pen.line(6, 9, 6, 18);
      pen.line(12, 9, 12, 18, alt: true);
      pen.line(18, 9, 18, 18);
      pen.line(3.5, 18, 20.5, 18);
    case OperonixPremiumGlyph.development:
      pen.rrect(const Rect.fromLTWH(2.6, 5, 5, 14), 1);
      pen.rrect(const Rect.fromLTWH(9.5, 5, 5, 14), 1, alt: true);
      pen.rrect(const Rect.fromLTWH(16.4, 5, 5, 14), 1);
      pen.line(5.1, 9, 5.1, 15, alt: true);
      pen.check(17.2, 10, 3);
    case OperonixPremiumGlyph.carbon:
      pen.circle(12, 12, 8);
      pen.path(
        Path()
          ..moveTo(12, 17.2)
          ..quadraticBezierTo(7.2, 14, 9.2, 8.2)
          ..quadraticBezierTo(14.6, 8.6, 16.4, 12.4)
          ..quadraticBezierTo(14.2, 14.8, 12, 17.2),
        alt: true,
      );
    case OperonixPremiumGlyph.maintenance:
      pen.path(
        Path()
          ..moveTo(14.2, 4)
          ..lineTo(20, 9.8)
          ..lineTo(17.2, 12.6)
          ..lineTo(11.4, 6.8)
          ..close(),
      );
      pen.line(12.6, 11.2, 4.2, 19.6);
      pen.circle(5.2, 18.2, 1.6, alt: true);
    case OperonixPremiumGlyph.station:
      pen.rrect(const Rect.fromLTWH(3, 3.2, 18, 12.4), 1.4);
      pen.line(9, 15.6, 15, 15.6, alt: true);
      pen.line(12, 15.6, 12, 19.2);
      pen.line(8, 19.2, 16, 19.2);
      pen.circle(7, 9.2, 1.3, alt: true);
    case OperonixPremiumGlyph.deviceWorkMode:
      pen.rrect(const Rect.fromLTWH(5.2, 2.4, 9.2, 17.2), 2);
      pen.line(7.4, 5.6, 12.2, 5.6, alt: true);
      pen.rrect(const Rect.fromLTWH(7.2, 14.2, 5.2, 2.4), 1.2, alt: true);
      pen.circle(11.2, 15.4, 1.15, fill: true);
      pen.line(16.2, 8.2, 20.2, 6.2, alt: true);
      pen.line(16.2, 12.2, 20.2, 14.2, alt: true);
    case OperonixPremiumGlyph.stationPreparation:
      pen.path(
        Path()
          ..moveTo(2.4, 4.2)
          ..lineTo(8.4, 4.2)
          ..lineTo(7.2, 8.4)
          ..lineTo(3.6, 8.4)
          ..close(),
      );
      pen.line(7.6, 6.4, 10.2, 8.6, alt: true);
      pen.rrect(const Rect.fromLTWH(9.2, 7.2, 11.2, 10.6), 1.4);
      pen.check(11.4, 10.6, 5);
      pen.line(10.4, 17.8, 19.2, 17.8);
    case OperonixPremiumGlyph.stationFirstControl:
      pen.path(
        Path()
          ..moveTo(3.4, 15.6)
          ..quadraticBezierTo(12, 3.2, 20.6, 15.6),
      );
      pen.line(12, 15.2, 15.6, 9.4);
      pen.dot(12, 15.2);
      pen.line(4.2, 18.4, 19.8, 18.4, alt: true);
      pen.line(5.2, 6.2, 5.2, 11.2, alt: true);
      pen.line(3.8, 8, 5.2, 6.2, alt: true);
    case OperonixPremiumGlyph.stationFinalControl:
      pen.path(
        Path()
          ..moveTo(3.2, 19)
          ..lineTo(3.2, 9.2)
          ..quadraticBezierTo(12, 2.2, 20.8, 9.2)
          ..lineTo(20.8, 19),
      );
      pen.line(7.2, 19, 16.8, 19, alt: true);
      pen.check(8.6, 11.2, 6.2);
    case OperonixPremiumGlyph.stationNetwork:
      pen.rrect(const Rect.fromLTWH(2.2, 9.2, 5.6, 5.2), 1.1);
      pen.rrect(const Rect.fromLTWH(9.2, 3.2, 5.6, 5.2), 1.1, alt: true);
      pen.rrect(const Rect.fromLTWH(16.2, 12.2, 5.6, 5.2), 1.1);
      pen.line(7.6, 11.2, 9.4, 7.2, alt: true);
      pen.line(14.6, 7.6, 16.4, 12.6, alt: true);
      pen.line(7.8, 12.4, 16.2, 14.2, alt: true);
    case OperonixPremiumGlyph.productionStations:
      pen.rrect(const Rect.fromLTWH(2.2, 6.2, 5.4, 11.6), 1);
      pen.rrect(const Rect.fromLTWH(9.3, 6.2, 5.4, 11.6), 1, alt: true);
      pen.rrect(const Rect.fromLTWH(16.4, 6.2, 5.4, 11.6), 1);
      pen.line(3.4, 9.2, 6.2, 9.2, alt: true);
      pen.line(10.5, 9.2, 13.3, 9.2, alt: true);
      pen.line(17.6, 9.2, 20.4, 9.2, alt: true);
    case OperonixPremiumGlyph.analytics:
      pen.path(
        Path()
          ..moveTo(3, 16)
          ..lineTo(7.2, 12)
          ..lineTo(11, 14.2)
          ..lineTo(16.2, 7.2)
          ..lineTo(21, 9.4),
      );
      pen.dot(16.2, 7.2);
      pen.line(3, 19, 21, 19, alt: true);
    case OperonixPremiumGlyph.attention:
      pen.path(
        Path()
          ..moveTo(12, 3.2)
          ..lineTo(17.4, 8.2)
          ..lineTo(17.4, 13)
          ..quadraticBezierTo(17.4, 16.2, 14.6, 17.4)
          ..lineTo(9.4, 17.4)
          ..quadraticBezierTo(6.6, 16.2, 6.6, 13)
          ..lineTo(6.6, 8.2)
          ..close(),
      );
      pen.line(10, 17.6, 14, 17.6, alt: true);
      pen.circle(12, 19.6, 1, alt: true, fill: true);
      pen.dot(17.8, 5.2, r: 1.4);
    case OperonixPremiumGlyph.ncr:
      pen.rrect(const Rect.fromLTWH(4, 3, 16, 18), 1.6);
      pen.path(
        Path()
          ..moveTo(12, 7)
          ..lineTo(16.2, 14.4)
          ..lineTo(7.8, 14.4)
          ..close(),
      );
      pen.line(12, 9.4, 12, 12, alt: true);
      pen.dot(12, 13.2, alt: true, r: 0.7);
    case OperonixPremiumGlyph.capa:
      pen.path(
        Path()
          ..moveTo(16, 6)
          ..arcToPoint(
            const Offset(8, 8),
            radius: const Radius.circular(6),
            clockwise: false,
          ),
      );
      pen.path(
        Path()
          ..moveTo(8, 18)
          ..arcToPoint(
            const Offset(16, 16),
            radius: const Radius.circular(6),
          ),
        alt: true,
      );
      pen.line(14.2, 3.6, 16.6, 6);
      pen.line(16.6, 6, 13.4, 7.2);
      pen.check(10, 11, 3.2);
    case OperonixPremiumGlyph.audit:
      pen.rrect(const Rect.fromLTWH(4, 3, 12, 16), 1.4);
      pen.line(7, 8, 13, 8, alt: true);
      pen.line(7, 11.5, 12, 11.5, alt: true);
      pen.circle(16.4, 16.2, 4);
      pen.check(14.4, 15.4, 3.2);
    case OperonixPremiumGlyph.history:
      pen.circle(12, 12, 7.2);
      pen.line(12, 12, 12, 7.4);
      pen.line(12, 12, 15.6, 14, alt: true);
      pen.path(
        Path()
          ..moveTo(6.2, 5.2)
          ..lineTo(4.2, 8.4)
          ..lineTo(8, 8.2),
        alt: true,
      );
    case OperonixPremiumGlyph.about:
      pen.circle(12, 12, 8);
      pen.line(12, 11, 12, 16.4);
      pen.dot(12, 8, r: 1.05);
    case OperonixPremiumGlyph.appearance:
      pen.circle(8, 12, 4.2);
      pen.circle(15.2, 8.4, 3, alt: true);
      pen.circle(16.4, 15.6, 2.4, alt: true);
    case OperonixPremiumGlyph.evidence:
      pen.rrect(const Rect.fromLTWH(4, 3, 16, 18), 1.6);
      pen.line(7.5, 8, 16, 8, alt: true);
      pen.line(7.5, 12, 16, 12, alt: true);
      pen.line(7.5, 16, 13, 16, alt: true);
  }
}

void _shield(_Pen pen, double x, double y, double w, double h) {
  pen.path(
    Path()
      ..moveTo(x + w / 2, y)
      ..lineTo(x + w, y + h * 0.18)
      ..lineTo(x + w, y + h * 0.48)
      ..quadraticBezierTo(x + w, y + h * 0.82, x + w / 2, y + h)
      ..quadraticBezierTo(x, y + h * 0.82, x, y + h * 0.48)
      ..lineTo(x, y + h * 0.18)
      ..close(),
  );
}

void _calendar(_Pen pen) {
  pen.rrect(const Rect.fromLTWH(3.2, 4.6, 17.6, 15.2), 1.6);
  pen.line(3.2, 9, 20.8, 9);
  pen.line(8, 3, 8, 6.2, alt: true);
  pen.line(16, 3, 16, 6.2, alt: true);
}

void _diamond(_Pen pen, double x, double y, double r, {bool alt = false}) {
  pen.path(
    Path()
      ..moveTo(x, y - r)
      ..lineTo(x + r, y)
      ..lineTo(x, y + r)
      ..lineTo(x - r, y)
      ..close(),
    alt: alt,
  );
}

void _kpiPlate(_Pen pen) {
  pen.rrect(const Rect.fromLTWH(2.8, 5, 9.2, 14), 1.6);
  pen.line(5, 9, 9.6, 9, alt: true);
  pen.line(5, 12.2, 8.4, 12.2, alt: true);
}

void _corner(_Pen pen, double x, double y, double dx, double dy) {
  final arm = 4.4;
  pen.path(
    Path()
      ..moveTo(x + dx * arm, y)
      ..lineTo(x, y)
      ..lineTo(x, y + dy * arm),
  );
}
