import 'package:flutter/material.dart';

import 'operonix_premium_icon.dart';

/// Duotone piktogrami. Jedna porodica: puni oblik, mekši drugi ton, jedan detalj.
class OperonixPremiumPictogram {
  const OperonixPremiumPictogram._();

  static void paint({
    required Canvas canvas,
    required Size size,
    required OperonixPremiumGlyph glyph,
    required Color color,
  }) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    final g = _G(canvas, color);
    switch (glyph) {
      case OperonixPremiumGlyph.usersAccess:
        _users(g);
      case OperonixPremiumGlyph.productionCell:
        _press(g);
      case OperonixPremiumGlyph.productionOrder:
        _order(g);
      case OperonixPremiumGlyph.planningFlow:
        _planning(g);
      case OperonixPremiumGlyph.liveTracking:
        _tracking(g);
      case OperonixPremiumGlyph.qualityShield:
        _shieldMark(g, 4.2, 2.2, 15.6, 18.4);
      case OperonixPremiumGlyph.aiInsight:
        _insight(g);
      case OperonixPremiumGlyph.chemicalDose:
        _beaker(g);
      case OperonixPremiumGlyph.productionCount:
        _count(g);
      case OperonixPremiumGlyph.processCheck:
        _processDoc(g);
      case OperonixPremiumGlyph.materialPrep:
        _scoopBin(g);
      case OperonixPremiumGlyph.wastewater:
        _tank(g);
      case OperonixPremiumGlyph.packingSeal:
        _sealedBox(g);
      case OperonixPremiumGlyph.firstPiece:
        _stampedPart(g);
      case OperonixPremiumGlyph.finalInspection:
        _gaugeProduct(g);
      case OperonixPremiumGlyph.machineClean:
        _brushMachine(g);
      case OperonixPremiumGlyph.workspace5s:
        _floorGrid(g);
      case OperonixPremiumGlyph.openActions:
        _tray(g);
      case OperonixPremiumGlyph.methodology:
        _book(g);
      case OperonixPremiumGlyph.qualityOverview:
        _shieldBars(g);
      case OperonixPremiumGlyph.controlledDocument:
        _lockedDoc(g);
      case OperonixPremiumGlyph.pfmea:
        _alertSheet(g);
      case OperonixPremiumGlyph.controlPlan:
        _checks(g);
      case OperonixPremiumGlyph.inspectionRoute:
        _route(g);
      case OperonixPremiumGlyph.managementReport:
        _reportBars(g);
      case OperonixPremiumGlyph.workDay:
        _calendar(g, sun: true);
      case OperonixPremiumGlyph.entryDate:
        _calendar(g, sun: false);
      case OperonixPremiumGlyph.plant:
        _plant(g);
      case OperonixPremiumGlyph.readyStatus:
        _ready(g);
      case OperonixPremiumGlyph.quickEntry:
        _boltCard(g);
      case OperonixPremiumGlyph.manualEntry:
        _pencilCard(g);
      case OperonixPremiumGlyph.qrScan:
        _qr(g);
      case OperonixPremiumGlyph.closeBox:
        _openLid(g);
      case OperonixPremiumGlyph.labelPrint:
        _label(g);
      case OperonixPremiumGlyph.tableColumns:
        _columns(g);
      case OperonixPremiumGlyph.quantity:
        _cubes(g);
      case OperonixPremiumGlyph.kpiTotal:
        _kpiStack(g);
      case OperonixPremiumGlyph.kpiOpen:
        _kpiClock(g);
      case OperonixPremiumGlyph.kpiRunning:
        _kpiPlay(g);
      case OperonixPremiumGlyph.kpiDone:
        _kpiCheck(g);
      case OperonixPremiumGlyph.products:
        _products(g);
      case OperonixPremiumGlyph.workCenter:
        _bay(g);
      case OperonixPremiumGlyph.process:
        _flowNodes(g);
      case OperonixPremiumGlyph.workforce:
        _crew(g);
      case OperonixPremiumGlyph.downtime:
        _paused(g);
      case OperonixPremiumGlyph.reports:
        _chart(g);
      case OperonixPremiumGlyph.logistics:
        _warehouse(g);
      case OperonixPremiumGlyph.orders:
        _sheets(g);
      case OperonixPremiumGlyph.partners:
        _partners(g);
      case OperonixPremiumGlyph.finance:
        _ledger(g);
      case OperonixPremiumGlyph.development:
        _blueprint(g);
      case OperonixPremiumGlyph.carbon:
        _leaf(g);
      case OperonixPremiumGlyph.maintenance:
        _wrenchGear(g);
      case OperonixPremiumGlyph.station:
        _singleBay(g);
      case OperonixPremiumGlyph.deviceWorkMode:
        _tablet(g);
      case OperonixPremiumGlyph.stationPreparation:
        _prep(g);
      case OperonixPremiumGlyph.stationFirstControl:
        _caliper(g);
      case OperonixPremiumGlyph.stationFinalControl:
        _finalGate(g);
      case OperonixPremiumGlyph.stationNetwork:
        _cells(g);
      case OperonixPremiumGlyph.productionStations:
        _bays(g);
      case OperonixPremiumGlyph.analytics:
        _rising(g);
      case OperonixPremiumGlyph.attention:
        _pin(g);
      case OperonixPremiumGlyph.ncr:
        _ncr(g);
      case OperonixPremiumGlyph.capa:
        _loop(g);
      case OperonixPremiumGlyph.audit:
        _lens(g);
      case OperonixPremiumGlyph.history:
        _history(g);
      case OperonixPremiumGlyph.about:
        _about(g);
      case OperonixPremiumGlyph.appearance:
        _swatches(g);
      case OperonixPremiumGlyph.evidence:
        _logbook(g);
    }
    canvas.restore();
  }
}

