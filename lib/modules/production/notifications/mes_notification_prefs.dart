/// NOTIF-M1-D1 — kategorije postavki obavijesti (BCS, bez raw kodova u UI).
library;

class MesNotificationCategory {
  const MesNotificationCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.canDisable,
    this.lockReason,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool canDisable;
  final String? lockReason;
}

class MesNotificationPrefs {
  const MesNotificationPrefs(this._enabled);

  static const ids = <String>[
    'production',
    'quality',
    'maintenance',
    'finance',
    'ai',
    'system',
  ];

  static const categories = <MesNotificationCategory>[
    MesNotificationCategory(
      id: 'production',
      title: 'Proizvodnja',
      subtitle: 'Nalozi, izvršenje, materijal i operativna upozorenja.',
      canDisable: true,
      lockReason:
          'Kritični rizik naloga, blokada i predugi zastoj ostaju uključeni jer zahtijevaju vašu akciju.',
    ),
    MesNotificationCategory(
      id: 'quality',
      title: 'Kvalitet',
      subtitle: 'Evidencije, NCR i zadržavanje kvaliteta.',
      canDisable: true,
      lockReason:
          'Obavezne verifikacije, NCR / CAPA i HOLD ostaju uključeni jer se ne smiju ugasiti.',
    ),
    MesNotificationCategory(
      id: 'maintenance',
      title: 'Održavanje',
      subtitle: 'Kvarovi, radni nalozi i signali uređaja.',
      canDisable: true,
      lockReason:
          'Dodijeljeni kvar, radni nalog i prekid veze uređaja ostaju uključeni.',
    ),
    MesNotificationCategory(
      id: 'finance',
      title: 'Finansije',
      subtitle: 'Financijski sažeci i obavijesti.',
      canDisable: true,
    ),
    MesNotificationCategory(
      id: 'ai',
      title: 'AI obavijesti',
      subtitle: 'Sažeci i upozorenja Asistenta.',
      canDisable: true,
    ),
    MesNotificationCategory(
      id: 'system',
      title: 'Sistem / sigurnost',
      subtitle: 'Sigurnosni događaji i sistemske obavijesti.',
      canDisable: false,
      lockReason:
          'Sigurnosne i sistemske obavijesti ne mogu se isključiti.',
    ),
  ];

  static const _muteable = <String>{
    'PROD_ORDER_CREATED',
    'PROD_ORDER_RELEASED',
    'PROD_ORDER_COMPLETED',
    'PROD_ORDER_START_DELAY',
    'ORDER_RELEASE_PENDING',
    'MULTI_OPERATOR_CONFLICT',
    'EXEC_STARTED',
    'EXEC_PAUSED',
    'FIRST_BAD_PIECE',
    'SCRAP_RATE_ROLLING_HIGH',
    'DOWNTIME_STARTED',
    'MULTI_DOWNTIME_PATTERN',
    'SHIFT_SUMMARY_READY',
    'OOE_DROP',
    'SHIFT_KPI_LOW',
    'MATERIAL_SHORTAGE',
    'MATERIAL_NOT_READY',
    'REPLENISHMENT_REQUEST',
    'NCR_CLOSED',
    'FINANCE_AI_NIGHTLY_DIGEST',
    'OPERONIX_AI_ALERT',
    'OPERONIX_AI_BRIEFING',
    'MAINTENANCE_AI_WATCH_DIGEST',
    'FAULT_STATUS_CHANGE',
    'WORK_ORDER_STATUS_CHANGE',
  };

  static const _quality = <String>{
    'FIRST_BAD_PIECE',
    'SCRAP_THRESHOLD_EXCEEDED',
    'SCRAP_RATE_ROLLING_HIGH',
    'QUALITY_HOLD',
    'PROCESS_PARAM_OUT',
    'VERIFIKACIJA_EVIDENCIJE',
    'EVIDENCE_OUTCOME_NCR',
    'NCR_REWORK_ASSIGNED',
    'NCR_REWORK_COMPLETED',
    'NCR_RECHECK_FAILED',
    'NCR_CLOSED',
  };

  static const _maintenance = <String>{
    'FAULT_CREATED',
    'FAULT_STATUS_CHANGE',
    'WORK_ORDER_ASSIGNED',
    'WORK_ORDER_STATUS_CHANGE',
    'DEVICE_OFFLINE',
    'SCADA_DATA_LOSS',
  };

  static const _system = <String>{
    'USER_PENDING',
    'SECURITY_EVENT',
    'MES_SLA_ESCALATION',
    'DEV_APPROVAL_PENDING',
    'DEV_BLOCKING_RISK',
    'DEV_BLOCKING_CHANGE',
  };

  static const _ai = <String>{
    'OPERONIX_AI_ALERT',
    'OPERONIX_AI_BRIEFING',
    'MAINTENANCE_AI_WATCH_DIGEST',
  };

  final Map<String, bool> _enabled;

  static MesNotificationPrefs allEnabled() {
    return MesNotificationPrefs({
      for (final id in ids) id: true,
    });
  }

  factory MesNotificationPrefs.fromUser(Map<String, dynamic>? user) {
    final raw = user == null ? null : user['mesNotificationPrefs'];
    final map = raw is Map ? Map<Object?, Object?>.from(raw) : const {};
    final out = <String, bool>{};
    for (final id in ids) {
      if (id == 'system') {
        out[id] = true;
        continue;
      }
      out[id] = map[id] != false;
    }
    return MesNotificationPrefs(out);
  }

  bool isEnabled(String id) => _enabled[id] != false;

  MesNotificationPrefs copyWithId(String id, bool enabled) {
    if (id == 'system') return this;
    return MesNotificationPrefs({..._enabled, id: enabled});
  }

  Map<String, bool> toPayload() {
    return {
      for (final id in ids) id: id == 'system' ? true : isEnabled(id),
    };
  }

  static String categoryForEvent(String eventCode) {
    final code = eventCode.trim();
    if (_ai.contains(code)) return 'ai';
    if (code == 'FINANCE_AI_NIGHTLY_DIGEST') return 'finance';
    if (_quality.contains(code)) return 'quality';
    if (_maintenance.contains(code)) return 'maintenance';
    if (_system.contains(code)) return 'system';
    return 'production';
  }

  static bool isMuteable(String eventCode) => _muteable.contains(eventCode.trim());

  bool allowsEvent(String eventCode) {
    final code = eventCode.trim();
    if (!isMuteable(code)) return true;
    final cat = categoryForEvent(code);
    if (cat == 'system') return true;
    return isEnabled(cat);
  }

  bool allowsRow(Map<String, dynamic> row) {
    final code = (row['eventCode'] ?? '').toString().trim();
    if (code.isNotEmpty && !isMuteable(code)) return true;
    final extra = row['extra'];
    if (extra is Map) {
      final orig = (extra['originalEventCode'] ?? '').toString().trim();
      if (orig.isNotEmpty) return allowsEvent(orig);
    }
    return allowsEvent(code);
  }
}
