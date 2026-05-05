import '../models/development_project_model.dart';
import '../models/development_project_supplier_model.dart';
import '../services/development_project_service.dart';
import '../utils/development_constants.dart';

/// Jedan dobavljač na jednom projektu (za portfelj).
class SupplierOnProject {
  const SupplierOnProject({required this.project, required this.supplier});

  final DevelopmentProjectModel project;
  final DevelopmentProjectSupplierModel supplier;
}

/// Grupa istih naziva dobavljača kroz više projekata.
class PortfolioSupplierRollup {
  PortfolioSupplierRollup({
    required this.groupKey,
    required this.displayName,
    required this.items,
  });

  final String groupKey;
  final String displayName;
  final List<SupplierOnProject> items;

  int get projectCount => items.length;

  int _activeProjects() {
    var n = 0;
    for (final x in items) {
      final s = x.project.status.trim();
      if (s == DevelopmentProjectStatuses.active ||
          s == DevelopmentProjectStatuses.approved ||
          s == DevelopmentProjectStatuses.proposed ||
          s == DevelopmentProjectStatuses.draft ||
          s == DevelopmentProjectStatuses.onHold ||
          s == DevelopmentProjectStatuses.atRisk ||
          s == DevelopmentProjectStatuses.delayed) {
        n++;
      }
    }
    return n;
  }

  int _doneProjects() {
    var n = 0;
    for (final x in items) {
      final s = x.project.status.trim();
      if (s == DevelopmentProjectStatuses.completed ||
          s == DevelopmentProjectStatuses.closed ||
          s == DevelopmentProjectStatuses.cancelled) {
        n++;
      }
    }
    return n;
  }

  int get activeProjectCount => _activeProjects();
  int get doneProjectCount => _doneProjects();

  bool get hasRejected => items.any(
        (x) =>
            x.supplier.approvalStatus ==
            DevelopmentSupplierApprovalStatuses.rejected,
      );

  bool get hasPendingOrDraft => items.any((x) {
        final a = x.supplier.approvalStatus;
        return a == DevelopmentSupplierApprovalStatuses.pendingApproval ||
            a == DevelopmentSupplierApprovalStatuses.draft ||
            a == DevelopmentSupplierApprovalStatuses.conditional;
      });

  bool get allApprovedEverywhere =>
      items.isNotEmpty &&
      items.every(
        (x) =>
            x.supplier.approvalStatus ==
            DevelopmentSupplierApprovalStatuses.approved,
      );

  /// Prosjek ocjena (1–5) samo gdje je postavljeno.
  ({double? q, double? d, double? p}) averageRatings() {
    var qSum = 0, qN = 0;
    var dSum = 0, dN = 0;
    var pSum = 0, pN = 0;
    for (final x in items) {
      final s = x.supplier;
      if (s.qualityRating != null) {
        qSum += s.qualityRating!;
        qN++;
      }
      if (s.deliveryRating != null) {
        dSum += s.deliveryRating!;
        dN++;
      }
      if (s.priceRating != null) {
        pSum += s.priceRating!;
        pN++;
      }
    }
    return (
      q: qN > 0 ? qSum / qN : null,
      d: dN > 0 ? dSum / dN : null,
      p: pN > 0 ? pSum / pN : null,
    );
  }

  /// Primjer teksta problema (zadnji neprazan evaluationNote odbačen / rizičan).
  String? problemHint() {
    for (final x in items) {
      final note = (x.supplier.evaluationNote ?? '').trim();
      if (note.isEmpty) continue;
      if (x.supplier.approvalStatus ==
              DevelopmentSupplierApprovalStatuses.rejected ||
          x.supplier.externalRiskLevel == DevelopmentRiskLevels.high) {
        return note;
      }
    }
    for (final x in items) {
      final note = (x.supplier.evaluationNote ?? '').trim();
      if (note.isNotEmpty) return note;
    }
    return null;
  }