class _G {
  _G(this.canvas, Color color)
    : ink = (Paint()
        ..color = color
        ..style = PaintingStyle.fill),
      wash = (Paint()
        ..color = color.withValues(alpha: 0.40)
        ..style = PaintingStyle.fill),
      line = (Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round),
      lite = (Paint()
        ..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.72)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);

  final Canvas canvas;
  final Paint ink;
  final Paint wash;
  final Paint line;
  final Paint lite;

  void box(double x, double y, double w, double h, double r, {bool soft = false}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
      soft ? wash : ink,
    );
  }

  void disc(double x, double y, double r, {bool soft = false}) {
    canvas.drawCircle(Offset(x, y), r, soft ? wash : ink);
  }

  void shape(Path path, {bool soft = false}) {
    canvas.drawPath(path, soft ? wash : ink);
  }

  void stroke(Path path, {bool light = false}) {
    canvas.drawPath(path, light ? lite : line);
  }

  void seg(double x1, double y1, double x2, double y2, {bool light = false}) {
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), light ? lite : line);
  }
}

Path _shield(double x, double y, double w, double h) {
  return Path()
    ..moveTo(x, y)
    ..lineTo(x + w, y)
    ..lineTo(x + w, y + h * 0.58)
    ..quadraticBezierTo(x + w / 2, y + h, x, y + h * 0.58)
    ..close();
}

Path _check(double x, double y, double s) {
  return Path()
    ..moveTo(x, y + s * 0.48)
    ..lineTo(x + s * 0.36, y + s)
    ..lineTo(x + s, y);
}

void _shieldMark(_G g, double x, double y, double w, double h) {
  g.shape(_shield(x, y, w, h));
  g.stroke(_check(x + w * 0.26, y + h * 0.34, w * 0.48), light: true);
}

void _users(_G g) {
  g.disc(8, 7.2, 2.5, soft: true);
  g.shape(
    Path()
      ..moveTo(3.2, 17.6)
      ..quadraticBezierTo(8, 12.2, 12.8, 17.6)
      ..lineTo(3.2, 17.6)
      ..close(),
    soft: true,
  );
  g.disc(15.4, 8.4, 2.7);
  g.shape(
    Path()
      ..moveTo(10.6, 19.4)
      ..quadraticBezierTo(15.4, 13.2, 20.4, 19.4)
      ..close(),
  );
}

void _press(_G g) {
  g.box(3, 13.5, 14, 6.2, 1.3, soft: true);
  g.box(5, 7.2, 10, 6.6, 1.2);
  g.box(7.2, 3.2, 5.6, 4.2, 1);
  g.box(6.2, 16.2, 2.1, 3.2, 0.4);
  g.box(12.2, 16.2, 2.1, 3.2, 0.4);
}

