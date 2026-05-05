import '../models/development_project_model.dart';
import 'development_constants.dart';

/// Agregati za KPI portfelja (samo klijent — isti scope kao stream liste).
class DevelopmentPortfolioStats {
  DevelopmentPortfolioStats._();

  static bool _isActiveNpi(String status) {
    final s = status.trim();
    return s == DevelopmentProjectStatuses.active ||
        s == DevelopmentProjectStatuses.approved ||
        s == DevelopmentProjectStatuses.proposed ||
        s == DevelopmentProjectStatuses.draft;
  }

  static int countActiveNpi(List<DevelopmentProjectModel> projects) {
    return projects.where((p) => _isActiveNpi(p.status)).length;
  }

  static Map<String, int> countsByGate(List<DevelopmentProjectModel> projects) {
    final m = <String, int>{};
    for (final p in projects) {
      final g = p.currentGate.trim();
      final key = g.isEmpty ? '—' : g;
      m[key] = (m[key] ?? 0) + 1;
    }
    return m;
  }

  static int _gateSortKey(String gate) {
    if (gate == '—') return -1;
    final m = RegExp(r'^G(\d+)$', caseSensitive: false).firstMatch(gate.trim());
    if (m != null) return int.tryParse(m.group(1)!) ?? 100;
    return 50;
  }

  /// Gates sortirani G0, G1, … zatim ostalo.
  static List<String> gatesSorted(Map<String, int> counts) {
    final keys = counts.keys.toList();
    keys.sort((a, b) => _gateSortKey(a).compareTo(_gateSortKey(b)));
    return keys;
  }

  /// [customerLabel] = prikazni naziv; prazan string grupira „Bez kupca”.
  static List<({String customerLabel, int count, Map<String, int> byGate})>
      rowsByCustomer(List<DevelopmentProjectModel> projects) {
    final groups = <String, List<DevelopmentProjectModel>>{};
    for (final p in projects) {
      final raw = (p.customerName ?? '').trim();
      groups.putIfAbsent(raw, () => []).add(p);
    }
    final out =
        <({String customerLabel, int count, Map<String, int> byGate})>[];
    for (final e in groups.entries) {
      final label = e.key.isEmpty ? '' : e.key;
      out.add((
        customerLabel: label,
        count: e.value.length,
        byGate: countsByGate(e.value),
      ));
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  static String? dominantGate(Map<String, int> byGate) {
    if (byGate.isEmpty) return null;
    var bestK = '';
    var bestN = -1;
    for (final e in byGate.entries) {
      if (e.value > bestN) {
        bestN = e.value;
        bestK = e.key;
      }
    }
    if (bestK == '—') return null;
    return bestK;
  }

  /// Aktivni NPI tok / treba pažnje / završeno — za vizualnu traku životnog ciklusa.
  static ({int pipeline, int attention, int done, int other}) lifecycleBuckets(
    List<DevelopmentProjectModel> projects,
  ) {
    var pipeline = 0;
    var attention = 0;
    var done = 0;
    var other = 0;
    for (final p in projects) {
      final s = p.status.trim();
      if (s == DevelopmentProjectStatuses.atRisk ||
          s == DevelopmentProjectStatuses.delayed ||
          s == DevelopmentProjectStatuses.onHold) {
        attention++;
      } else if (s == DevelopmentProjectStatuses.completed ||
          s == DevelopmentProjectStatuses.closed ||
          s == DevelopmentProjectStatuses.cancelled) {
        done++;
      } else if (s == DevelopmentProjectStatuses.active ||
          s == DevelopmentProjectStatuses.approved ||
          s == DevelopmentProjectStatuses.proposed ||
          s == DevelopmentProjectStatuses.draft) {
        pipeline++;
      } else {
        other++;
      }
    }
    return (pipeline: pipeline, attention: attention, done: done, other: other);
  }

  static double? averageProgressPercent(List<DevelopmentProjectModel> projects) {
    if (projects.isEmpty) return null;
    var sum = 0;
    for (final p in projects) {
      sum += p.progressPercent;
    }
    return sum / projects.length;
  }

  /// Broj projekata po pojasu overall health score-a (0–100).
  static Map<String, int> healthScoreBands(List<DevelopmentProjectModel> projects) {
    var b0 = 0; // <60
    var b1 = 0; // 60–79
    var b2 = 0; // 80–100
    var missing = 0;
    for (final p in projects) {
      final h = p.kpi.overallHealthScore;
      if (h == null) {
        missing++;
        continue;
      }
      if (h < 60) {
        b0++;
      } else if (h < 80) {
        b1++;
      } else {
        b2++;
      }
    }
    return {
      'low': b0,
      'medium': b1,
      'high': b2,
      'na': missing,
    };
  }
}