  static Future<List<PortfolioSupplierRollup>> loadForProjects(
    List<DevelopmentProjectModel> projects,
    DevelopmentProjectService service,
  ) async {
    if (projects.isEmpty) return [];

    final futures = <Future<List<DevelopmentProjectSupplierModel>>>[];
    for (final p in projects) {
      futures.add(service.fetchSuppliersSnapshot(p.id));
    }
    final perProject = await Future.wait(futures);

    final flat = <SupplierOnProject>[];
    for (var i = 0; i < projects.length; i++) {
      for (final s in perProject[i]) {
        flat.add(SupplierOnProject(project: projects[i], supplier: s));
      }
    }

    final map = <String, List<SupplierOnProject>>{};
    for (final x in flat) {
      final name = x.supplier.displayName.trim();
      final key = name.isEmpty
          ? '${x.project.id}::${x.supplier.id}'
          : name.toLowerCase();
      map.putIfAbsent(key, () => []).add(x);
    }

    final rollups = map.entries.map((e) {
      final first = e.value.first;
      final disp = first.supplier.displayName.trim().isEmpty
          ? 'Bez naziva · ${first.project.projectCode}'
          : first.supplier.displayName.trim();
      return PortfolioSupplierRollup(
        groupKey: e.key,
        displayName: disp,
        items: e.value,
      );
    }).toList();

    rollups.sort((a, b) {
      final c = b.projectCount.compareTo(a.projectCount);
      if (c != 0) return c;
      return a.displayName.compareTo(b.displayName);
    });
    return rollups;
  }
}

/// Brojači za KPI na tabu Analitika.
class PortfolioSupplierKpiSnapshot {
  PortfolioSupplierKpiSnapshot({
    required this.uniqueSupplierNames,
    required this.totalLinks,
    required this.approvedLinks,
    required this.rejectedLinks,
    required this.pendingLinks,
    required this.avgQuality,
    required this.avgDelivery,
    required this.avgPrice,
    required this.rollups,
  });

  final int uniqueSupplierNames;
  final int totalLinks;
  final int approvedLinks;
  final int rejectedLinks;
  final int pendingLinks;
  final double? avgQuality;
  final double? avgDelivery;
  final double? avgPrice;
  final List<PortfolioSupplierRollup> rollups;

  static Future<PortfolioSupplierKpiSnapshot> load(
    List<DevelopmentProjectModel> projects,
    DevelopmentProjectService service,
  ) async {
    final rollups = await PortfolioSupplierRollup.loadForProjects(
      projects,
      service,
    );
    var total = 0;
    var appr = 0;
    var rej = 0;
    var pend = 0;
    var qSum = 0, qN = 0;
    var dSum = 0, dN = 0;
    var pSum = 0, pN = 0;

    for (final r in rollups) {
      for (final x in r.items) {
        total++;
        final a = x.supplier.approvalStatus;
        if (a == DevelopmentSupplierApprovalStatuses.approved) {
          appr++;
        } else if (a == DevelopmentSupplierApprovalStatuses.rejected) {
          rej++;
        } else {
          pend++;
        }
        if (x.supplier.qualityRating != null) {
          qSum += x.supplier.qualityRating!;
          qN++;
        }
        if (x.supplier.deliveryRating != null) {
          dSum += x.supplier.deliveryRating!;
          dN++;
        }
        if (x.supplier.priceRating != null) {
          pSum += x.supplier.priceRating!;
          pN++;
        }
      }
    }

    return PortfolioSupplierKpiSnapshot(
      uniqueSupplierNames: rollups.length,
      totalLinks: total,
      approvedLinks: appr,
      rejectedLinks: rej,
      pendingLinks: pend,
      avgQuality: qN > 0 ? qSum / qN : null,
      avgDelivery: dN > 0 ? dSum / dN : null,
      avgPrice: pN > 0 ? pSum / pN : null,
      rollups: rollups,
    );
  }
}