void _order(_G g) {
  g.box(3.4, 3.6, 12.4, 16.8, 1.7, soft: true);
  g.box(6.6, 1.6, 6, 3.4, 1);
  g.box(5.6, 7.4, 8, 1.15, 0.4);
  g.box(5.6, 10, 6.2, 1.15, 0.4);
  g.box(5.6, 12.6, 7.2, 1.15, 0.4);
  g.disc(17.6, 15.2, 1.25);
  g.disc(21, 19.6, 1.25);
  g.seg(17.8, 16.2, 20.6, 18.6);
}

void _planning(_G g) {
  g.box(2, 5.4, 11.2, 2.6, 0.8);
  g.box(4.4, 9.6, 8.4, 2.6, 0.8, soft: true);
  g.box(2, 13.8, 6.6, 2.6, 0.8);
  g.box(2, 18.8, 13, 1.35, 0.5, soft: true);
  g.disc(19.2, 6.6, 3.2, soft: true);
  g.seg(19.2, 6.6, 19.2, 4.4);
  g.seg(19.2, 6.6, 21.3, 7.6);
}

void _tracking(_G g) {
  g.box(2, 14.2, 12.6, 6, 1.3, soft: true);
  g.box(3.4, 8.4, 9.8, 6.2, 1.2);
  g.box(5.2, 4, 6.2, 4.6, 1);
  final pulse = Path()
    ..moveTo(15.6, 14.2)
    ..lineTo(17.2, 14.2)
    ..lineTo(18.2, 8.6)
    ..lineTo(19.6, 17.2)
    ..lineTo(20.8, 11.4)
    ..lineTo(22.4, 11.4);
  g.stroke(pulse);
}

void _insight(_G g) {
  g.disc(6.2, 15.4, 2.5, soft: true);
  g.disc(17.2, 6.4, 2.8);
  g.disc(16.4, 16.6, 2.2, soft: true);
  g.seg(8.4, 14.2, 14.8, 8.2);
  g.seg(8.2, 16.2, 14.4, 16.4);
}

void _beaker(_G g) {
  final flask = Path()
    ..moveTo(9, 2.4)
    ..lineTo(15, 2.4)
    ..lineTo(15, 8)
    ..lineTo(20.2, 19.2)
    ..quadraticBezierTo(12, 22.4, 3.8, 19.2)
    ..lineTo(9, 8)
    ..close();
  g.shape(flask, soft: true);
  g.box(8.6, 14.2, 6.8, 4.2, 1);
  g.disc(17.6, 5.2, 1.5);
}

void _count(_G g) {
  g.box(3, 15.2, 14, 4.2, 1, soft: true);
  g.box(4.2, 10.2, 11.6, 4.2, 1);
  g.box(5.6, 5.2, 9, 4.2, 1, soft: true);
  g.box(16.8, 8.4, 4.6, 8.8, 1);
}

void _processDoc(_G g) {
  g.box(2, 2.6, 12.2, 18.6, 1.5, soft: true);
  g.box(4.2, 6.2, 7.6, 1.15, 0.4);
  g.box(4.2, 9, 5.8, 1.15, 0.4);
  g.box(4.2, 11.8, 6.6, 1.15, 0.4);
  g.disc(18.4, 6.2, 1.55);
  g.disc(18.4, 12, 1.55);
  g.disc(18.4, 17.8, 1.55, soft: true);
  g.seg(18.4, 7.8, 18.4, 10.4);
  g.seg(18.4, 13.6, 18.4, 16.2);
}

void _scoopBin(_G g) {
  g.shape(
    Path()
      ..moveTo(2.2, 8)
      ..lineTo(9.4, 8)
      ..lineTo(11.2, 12)
      ..lineTo(11.2, 20)
      ..lineTo(2.2, 20)
      ..close(),
    soft: true,
  );
  g.box(4, 13.4, 2.4, 2.4, 0.4);
  g.box(7, 15.4, 2.4, 2.4, 0.4);
  g.shape(
    Path()
      ..moveTo(14, 6)
      ..quadraticBezierTo(21.5, 6, 21.5, 12.2)
      ..lineTo(16.2, 12.2)
      ..quadraticBezierTo(16.2, 9, 14, 9)
      ..close(),
  );
  g.box(14.6, 12, 1.8, 7.2, 0.7);
}

