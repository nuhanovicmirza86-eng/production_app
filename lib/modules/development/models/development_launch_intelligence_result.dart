/// Odgovor Callabla [getDevelopmentProjectLaunchIntelligence].
class DevelopmentLaunchIntelligenceResult {
  const DevelopmentLaunchIntelligenceResult({
    required this.targetGate,
    required this.launchReadinessScore,
    required this.launchReadinessStatusKey,
    required this.launchReadinessStatusLabel,
    required this.launchSummaryLine,
    required this.segments,
    required this.sopBlockers,
    required this.releaseBlockers,
    required this.changeImpactSummaries,
    required this.lessonsLearnedHints,
    required this.dynamicControlPlan,
    required this.predictiveRisks,
    required this.redTeamQuestions,
    required this.redTeamSummaryLine,
    required this.heatmapLevels,
    required this.heatmapLegend,
    required this.digitalThreadSteps,
    required this.digitalThreadNarrative,
    required this.noSilentChangeRule,
    required this.openBlockingChanges,
    required this.mesIntegrationNote,
    this.customerRequirementsProfile,
  });

  final String targetGate;
  final int launchReadinessScore;
  final String launchReadinessStatusKey;
  final String launchReadinessStatusLabel;
  final String launchSummaryLine;
  final List<LaunchReadinessSegment> segments;
  final List<Map<String, dynamic>> sopBlockers;
  final List<Map<String, dynamic>> releaseBlockers;
  final List<Map<String, dynamic>> changeImpactSummaries;
  final List<Map<String, dynamic>> lessonsLearnedHints;
  final List<Map<String, dynamic>> dynamicControlPlan;
  final List<Map<String, dynamic>> predictiveRisks;
  final List<Map<String, dynamic>> redTeamQuestions;
  final String redTeamSummaryLine;
  final Map<String, int> heatmapLevels;
  final List<String> heatmapLegend;
  final List<Map<String, dynamic>> digitalThreadSteps;
  final String digitalThreadNarrative;
  final String noSilentChangeRule;
  final int openBlockingChanges;
  final String mesIntegrationNote;
  final Map<String, dynamic>? customerRequirementsProfile;

  static DevelopmentLaunchIntelligenceResult parse(dynamic raw) {
    if (raw is! Map) {
      throw Exception('Neočekivan odgovor Launch Intelligence.');
    }
    final m = Map<String, dynamic>.from(raw);
    final lr = m['launchReadiness'];
    final segs = <LaunchReadinessSegment>[];
    if (lr is Map) {
      final lrm = Map<String, dynamic>.from(lr);
      final sl = lrm['segments'];
      if (sl is List) {
        for (final x in sl) {
          if (x is Map) {
            final sm = Map<String, dynamic>.from(x);
            segs.add(LaunchReadinessSegment(
              id: (sm['id'] ?? '').toString(),
              label: (sm['label'] ?? '').toString(),
              weightPercent: () {
                final w = sm['weightPercent'];
                if (w is int) return w;
                if (w is num) return w.toInt();
                return int.tryParse((w ?? '').toString()) ?? 0;
              }(),
              points: () {
                final p = sm['points'];
                if (p is num) return p.toDouble();
                return double.tryParse((p ?? '').toString().replaceAll(',', '.')) ?? 0;
              }(),
              detail: (sm['detail'] ?? '').toString(),
            ));
          }
        }
      }
    }

    Map<String, int> heatLevels = {};
    final hm = m['riskHeatmap'];
    if (hm is Map) {
      final lv = hm['levels'];
      if (lv is Map) {
        lv.forEach((k, v) {
          if (k is! String) return;
          if (v is int) {
            heatLevels[k] = v.clamp(0, 3);
          } else if (v is num) {
            heatLevels[k] = v.toInt().clamp(0, 3);
          }
        });
      }
    }

    final rt = m['redTeamReview'];
    final rtQuestions = <Map<String, dynamic>>[];
    String rtSummary = '';
    if (rt is Map) {
      final rtm = Map<String, dynamic>.from(rt);
      rtSummary = (rtm['summaryLine'] ?? '').toString();
      final q = rtm['questions'];
      if (q is List) {
        for (final x in q) {
          if (x is Map) rtQuestions.add(Map<String, dynamic>.from(x));
        }
      }
    }

    final dt = m['digitalThread'];
    var dtNarrative = '';
    final dtSteps = <Map<String, dynamic>>[];
    if (dt is Map) {
      final dtm = Map<String, dynamic>.from(dt);
      dtNarrative = (dtm['narrative'] ?? '').toString();
      final s = dtm['steps'];
      if (s is List) {
        for (final x in s) {
          if (x is Map) dtSteps.add(Map<String, dynamic>.from(x));
        }
      }
    }

    final nsc = m['noSilentChange'];
    var nscRule = '';
    var nscOpen = 0;
    if (nsc is Map) {
      final n = Map<String, dynamic>.from(nsc);
      nscRule = (n['rule'] ?? '').toString();
      final ob = n['openBlockingChanges'];
      if (ob is int) {
        nscOpen = ob;
      } else if (ob is num) {
        nscOpen = ob.toInt();
      }
    }

    int score = 0;
    String sk = '';
    String slb = '';
    String sline = '';
    if (lr is Map) {
      final lrm = Map<String, dynamic>.from(lr);
      final sc = lrm['score'];
      if (sc is int) {
        score = sc;
      } else if (sc is num) {
        score = sc.round();
      }
      sk = (lrm['statusKey'] ?? '').toString();
      slb = (lrm['statusLabelHr'] ?? '').toString();
      sline = (lrm['summaryLine'] ?? '').toString();
    }

    List<Map<String, dynamic>> asMapList(dynamic v) {
      if (v is! List) return [];
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return DevelopmentLaunchIntelligenceResult(
      targetGate: (m['targetGate'] ?? 'G8').toString(),
      launchReadinessScore: score,
      launchReadinessStatusKey: sk,
      launchReadinessStatusLabel: slb,
      launchSummaryLine: sline,
      segments: segs,
      sopBlockers: asMapList(m['sopBlockers']),
      releaseBlockers: asMapList(m['releaseBlockers']),
      changeImpactSummaries: asMapList(m['changeImpactSummaries']),
      lessonsLearnedHints: asMapList(m['lessonsLearnedHints']),
      dynamicControlPlan: asMapList(m['dynamicControlPlan']),
      predictiveRisks: asMapList(m['predictiveRisks']),
      redTeamQuestions: rtQuestions,
      redTeamSummaryLine: rtSummary,
      heatmapLevels: heatLevels,
      heatmapLegend: () {
        final h = m['riskHeatmap'];
        if (h is! Map) return <String>[];
        final leg = h['legend'];
        if (leg is! List) return <String>[];
        return leg.map((e) => e.toString()).toList();
      }(),
      digitalThreadSteps: dtSteps,
      digitalThreadNarrative: dtNarrative,
      noSilentChangeRule: nscRule,
      openBlockingChanges: nscOpen,
      mesIntegrationNote: (m['mesIntegrationNote'] ?? '').toString(),
      customerRequirementsProfile: () {
        final c = m['customerRequirementsProfile'];
        if (c is Map) return Map<String, dynamic>.from(c);
        return null;
      }(),
    );
  }
}

class LaunchReadinessSegment {
  const LaunchReadinessSegment({
    required this.id,
    required this.label,
    required this.weightPercent,
    required this.points,
    required this.detail,
  });

  final String id;
  final String label;
  final int weightPercent;
  final double points;
  final String detail;
}
