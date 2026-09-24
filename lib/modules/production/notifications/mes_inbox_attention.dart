/// NOTIF-M1-C — brojači pažnje i poslovni signal, bez raw kodova.
library;

import 'mes_notification_prefs.dart';

/// Događaji koji traže radnju (B2 §6). UI ih ne prikazuje kao kod.
const Set<String> kMesInboxActionEventCodes = {
  'VERIFIKACIJA_EVIDENCIJE',
  'EVIDENCE_OUTCOME_NCR',
  'NCR_REWORK_ASSIGNED',
  'NCR_REWORK_COMPLETED',
  'NCR_RECHECK_FAILED',
  'QUALITY_HOLD',
  'PROCESS_PARAM_OUT',
  'LOGISTIC_BLOCK',
  'PROD_ORDER_AT_RISK',
  'DATA_CHANGE_CRITICAL',
  'DOWNTIME_EXCEEDED',
  'DEVICE_OFFLINE',
  'SCADA_DATA_LOSS',
  'SECURITY_EVENT',
  'USER_PENDING',
  'MES_SLA_ESCALATION',
  'DEV_BLOCKING_RISK',
  'DEV_BLOCKING_CHANGE',
  'DEV_APPROVAL_PENDING',
  'FAULT_CREATED',
  'WORK_ORDER_ASSIGNED',
};

/// App površina ovog klijenta — Production vidi proizvodnju / QMS / finansije.
const String kMesInboxAppSurface = 'production';

const Set<String> kMesInboxAppDomains = {
  'production',
  'qms',
  'finance',
  'development',
  'admin_system',
  'scada',
};

const Map<String, String> kMesInboxEventDomain = {
  'PROD_ORDER_CREATED': 'production',
  'PROD_ORDER_RELEASED': 'production',
  'PROD_ORDER_COMPLETED': 'production',
  'PROD_ORDER_START_DELAY': 'production',
  'PROD_ORDER_AT_RISK': 'production',
  'ORDER_RELEASE_PENDING': 'production',
  'DATA_CHANGE_CRITICAL': 'production',
  'LOGISTIC_BLOCK': 'production',
  'MULTI_OPERATOR_CONFLICT': 'production',
  'EXEC_STARTED': 'production',
  'EXEC_PAUSED': 'production',
  'DOWNTIME_STARTED': 'production',
  'DOWNTIME_EXCEEDED': 'production',
  'MULTI_DOWNTIME_PATTERN': 'production',
  'SHIFT_SUMMARY_READY': 'production',
  'OOE_DROP': 'production',
  'SHIFT_KPI_LOW': 'production',
  'MATERIAL_SHORTAGE': 'production',
  'MATERIAL_NOT_READY': 'production',
  'REPLENISHMENT_REQUEST': 'production',
  'OPERONIX_AI_ALERT': 'production',
  'OPERONIX_AI_BRIEFING': 'production',
  'FIRST_BAD_PIECE': 'qms',
  'SCRAP_THRESHOLD_EXCEEDED': 'qms',
  'SCRAP_RATE_ROLLING_HIGH': 'qms',
  'QUALITY_HOLD': 'qms',
  'PROCESS_PARAM_OUT': 'qms',
  'VERIFIKACIJA_EVIDENCIJE': 'qms',
  'EVIDENCE_OUTCOME_NCR': 'qms',
  'NCR_REWORK_ASSIGNED': 'qms',
  'NCR_REWORK_COMPLETED': 'qms',
  'NCR_RECHECK_FAILED': 'qms',
  'NCR_CLOSED': 'qms',
  'FINANCE_AI_NIGHTLY_DIGEST': 'finance',
  'MAINTENANCE_AI_WATCH_DIGEST': 'maintenance',
  'FAULT_CREATED': 'maintenance',
  'FAULT_STATUS_CHANGE': 'maintenance',
  'WORK_ORDER_ASSIGNED': 'maintenance',
  'WORK_ORDER_STATUS_CHANGE': 'maintenance',
  'DEVICE_OFFLINE': 'scada',
  'SCADA_DATA_LOSS': 'scada',
  'USER_PENDING': 'admin_system',
  'SECURITY_EVENT': 'admin_system',
  'MES_SLA_ESCALATION': 'production',
  'DEV_APPROVAL_PENDING': 'development',
  'DEV_BLOCKING_RISK': 'development',
  'DEV_BLOCKING_CHANGE': 'development',
};

class MesInboxAttentionCounts {
  const MesInboxAttentionCounts({
    required this.newCount,
    required this.waitingActionCount,
  });

  final int newCount;
  final int waitingActionCount;

  bool get hasAttention => newCount > 0 || waitingActionCount > 0;
}

class MesInboxArrival {
  const MesInboxArrival({
    required this.docId,
    required this.title,
    required this.waitingAction,
    required this.row,
  });

  final String docId;
  final String title;
  final bool waitingAction;
  final Map<String, dynamic> row;
}

class MesInboxAttention {
  MesInboxAttention._();

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static bool isArchivedRow(Map<String, dynamic> row) {
    if (row['archivedAt'] != null) return true;
    if (_s(row['deliveryStatus']) == 'legacy_out_of_scope') return true;
    if (_s(row['deliveryStatus']) == 'legacy_duplicate') return true;
    if (_s(row['status']) == 'archived') return true;
    return false;
  }

  static String domainForRow(Map<String, dynamic> row) {
    final stored = _s(row['deliveryDomain']);
    if (stored.isNotEmpty) return stored;
    final extra = row['extra'];
    if (extra is Map) {
      final orig = _s(extra['originalEventCode']);
      if (orig.isNotEmpty) {
        return kMesInboxEventDomain[orig] ?? '';
      }
    }
    return kMesInboxEventDomain[_s(row['eventCode'])] ?? '';
  }