void _tank(_G g) {
  g.box(4, 6, 12, 14, 2, soft: true);
  g.shape(
    Path()
      ..moveTo(5, 14)
      ..quadraticBezierTo(8, 11.4, 10, 14)
      ..quadraticBezierTo(13, 16.6, 15, 14)
      ..lineTo(15, 18.4)
      ..lineTo(5, 18.4)
      ..close(),
  );
  g.disc(19.2, 8, 2.2);
  g.seg(19.2, 10.2, 19.2, 16);
}

void _sealedBox(_G g) {
  g.shape(
    Path()
      ..moveTo(4, 9)
      ..lineTo(12, 5)
      ..lineTo(20, 9)
      ..lineTo(12, 13)
      ..close(),
    soft: true,
  );
  g.shape(
    Path()
      ..moveTo(4, 9)
      ..lineTo(12, 13)
      ..lineTo(12, 20)
      ..lineTo(4, 16)
      ..close(),
  );
  g.shape(
    Path()
      ..moveTo(12, 13)
      ..lineTo(20, 9)
      ..lineTo(20, 16)
      ..lineTo(12, 20)
      ..close(),
    soft: true,
  );
  g.seg(12, 5, 12, 20, light: true);
}

void _stampedPart(_G g) {
  g.box(2.4, 6.4, 12.4, 11.2, 1.4);
  g.disc(17.6, 8.2, 3.6, soft: true);
  g.seg(17.6, 6.2, 17.6, 10.2, light: true);
}

void _gaugeProduct(_G g) {
  g.box(2.2, 12.4, 11.5, 7.4, 1.2, soft: true);
  g.shape(
    Path()
      ..moveTo(5, 6.2)
      ..arcToPoint(const Offset(19.4, 6.2), radius: const Radius.circular(8), clockwise: false)
      ..lineTo(17.2, 12.4)
      ..arcToPoint(const Offset(7.2, 12.4), radius: const Radius.circular(5))
      ..close(),
  );
  g.seg(12.2, 11.6, 15.6, 7.4, light: true);
}

void _brushMachine(_G g) {
  g.box(2, 12, 11, 7.2, 1.2, soft: true);
  g.box(4, 7.2, 7, 5, 1);
  g.box(15.2, 4, 2.2, 8.4, 0.8);
  g.seg(14.2, 12.6, 14.2, 19);
  g.seg(16.3, 12.6, 16.3, 19);
  g.seg(18.4, 12.6, 18.4, 19);
}

void _floorGrid(_G g) {
  g.box(3, 3, 8, 8, 1.2, soft: true);
  g.box(13, 3, 8, 8, 1.2);
  g.box(3, 13, 8, 8, 1.2);
  g.box(13, 13, 8, 8, 1.2, soft: true);
  g.stroke(_check(5.2, 15.2, 4.2), light: true);
}

void _tray(_G g) {
  g.box(6.4, 3.2, 10, 3.4, 0.8, soft: true);
  g.box(4.2, 6.2, 12.2, 6.4, 1.2);
  g.box(2, 12.2, 20, 8.2, 1.8, soft: true);
  g.disc(19.2, 5.2, 2.05);
}

void _book(_G g) {
  g.shape(
    Path()
      ..moveTo(12, 4)
      ..lineTo(4, 6)
      ..lineTo(4, 19)
      ..lineTo(12, 17)
      ..close(),
    soft: true,
  );
  g.shape(
    Path()
      ..moveTo(12, 4)
      ..lineTo(20, 6)
      ..lineTo(20, 19)
      ..lineTo(12, 17)
      ..close(),
  );
  g.seg(12, 4.4, 12, 16.8, light: true);
}

void _shieldBars(_G g) {
  g.shape(_shield(2.2, 2.4, 11, 14));
  g.box(14.2, 14, 2.4, 6, 0.5, soft: true);
  g.box(17.6, 10, 2.4, 10, 0.5);
  g.box(21, 6.5, 1.6, 13.5, 0.4, soft: true);
}

