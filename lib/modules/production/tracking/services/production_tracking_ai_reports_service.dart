import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/production_operator_tracking_entry.dart';
import '../models/production_plant_device_event.dart';
import '../models/production_tracking_ai_report_models.dart';
import 'production_asset_display_lookup.dart';
import 'production_operator_tracking_service.dart';

/// Dnevni brzi izvještaji (hub „Brzi izvještaji” u Praćenju): škart po proizvodu, uređaji.
class ProductionTrackingAiReportsService {
  ProductionTrackingAiReportsService({
    ProductionOperatorTrackingService? tracking,
    FirebaseFirestore? firestore,
  })  : _tracking = tracking ?? ProductionOperatorTrackingService(),
        _db = firestore ?? FirebaseFirestore.instance;

  final ProductionOperatorTrackingService _tracking;
  final FirebaseFirestore _db;

  static String workDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// Top [limit] proizvoda po postotku škarta (samo ako je ukupna masa > [minTotalMass]).
  Future<List<ProductScrapDayRollup>> loadTopScrapProductsByDay({
    required String companyId,
    required String plantKey,
    required String workDate,
    int limit = 5,
    double minTotalMass = 0.5,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final entries = await _tracking.fetchDayAllPhasesMerged(
      companyId: cid,
      plantKey: pk,
      workDate: workDate,
    );

    final map = <String, ProductScrapDayRollup>{};
    for (final e in entries) {
      final key = _productKey(e);
      final scrap = e.scrapBreakdown.fold<double>(
        0,
        (a, b) => a + b.qty,
      );
      final good = e.quantity;
      final existing = map[key];
      if (existing == null) {
        map[key] = ProductScrapDayRollup(
          itemKey: key,
          itemCode: e.itemCode.trim(),
          itemName: e.itemName.trim(),
          goodQty: good,
          scrapQty: scrap,
          entries: [e],
        );
      } else {
        map[key] = ProductScrapDayRollup(
          itemKey: key,
          itemCode: existing.itemCode.isNotEmpty
              ? existing.itemCode
              : e.itemCode.trim(),
          itemName: existing.itemName.isNotEmpty
              ? existing.itemName
              : e.itemName.trim(),
          goodQty: existing.goodQty + good,
          scrapQty: existing.scrapQty + scrap,
          entries: [...existing.entries, e],
        );
      }
    }

    final list = map.values
        .where((r) => r.totalMass >= minTotalMass)
        .toList()
      ..sort((a, b) => b.scrapPct.compareTo(a.scrapPct));

    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  /// Svi proizvodi agregirano (za prošireni pregled).
  Future<List<ProductScrapDayRollup>> loadAllScrapProductsByDay({
    required String companyId,
    required String plantKey,
    required String workDate,
    double minTotalMass = 0.5,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final entries = await _tracking.fetchDayAllPhasesMerged(
      companyId: cid,
      plantKey: pk,
      workDate: workDate,
    );

    final map = <String, ProductScrapDayRollup>{};
    for (final e in entries) {
      final key = _productKey(e);
      final scrap = e.scrapBreakdown.fold<double>(
        0,
        (a, b) => a + b.qty,
      );
      final good = e.quantity;
      final existing = map[key];
      if (existing == null) {
        map[key] = ProductScrapDayRollup(
          itemKey: key,
          itemCode: e.itemCode.trim(),
          itemName: e.itemName.trim(),
          goodQty: good,
          scrapQty: scrap,
          entries: [e],
        );
      } else {
        map[key] = ProductScrapDayRollup(
          itemKey: key,
          itemCode: existing.itemCode.isNotEmpty
              ? existing.itemCode
              : e.itemCode.trim(),
          itemName: existing.itemName.isNotEmpty
              ? existing.itemName
              : e.itemName.trim(),
          goodQty: existing.goodQty + good,
          scrapQty: existing.scrapQty + scrap,
          entries: [...existing.entries, e],
        );
      }
    }

    final list = map.values
        .where((r) => r.totalMass >= minTotalMass)
        .toList()
      ..sort((a, b) => b.scrapPct.compareTo(a.scrapPct));
    return list;
  }

  String _productKey(ProductionOperatorTrackingEntry e) {
    final c = e.itemCode.trim();
    if (c.isNotEmpty) return c.toUpperCase();
    return e.itemName.trim().toUpperCase();
  }

  /// Top [limit] uređaja po bodovima: zastoj 3, alarm 2, kvar 1.
  /// Nazivi dolaze iz šifrarnika `assets` + `deviceName` na kvaru — nikad sirovi ID.
  Future<List<DeviceIssueDayRollup>> loadTopDeviceIssuesByDay({
    required String companyId,
    required String plantKey,
    required DateTime day,
    int limit = 5,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) return const [];

    final lookup = await ProductionAssetDisplayLookup.loadForPlant(
      companyId: cid,
      plantKey: pk,
      firestore: _db,
    );

    final start = Timestamp.fromDate(startOfDay(day));
    final end = Timestamp.fromDate(endOfDay(day));

    final aggs = <String, _DeviceAgg>{};

    void mergeAgg(
      String mergeKey, {
      int addD = 0,
      int addA = 0,
      int addF = 0,
      String? eventAssetCode,
      String? eventTitle,
      String? faultAssetId,
      String? faultDeviceName,
    }) {
      if (mergeKey.isEmpty) return;
      final cur = aggs[mergeKey];
      if (cur == null) {
        aggs[mergeKey] = _DeviceAgg(
          mergeKey: mergeKey,
          downtimeCount: addD,
          alarmCount: addA,
          faultCount: addF,
          eventAssetCode: eventAssetCode,
          eventTitle: eventTitle,
          faultAssetId: faultAssetId,
          faultDeviceName: faultDeviceName,
        );
      } else {
        aggs[mergeKey] = _DeviceAgg(
          mergeKey: mergeKey,
          downtimeCount: cur.downtimeCount + addD,
          alarmCount: cur.alarmCount + addA,
          faultCount: cur.faultCount + addF,
          eventAssetCode: cur.eventAssetCode ?? eventAssetCode,
          eventTitle: cur.eventTitle ?? eventTitle,
          faultAssetId: cur.faultAssetId ?? faultAssetId,
          faultDeviceName: cur.faultDeviceName ?? faultDeviceName,
        );
      }
    }

    try {
      final evSnap = await _db
          .collection('production_plant_device_events')
          .where('companyId', isEqualTo: cid)
          .where('plantKey', isEqualTo: pk)
          .where('occurredAt', isGreaterThanOrEqualTo: start)
          .where('occurredAt', isLessThanOrEqualTo: end)
          .get();

      for (final doc in evSnap.docs) {
        final ev = ProductionPlantDeviceEvent.fromDoc(doc);
        if (ev == null) continue;
        final code = (ev.assetCode ?? '').trim();
        final title = ev.title.trim();
        final mergeKey =
            code.isNotEmpty ? code : (title.isNotEmpty ? '__ttl_${title.hashCode}' : '');
        if (mergeKey.isEmpty) continue;
        if (ev.kind == ProductionPlantDeviceEventKind.downtime) {
          mergeAgg(
            mergeKey,
            addD: 1,
            eventAssetCode: code.isNotEmpty ? code : null,
            eventTitle: title.isNotEmpty ? title : null,
          );
        } else {
          mergeAgg(
            mergeKey,
            addA: 1,
            eventAssetCode: code.isNotEmpty ? code : null,
            eventTitle: title.isNotEmpty ? title : null,
          );
        }
      }
    } catch (_) {}

    try {
      final fSnap = await _db
          .collection('faults')
          .where('companyId', isEqualTo: cid)
          .where('plantKey', isEqualTo: pk)
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .get();

      for (final doc in fSnap.docs) {
        final d = doc.data();
        final aid = (d['assetId'] ?? '').toString().trim();
        final dName = (d['deviceName'] ?? '').toString().trim();
        final mergeKey =
            aid.isNotEmpty ? aid : '__no_asset_fault__';
        mergeAgg(
          mergeKey,
          addF: 1,
          faultAssetId: aid.isNotEmpty ? aid : null,
          faultDeviceName: dName.isNotEmpty ? dName : null,
        );
      }
    } catch (_) {}

    final list = aggs.values.map((a) {
      final String display;
      if (a.mergeKey.startsWith('__ttl_')) {
        display = lookup.resolveEventLine(null, a.eventTitle ?? '');
      } else if (a.mergeKey == '__no_asset_fault__') {
        display = lookup.resolve(
          '__no_asset_fault__',
          faultDeviceName: a.faultDeviceName,
        );
      } else {
        final raw = a.faultAssetId ?? a.eventAssetCode ?? a.mergeKey;
        display = lookup.resolve(
          raw,
          eventTitle: a.eventTitle,
          faultDeviceName: a.faultDeviceName,
        );
      }
      return DeviceIssueDayRollup(
        displayName: display,
        downtimeCount: a.downtimeCount,
        alarmCount: a.alarmCount,
        faultCount: a.faultCount,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (list.length <= limit) return list;
    return list.take(limit).toList();
  }

  /// Tekst za predloženi upit asistentu (HR) — isti sadržaj kao ekran „Brzi izvještaji“ u Praćenju.
  ///
  /// [allProductsRanked] opcionalno: svi proizvodi sortirani po % škarta (za sažetak u promptu).
  String buildAssistantPrompt({
    required String workDateLabel,
    required String plantLabel,
    required List<ProductScrapDayRollup> topProducts,
    required List<DeviceIssueDayRollup> topDevices,
    List<ProductScrapDayRollup>? allProductsRanked,
    int allProductsPromptMaxLines = 25,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      'DNEVNI OPERATIVNI IZVJEŠTAJ (brzi) — radni dan $workDateLabel, pogon $plantLabel.',
    );
    buf.writeln(
      'Kontekst: brzi dnevni izvještaj iz Praćenja proizvodnje (škart iz unosa + događaji uređaja + kvarovi).',
    );
    buf.writeln();

    buf.writeln(
      '=== TOP 5 PROBLEMATIČNIH PROIZVODA (najveći % škarta, dnevni agregat) ===',
    );
    if (topProducts.isEmpty) {
      buf.writeln('(Nema dovoljno prijavljene mase za agregat ili su svi ispod praga.)');
    } else {
      for (var i = 0; i < topProducts.length; i++) {
        final p = topProducts[i];
        buf.writeln(
          'Rang ${i + 1}. ${_productLine(p)} — ${_fmtPct(p.scrapPct)} škarta '
          '(škart ${_fmtNum(p.scrapQty)} / ukupno ${_fmtNum(p.totalMass)})',
        );
        _appendProductPhaseScrapDetail(buf, p);
      }
    }
    buf.writeln();

    final full = allProductsRanked;
    if (full != null && full.isNotEmpty) {
      final skip = topProducts.length;
      final rest = full.skip(skip).toList(growable: false);
      buf.writeln(
        '=== IZVJEŠTAJ PO PROIZVODU (ostali proizvodi s podacima, isti rang po % škarta) ===',
      );
      if (rest.isEmpty) {
        buf.writeln(
          '(Nema dodatnih redova osim top $skip — ili je cijeli dan pokriven gornjim listom.)',
        );
      } else {
        final cap = allProductsPromptMaxLines.clamp(5, 80);
        var n = 0;
        for (final p in rest) {
          if (n >= cap) break;
          buf.writeln(
            '${skip + n + 1}. ${_productLine(p)} — ${_fmtPct(p.scrapPct)} škarta '
            '(dobro ${_fmtNum(p.goodQty)}, škart ${_fmtNum(p.scrapQty)})',
          );
          n++;
        }
        if (rest.length > cap) {
          buf.writeln(
            '… i još ${rest.length - cap} proizvod(a) — punu tabelu vidi u aplikaciji.',
          );
        }
      }
      buf.writeln();
    }

    buf.writeln(
      '=== TOP 5 UREĐAJA / LINIJA (najviše zastoja, alarmi, kvarovi; bodovi: zastoj×3 + alarm×2 + kvar) ===',
    );
    if (topDevices.isEmpty) {
      buf.writeln(
        '(Nema događaja u „Stanje uređaja“ niti prijavljenih kvarova za ovaj dan i pogon.)',
      );
    } else {
      for (var i = 0; i < topDevices.length; i++) {
        final d = topDevices[i];
        buf.writeln(
          'Rang ${i + 1}. ${d.displayName}: zastoji ${d.downtimeCount}, '
          'alarmi ${d.alarmCount}, kvarovi ${d.faultCount} (bodovi: ${d.score})',
        );
      }
    }
    buf.writeln();

    buf.writeln('=== ZADATAK ZA AI ASISTENTA ===');
    buf.writeln(
      '1) Sažmi dnevni operativni rizik u 5 kratkih tačaka (za menadžment / brzi sastanak).',
    );
    buf.writeln(
      '2) Za top proizvode s visokim % škarta: koje faze i koje vrste škarta (labele) ističu?',
    );
    buf.writeln(
      '3) Za top 5 uređaja: prepoznaj signale ponavljajućih zastoja ili alarm '
      '(isti uređaj, više događaja u jednom danu). Predloži 3 konkretne provjere ili preventivne korake.',
    );
    buf.writeln(
      '4) Gdje ima smisla, poveži hipotetski visok škart na proizvodu s mogućim zastojem na liniji '
      '(bez kategoričnih tvrdnji — navedi šta bi se provjerilo u proizvodnji).',
    );
    buf.writeln(
      'Odgovor na bosanskom/hrvatskom, numerisano, sažeto, s konkretnim sljedećim koracima.',
    );
    return buf.toString();
  }

  static String _productLine(ProductScrapDayRollup p) {
    final code = p.itemCode.trim();
    final name = p.itemName.trim();
    if (code.isNotEmpty && name.isNotEmpty) return '$code — $name';
    if (code.isNotEmpty) return code;
    if (name.isNotEmpty) return name;
    return p.itemKey;
  }

  static void _appendProductPhaseScrapDetail(StringBuffer buf, ProductScrapDayRollup p) {
    if (p.entries.isEmpty) return;
    for (final e in p.entries) {
      final sc = e.scrapBreakdown.fold<double>(0, (a, b) => a + b.qty);
      buf.writeln(
        '   • ${_phaseLabelHr(e.phase)}: dobro ${_fmtNum(e.quantity)}, škart ${_fmtNum(sc)}',
      );
      for (final b in e.scrapBreakdown) {
        final lbl = b.label.trim().isNotEmpty ? b.label : b.code;
        buf.writeln('     – $lbl: ${_fmtNum(b.qty)}');
      }
    }
  }

  static String _phaseLabelHr(String phase) {
    switch (phase) {
      case ProductionOperatorTrackingEntry.phasePreparation:
        return 'Pripremna';
      case ProductionOperatorTrackingEntry.phaseFirstControl:
        return 'Prva kontrola';
      case ProductionOperatorTrackingEntry.phaseFinalControl:
        return 'Završna kontrola';
      default:
        return phase;
    }
  }

  static String _fmtPct(double v) =>
      '${v.toStringAsFixed(1).replaceAll('.', ',')}%';

  static String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }
}

class _DeviceAgg {
  _DeviceAgg({
    required this.mergeKey,
    required this.downtimeCount,
    required this.alarmCount,
    required this.faultCount,
    this.eventAssetCode,
    this.eventTitle,
    this.faultAssetId,
    this.faultDeviceName,
  });

  final String mergeKey;
  final int downtimeCount;
  final int alarmCount;
  final int faultCount;
  final String? eventAssetCode;
  final String? eventTitle;
  final String? faultAssetId;
  final String? faultDeviceName;
}