  static bool isVisibleInThisApp(Map<String, dynamic> row) {
    if (isArchivedRow(row)) return false;
    final domain = domainForRow(row);
    if (domain.isEmpty) return false;
    return kMesInboxAppDomains.contains(domain);
  }

  static bool isClosedWithoutAction(Map<String, dynamic> row) {
    if (row['closedWithoutActionAt'] != null) return true;
    if (_s(row['lifecycleStatus']) == 'closed_without_action') return true;
    if (_s(row['status']) == 'closed_without_action') return true;
    return false;
  }

  static bool isWaitingAction(Map<String, dynamic> row) {
    if (isArchivedRow(row)) return false;
    if (isClosedWithoutAction(row)) return false;
    if (row['acknowledgedAt'] != null) return false;
    if (row['requiresAction'] == true) return true;
    final code = _s(row['eventCode']);
    return kMesInboxActionEventCodes.contains(code);
  }

  static MesInboxAttentionCounts countsFromRows(
    Iterable<Map<String, dynamic>> rows, {
    MesNotificationPrefs? prefs,
  }) {
    var newer = 0;
    var waiting = 0;
    for (final row in rows) {
      if (!isVisibleInThisApp(row)) continue;
      if (prefs != null && !prefs.allowsRow(row)) continue;
      final unread = row['readAt'] == null;
      if (unread) newer += 1;
      if (isWaitingAction(row)) waiting += 1;
    }
    return MesInboxAttentionCounts(
      newCount: newer,
      waitingActionCount: waiting,
    );
  }

  static String homeCardTitle() => 'Potrebna pažnja';

  static String homeCardOpenActionLabel() => 'Otvori obavijesti';

  static String _cap99(int n) => n > 99 ? '99+' : '$n';

  static String _newCountPhrase(int n) {
    if (n == 1) return '1 novu obavijest';
    if (n >= 2 && n <= 4) return '$n nove obavijesti';
    return '$n novih obavijesti';
  }

  static String homeCardBody(MesInboxAttentionCounts counts) {
    final n = counts.newCount;
    final w = counts.waitingActionCount;
    if (n > 0 && w > 0) {
      return '${_newCountPhrase(n)} · $w čeka akciju';
    }
    if (n > 0) {
      return 'Imate ${_newCountPhrase(n)}';
    }
    if (w == 1) return '1 čeka akciju';
    return '$w čeka akciju';
  }

  /// Chip na Početnoj — stvarni broj, bez 99+.
  static String newCountChipLabel(int n) {
    if (n <= 0) return '';
    if (n == 1) return '1 nova';
    if (n >= 2 && n <= 4) return '$n nove';
    return '$n novih';
  }

  /// Chip na Početnoj — stvarni broj, bez 99+.
  static String waitingActionChipLabel(int w) {
    if (w <= 0) return '';
    return '$w čeka akciju';
  }

  static List<String> homeCardChipLabels(MesInboxAttentionCounts counts) {
    return [
      newCountChipLabel(counts.newCount),
      waitingActionChipLabel(counts.waitingActionCount),
    ].where((s) => s.isNotEmpty).toList(growable: false);
  }

  /// Mali sidebar badge: jedan broj, 99+ iznad 99. Nikad `99+ / 50`.
  static String badgeLabel(MesInboxAttentionCounts counts) {
    if (!counts.hasAttention) return '';
    final n = counts.newCount > 0 ? counts.newCount : counts.waitingActionCount;
    return _cap99(n);
  }

  static String badgeTooltip(MesInboxAttentionCounts counts) {
    return homeCardBody(counts);
  }

  static const Duration inAppBannerVisibleFor = Duration(seconds: 4);

  static String inAppHeadline() => 'Nova obavijest';

  static String inAppSubtitle(String businessTitle) => businessTitle.trim();

  static String inAppOpenLabel() => 'Otvori';

  static String inAppCloseTooltip() => 'Zatvori';

  /// In-app banner samo izvan ekrana Obavijesti (HOTFIX-02).
  static bool shouldShowInAppBanner({required bool isOnInboxScreen}) {
    return !isOnInboxScreen;
  }

  static String inAppMessage(String businessTitle) {
    final t = inAppSubtitle(businessTitle);
    if (t.isEmpty) return inAppHeadline();
    return '${inAppHeadline()}: $t';
  }

  static String statusLabel({
    required bool isRead,
    required bool waitingAction,
    bool closedWithoutAction = false,
  }) {
    if (closedWithoutAction) return 'Zatvoreno bez akcije';
    if (waitingAction) return 'Čeka akciju';
    return isRead ? 'Pročitano' : 'Nepročitano';
  }

  /// FCM / deep-link mapa iz inbox reda (isti kanal, bez raw prikaza).
  static Map<String, dynamic> rowToPushData(Map<String, dynamic> row) {
    final out = <String, dynamic>{
      'type': 'MES_NOTIFICATION',
      'eventCode': _s(row['eventCode']),
      'deepLinkRoute': _s(row['deepLinkRoute']),
      'entityType': _s(row['entityType']),
      'entityId': _s(row['entityId']),
      'plantKey': _s(row['plantKey']),
      'companyId': _s(row['companyId']),
    };
    final extra = row['extra'];
    if (extra is Map) {
      for (final key in extra.keys) {
        final k = key.toString();
        final v = extra[key];
        if (v == null) continue;
        if (v is String || v is num || v is bool) {
          out[k] = v;
        }
      }
    }
    return out;
  }
}