void _lockedDoc(_G g) {
  g.box(3, 3, 12, 17.5, 1.5, soft: true);
  g.box(6, 7, 6, 1.1, 0.4);
  g.box(6, 9.6, 4.4, 1.1, 0.4);
  g.disc(17.6, 13.2, 3.3);
  g.box(16.2, 14.6, 2.8, 4.2, 0.5, soft: true);
}

void _alertSheet(_G g) {
  g.box(2, 6, 11, 14, 1.3, soft: true);
  g.shape(
    Path()
      ..moveTo(16.2, 19.6)
      ..lineTo(11.2, 8.4)
      ..lineTo(21.2, 8.4)
      ..close(),
  );
  g.seg(16.2, 11.2, 16.2, 14.4, light: true);
  g.disc(16.2, 16.4, 0.7);
}

void _checks(_G g) {
  g.box(3, 3, 14, 18, 1.6, soft: true);
  g.stroke(_check(5.2, 7, 3.2));
  g.box(10, 8.2, 5, 1.1, 0.4);
  g.stroke(_check(5.2, 13, 3.2));
  g.box(10, 14.2, 5, 1.1, 0.4);
}

void _route(_G g) {
  g.disc(5, 6, 2.2);
  g.disc(12, 12, 2.2, soft: true);
  g.disc(18.6, 18, 2.2);
  g.seg(6.8, 7.2, 10.2, 10.6);
  g.seg(13.8, 13.4, 16.8, 16.4);
}

void _reportBars(_G g) {
  g.box(2.2, 2.4, 13, 19, 1.5, soft: true);
  g.box(5, 13, 2.2, 5, 0.4);
  g.box(8.4, 9, 2.2, 9, 0.4);
  g.box(11.8, 6, 2.2, 12, 0.4, soft: true);
}

void _calendar(_G g, {required bool sun}) {
  g.box(3, 4.4, 14, 15.2, 1.6, soft: true);
  g.box(3, 4.4, 14, 4, 1);
  g.box(6.2, 2.2, 1.6, 3.4, 0.5);
  g.box(12.2, 2.2, 1.6, 3.4, 0.5);
  if (sun) {
    g.disc(18.8, 15.6, 3.2);
  } else {
    g.box(6.2, 11, 7.4, 1.2, 0.4);
    g.box(6.2, 14, 5, 1.2, 0.4);
  }
}

void _plant(_G g) {
  g.box(3, 11, 18, 9, 1, soft: true);
  g.box(8, 4.2, 5.2, 7, 0.6);
  g.box(5.2, 14.2, 2.4, 2.6, 0.3);
  g.box(10, 14.2, 2.4, 2.6, 0.3);
  g.box(14.6, 14.2, 2.4, 2.6, 0.3);
  g.box(9.4, 2, 2.4, 2.6, 0.3);
}

void _ready(_G g) {
  g.disc(12, 12, 8.2, soft: true);
  g.stroke(_check(7.4, 11.2, 8.4));
}

void _boltCard(_G g) {
  g.box(3, 3, 13, 18, 1.6, soft: true);
  g.shape(
    Path()
      ..moveTo(15.2, 2.4)
      ..lineTo(10.4, 12)
      ..lineTo(14.2, 12)
      ..lineTo(12.2, 21.2)
      ..lineTo(20.4, 9.2)
      ..lineTo(16.2, 9.2)
      ..close(),
  );
}

void _pencilCard(_G g) {
  g.box(2.2, 5, 13, 15.5, 1.5, soft: true);
  g.shape(
    Path()
      ..moveTo(14, 14)
      ..lineTo(20.4, 3.6)
      ..lineTo(22, 5.2)
      ..lineTo(15.6, 15.6)
      ..close(),
  );
  g.box(13.2, 15.2, 2.6, 2.2, 0.3);
}

void _qr(_G g) {
  g.box(2.2, 2.2, 7.2, 7.2, 1);
  g.box(4.2, 4.2, 3.2, 3.2, 0.4, soft: true);
  g.box(14.6, 2.2, 7.2, 7.2, 1);
  g.box(16.6, 4.2, 3.2, 3.2, 0.4, soft: true);
  g.box(2.2, 14.6, 7.2, 7.2, 1);
  g.box(4.2, 16.6, 3.2, 3.2, 0.4, soft: true);
  g.box(14.6, 14.6, 3, 3, 0.4);
  g.box(18.8, 18.8, 3, 3, 0.4, soft: true);
}

void _openLid(_G g) {
  g.box(4, 11, 16, 8.4, 1.2, soft: true);
  g.shape(
    Path()
      ..moveTo(4, 11)
      ..lineTo(12, 6.2)
      ..lineTo(20, 8.4)
      ..lineTo(12, 13)
      ..close(),
  );
}

void _label(_G g) {
  g.box(3, 6, 14, 12, 1.3, soft: true);
  g.box(5.2, 8.6, 8, 1.2, 0.4);
  g.box(5.2, 11.2, 5.4, 1.2, 0.4);
  g.box(17.4, 4, 3.4, 14, 0.8);
}

void _columns(_G g) {
  g.box(2.4, 4, 5, 16, 1);
  g.box(9.5, 4, 5, 16, 1, soft: true);
  g.box(16.6, 4, 5, 16, 1);
}

void _cubes(_G g) {
  g.box(3, 12, 7, 7, 1);
  g.box(8.4, 8, 7, 7, 1, soft: true);
  g.box(13.6, 4, 7, 7, 1);
}

void _kpiStack(_G g) {
  g.box(3.2, 6.4, 12, 13.2, 1.5, soft: true);
  g.box(7.4, 3.2, 12.2, 14.2, 1.5);
  g.box(9.6, 7.2, 7.4, 1.15, 0.4, soft: true);
  g.box(9.6, 9.8, 5.6, 1.15, 0.4, soft: true);
}

void _kpiClock(_G g) {
  g.box(2, 4, 11.2, 15.4, 1.5, soft: true);
  g.disc(16.8, 14.6, 4.6);
  g.seg(16.8, 14.6, 16.8, 11.6, light: true);
  g.seg(16.8, 14.6, 19.4, 15.8, light: true);
}

void _kpiPlay(_G g) {
  g.box(2, 4.2, 12, 15.2, 1.5);
  g.shape(
    Path()
      ..moveTo(15.6, 8.2)
      ..lineTo(22, 12.2)
      ..lineTo(15.6, 16.2)
      ..close(),
    soft: true,
  );
}

void _kpiCheck(_G g) {
  g.box(2, 3.6, 12.4, 16.2, 1.5, soft: true);
  g.stroke(_check(13.6, 11.2, 7.2));
}

void _products(_G g) {
  g.box(1.6, 16.8, 20.8, 4.6, 1.1, soft: true);
  g.box(3.2, 18.2, 17.6, 1, 0.3);
  g.box(3.2, 8.6, 7.4, 7.8, 1.2);
  g.box(12, 5.2, 8, 11.2, 1.3, soft: true);
  g.box(13.4, 7.4, 5.2, 2.1, 0.5);
}

void _bay(_G g) {
  g.box(2.2, 3, 19.6, 17.6, 1.6, soft: true);
  g.box(6, 8.2, 12, 8.2, 1.2);
  g.box(8.4, 5.2, 7.2, 3.2, 0.7);
}

void _flowNodes(_G g) {
  g.disc(5, 12, 2.6);
  g.disc(12, 6.2, 2.6, soft: true);
  g.disc(19, 12, 2.6);
  g.disc(12, 18, 2.6, soft: true);
  g.seg(7.2, 10.8, 9.8, 7.6);
  g.seg(14.2, 7.6, 16.8, 10.8);
  g.seg(7.4, 13.4, 10, 16.6);
  g.seg(14, 16.6, 16.6, 13.4);
}

void _crew(_G g) {
  g.disc(6, 7, 2.1, soft: true);
  g.disc(12, 6.2, 2.4);
  g.disc(18, 7, 2.1, soft: true);
  g.box(3.2, 11, 5.4, 7.2, 2, soft: true);
  g.box(9.2, 10.2, 5.6, 8.2, 2);
  g.box(15.4, 11, 5.4, 7.2, 2, soft: true);
}

void _paused(_G g) {
  g.box(2.2, 10, 11, 8.4, 1.2, soft: true);
  g.box(4, 6, 7.2, 4.4, 0.8);
  g.box(15.2, 6.2, 2.2, 11, 0.6);
  g.box(19, 6.2, 2.2, 11, 0.6);
}

void _chart(_G g) {
  g.box(3, 3, 18, 16, 1.5, soft: true);
  g.seg(6, 15, 6, 10);
  g.seg(10, 15, 10, 7);
  g.seg(14, 15, 14, 11);
  g.seg(18, 15, 18, 6);
}

void _warehouse(_G g) {
  g.shape(
    Path()
      ..moveTo(2, 10)
      ..lineTo(12, 3.2)
      ..lineTo(22, 10)
      ..lineTo(19.4, 10)
      ..lineTo(19.4, 20)
      ..lineTo(4.6, 20)
      ..lineTo(4.6, 10)
      ..close(),
    soft: true,
  );
  g.box(9.2, 12.4, 5.6, 7.6, 0.6);
}

void _sheets(_G g) {
  g.box(6.4, 2.4, 12, 15.2, 1.4, soft: true);
  g.box(3.2, 6, 12, 15.2, 1.4);
  g.box(5.4, 9.2, 7.2, 1.1, 0.4, soft: true);
  g.box(5.4, 12, 5.4, 1.1, 0.4, soft: true);
}

void _partners(_G g) {
  g.box(2, 7, 8.4, 11, 1.3);
  g.box(13.6, 7, 8.4, 11, 1.3, soft: true);
  g.seg(10.4, 12.4, 13.6, 12.4);
}

void _ledger(_G g) {
  g.box(3, 3.2, 13, 17.4, 1.4, soft: true);
  g.box(5.2, 6.4, 8.4, 1.1, 0.4);
  g.box(5.2, 9.2, 8.4, 1.1, 0.4);
  g.box(5.2, 12, 6, 1.1, 0.4);
  g.disc(17.8, 16.2, 3.4);
  g.disc(17.8, 16.2, 1.5, soft: true);
}

void _blueprint(_G g) {
  g.box(3, 3, 18, 14, 1.2, soft: true);
  g.box(6, 6, 8, 8, 0.6);
  g.disc(18.2, 17.6, 3.6);
  g.disc(18.2, 17.6, 1.4, soft: true);
}

void _leaf(_G g) {
  g.box(3, 12, 8, 8, 1, soft: true);
  g.shape(
    Path()
      ..moveTo(12, 20)
      ..quadraticBezierTo(8, 10, 14, 3)
      ..quadraticBezierTo(22, 10, 18, 18)
      ..close(),
  );
  g.seg(13.2, 16.4, 16.4, 8, light: true);
}

void _wrenchGear(_G g) {
  g.disc(8, 8, 3.4, soft: true);
  g.disc(8, 8, 1.4);
  g.box(6.8, 10.4, 2.4, 8.4, 0.8);
  g.disc(17.2, 15.4, 4);
  g.disc(17.2, 15.4, 1.6, soft: true);
}

void _singleBay(_G g) {
  g.box(4, 8, 16, 11, 1.6, soft: true);
  g.box(7, 4.2, 10, 4.2, 1);
  g.disc(12, 13.4, 2.2);
}

void _tablet(_G g) {
  g.box(6, 1.4, 12, 21.2, 2.2, soft: true);
  g.box(7.8, 3.8, 8.4, 13.2, 1.1);
  g.disc(12, 2.7, 0.7);
  g.disc(12, 10.2, 1.8, soft: true);
  g.disc(12, 19.4, 0.9);
}

void _prep(_G g) {
  g.shape(
    Path()
      ..moveTo(2, 6.4)
      ..lineTo(9.2, 6.4)
      ..lineTo(11, 10.2)
      ..lineTo(11, 20)
      ..lineTo(2, 20)
      ..close(),
    soft: true,
  );
  g.box(3.6, 12.4, 2.5, 2.5, 0.45);
  g.box(6.6, 14.8, 2.5, 2.5, 0.45);
  g.disc(17.4, 6.6, 2.5);
  g.disc(17.4, 6.6, 1.05, soft: true);
  g.box(16.2, 8.8, 2.4, 9.4, 1);
}

void _caliper(_G g) {
  g.shape(
    Path()
      ..moveTo(2.2, 3.6)
      ..lineTo(15.4, 3.6)
      ..lineTo(15.4, 7)
      ..lineTo(6.4, 7)
      ..lineTo(6.4, 16.8)
      ..lineTo(15.4, 16.8)
      ..lineTo(15.4, 20.2)
      ..lineTo(2.2, 20.2)
      ..close(),
    soft: true,
  );
  g.box(8.2, 9.2, 7.4, 5.4, 0.9);
  g.stroke(_check(16.6, 10.4, 5));
}

void _finalGate(_G g) {
  g.box(2, 9.2, 11.2, 8.2, 1.2, soft: true);
  g.box(3.2, 6, 8.8, 3.6, 0.8);
  g.shape(_shield(12.2, 7.4, 9.2, 12.2));
  g.stroke(_check(14.6, 11.6, 4.4), light: true);
}

void _cells(_G g) {
  g.seg(8.2, 7.4, 15.8, 7.4);
  g.seg(8.6, 8.6, 12, 14.2);
  g.seg(16.2, 8.6, 13.2, 14.2);
  g.box(3.6, 3, 6.6, 6.4, 1.5);
  g.box(13.8, 3, 6.6, 6.4, 1.5, soft: true);
  g.box(8.6, 13.4, 6.6, 6.4, 1.5);
}

void _bays(_G g) {
  g.box(1.6, 6, 6, 13.2, 1.2);
  g.box(9, 3.2, 6, 16, 1.2, soft: true);
  g.box(16.4, 8, 6, 11.2, 1.2);
}

void _rising(_G g) {
  g.seg(3, 20, 21, 20);
  g.box(4.2, 13, 3.2, 6.4, 0.6, soft: true);
  g.box(9.2, 9, 3.2, 10.4, 0.6);
  g.box(14.2, 4.4, 3.2, 15, 0.6);
}

void _pin(_G g) {
  g.shape(
    Path()
      ..moveTo(12, 21)
      ..lineTo(7.2, 11.2)
      ..arcToPoint(const Offset(16.8, 11.2), radius: const Radius.circular(5.2), clockwise: true)
      ..close(),
    soft: true,
  );
  g.disc(12, 8.2, 2.1);
}

void _ncr(_G g) {
  g.box(2.2, 3, 12, 17.4, 1.4, soft: true);
  g.shape(
    Path()
      ..moveTo(17.4, 20)
      ..lineTo(12.6, 9.2)
      ..lineTo(22.2, 9.2)
      ..close(),
  );
}

void _loop(_G g) {
  g.stroke(
    Path()
      ..addArc(const Rect.fromLTWH(4, 4, 14, 14), 0.6, 4.6),
  );
  g.shape(
    Path()
      ..moveTo(16.8, 4.2)
      ..lineTo(20.4, 7.6)
      ..lineTo(15.2, 8.2)
      ..close(),
  );
  g.stroke(_check(8, 10.2, 5.2), light: true);
}

void _lens(_G g) {
  g.box(2, 3, 12, 16.4, 1.4, soft: true);
  g.disc(16.2, 14.2, 4.2);
  g.disc(16.2, 14.2, 2, soft: true);
  g.box(18.6, 17.2, 2.2, 4.2, 0.6);
}

void _history(_G g) {
  g.box(2, 5, 10, 13, 1.2, soft: true);
  g.box(5, 3.2, 8, 15.2, 1.2);
  g.disc(17.4, 14.8, 4.4, soft: true);
  g.seg(17.4, 14.8, 17.4, 12, light: true);
  g.seg(17.4, 14.8, 19.8, 16, light: true);
}

void _about(_G g) {
  g.disc(12, 12, 8.4, soft: true);
  g.disc(12, 7.6, 1.15);
  g.box(11.1, 10.2, 1.8, 6.4, 0.7);
}

void _swatches(_G g) {
  g.disc(8, 9, 4.6);
  g.disc(16.2, 9, 4.6, soft: true);
  g.disc(12, 16.2, 4.6);
}

void _logbook(_G g) {
  g.box(3.2, 2.8, 16.2, 18.2, 1.6, soft: true);
  g.box(3.2, 2.8, 3.4, 18.2, 1);
  g.box(8.4, 7, 8, 1.15, 0.4);
  g.box(8.4, 10, 6.2, 1.15, 0.4);
  g.box(8.4, 13, 7, 1.15, 0.4);
  g.disc(16.2, 16.6, 2.7);
  g.stroke(_check(14.4, 15.6, 3.2), light: true);
}
