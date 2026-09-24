/// NOTIF-M1-B — poslovni prikaz MES inboxa. Nikad ne vraća sirovi event kod,
/// severity (`S1`–`S4`), e-mail, UID ili internu šifru u vidljivi tekst.
import 'mes_inbox_attention.dart';

enum MesInboxListFilter {
  unread,
  all,
  critical,
  warnings,
  info,
}

enum MesInboxPeriodFilter {
  today,
  days3,
  days7,
  days30,
  all,
}

enum MesInboxPriorityBand {
  critical,
  warnings,
  info,
}

class MesInboxActionGuide {
  const MesInboxActionGuide({
    required this.need,
    required this.owner,
    required this.nextStep,
    required this.doneWhen,
  });

  /// Šta se od korisnika traži.
  final String need;

  /// Ko je odgovoran (uloga / funkcija, nikad UID).
  final String owner;

  /// Sljedeći korak i gdje se rješava.
  final String nextStep;

  /// Kada je akcija završena.
  final String doneWhen;
}

class MesInboxVisibleCopy {
  const MesInboxVisibleCopy({
    required this.title,
    required this.body,
    required this.isRead,
    required this.readLabel,
    required this.band,
    required this.waitingAction,
    this.actionGuide,
    this.closedWithoutAction = false,
    this.canCloseWithoutAction = false,
    this.repeatCount = 0,
    this.repeatLabel = '',
    this.lastCheckLabel = '',
  });

  final String title;
  final String body;
  final bool isRead;
  final String readLabel;
  final MesInboxPriorityBand band;
  final bool waitingAction;
  final MesInboxActionGuide? actionGuide;
  final bool closedWithoutAction;
  final bool canCloseWithoutAction;
  final int repeatCount;
  final String repeatLabel;
  final String lastCheckLabel;
}

class MesInboxPresentation {
  MesInboxPresentation._();

  static const Map<String, String> titles = {
    'PROD_ORDER_RELEASED': 'Nalog pušten u rad',
    'PROD_ORDER_START_DELAY': 'Kašnjenje starta naloga',
    'DOWNTIME_STARTED': 'Zastoj / prekid rada',
    'DOWNTIME_EXCEEDED': 'Zastoj traje duže od praga',
    'SCRAP_THRESHOLD_EXCEEDED': 'Škart iznad praga',
    'SCRAP_RATE_ROLLING_HIGH': 'Udio škarta iznad praga',
    'MATERIAL_SHORTAGE': 'Čekanje materijala',
    'QUALITY_HOLD': 'Lot na zadržavanju kvaliteta',
    'USER_PENDING': 'Novi korisnik čeka odobrenje',
    'EXEC_STARTED': 'Rad pokrenut',
    'EXEC_PAUSED': 'Pauza izvršenja',
    'PROD_ORDER_COMPLETED': 'Nalog završen',
    'FIRST_BAD_PIECE': 'Prvi zabilježeni škart',
    'SHIFT_SUMMARY_READY': 'Sažetak smjene spreman',
    'VERIFIKACIJA_EVIDENCIJE': 'Evidencija čeka verifikaciju',
    'FINANCE_AI_NIGHTLY_DIGEST': 'Noćni financijski sažetak',
    'OPERONIX_AI_ALERT': 'Upozorenje Asistenta',
    'OPERONIX_AI_BRIEFING': 'Dnevni operativni briefing je spreman',
    'MAINTENANCE_AI_WATCH_DIGEST': 'Sažetak signala održavanja',
    'OOE_DROP': 'Pad učinkovitosti',
    'SHIFT_KPI_LOW': 'Niski pokazatelj smjene',
    'PROD_ORDER_CREATED': 'Novi proizvodni nalog',
    'MULTI_DOWNTIME_PATTERN': 'Uzorak zastoja na stroju',
    'PROD_ORDER_AT_RISK': 'Rizik kašnjenja roka',
    'ORDER_RELEASE_PENDING': 'Puštanje naloga još čeka',
    'MULTI_OPERATOR_CONFLICT': 'Mogući konflikt operatera',
    'REPLENISHMENT_REQUEST': 'Zahtjev za dopunu',
    'DATA_CHANGE_CRITICAL': 'Kritična izmjena naloga',
    'MATERIAL_NOT_READY': 'Priprema / postava linije',
    'LOGISTIC_BLOCK': 'Logistička blokada naloga',
    'PROCESS_PARAM_OUT': 'Parametar / mjerenje van tolerancije',
    'EVIDENCE_OUTCOME_NCR': 'NCR otvoren iz evidencije',
    'NCR_REWORK_ASSIGNED': 'Dodijeljen zadatak dorade',
    'NCR_REWORK_COMPLETED': 'Dorada završena — potrebna ponovna kontrola',
    'NCR_RECHECK_FAILED': 'Ponovna kontrola nije odobrena',
    'NCR_CLOSED': 'Neusaglašenost zatvorena',
    'DEVICE_OFFLINE': 'Uređaj nije dostupan',
    'SCADA_DATA_LOSS': 'Gubitak veze s uređajem',
    'SECURITY_EVENT': 'Sigurnosni događaj: korisnik blokiran',
    'MES_SLA_ESCALATION': 'Eskalacija bez odgovora',
    'DEV_APPROVAL_PENDING': 'Razvoj: novi zahtjev za odobrenje',
    'DEV_BLOCKING_RISK': 'Razvoj: rizik blokira puštanje',
    'DEV_BLOCKING_CHANGE': 'Razvoj: izmjena blokira puštanje',
    'FAULT_CREATED': 'Prijavljen je novi kvar',
    'FAULT_STATUS_CHANGE': 'Status kvara je izmijenjen',
    'WORK_ORDER_ASSIGNED': 'Dodijeljen vam je radni nalog',
    'WORK_ORDER_STATUS_CHANGE': 'Status radnog naloga je izmijenjen',
  };

  static const Map<String, String> bodies = {
    'PROD_ORDER_RELEASED': 'Proizvodni nalog je pušten u rad.',
    'PROD_ORDER_START_DELAY': 'Start naloga kasni u odnosu na plan.',
    'DOWNTIME_STARTED': 'Zabilježen je zastoj ili prekid rada.',
    'DOWNTIME_EXCEEDED': 'Zastoj traje duže od dopuštenog praga.',
    'SCRAP_THRESHOLD_EXCEEDED': 'Količina škarta prešla je prag.',
    'SCRAP_RATE_ROLLING_HIGH': 'Udio škarta je iznad praga.',
    'MATERIAL_SHORTAGE': 'Rad čeka materijal.',
    'QUALITY_HOLD': 'Lot je stavljen na zadržavanje kvaliteta.',
    'USER_PENDING': 'Novi korisnik čeka odobrenje pristupa.',
    'EXEC_STARTED': 'Izvršenje naloga je pokrenuto.',
    'EXEC_PAUSED': 'Izvršenje naloga je pauzirano.',
    'PROD_ORDER_COMPLETED': 'Proizvodni nalog je završen.',
    'FIRST_BAD_PIECE': 'Zabilježen je prvi škart na nalogu.',
    'SHIFT_SUMMARY_READY': 'Sažetak smjene je spreman za pregled.',
    'VERIFIKACIJA_EVIDENCIJE': 'Evidencija čeka verifikaciju ovlaštene osobe.',
    'FINANCE_AI_NIGHTLY_DIGEST': 'Spreman je noćni financijski sažetak.',
    'OPERONIX_AI_ALERT': 'Asistent je pripremio operativno upozorenje.',
    'OPERONIX_AI_BRIEFING': 'Dnevni operativni briefing je spreman.',
    'MAINTENANCE_AI_WATCH_DIGEST': 'Spreman je sažetak signala održavanja.',
    'OOE_DROP': 'Učinkovitost je pala ispod praga.',
    'SHIFT_KPI_LOW': 'Pokazatelj smjene je ispod praga.',
    'PROD_ORDER_CREATED': 'Upisan je novi proizvodni nalog.',
    'MULTI_DOWNTIME_PATTERN': 'Na stroju se ponavlja uzorak zastoja.',
    'PROD_ORDER_AT_RISK': 'Postoji rizik kašnjenja roka naloga.',
    'ORDER_RELEASE_PENDING': 'Nalog još čeka puštanje u rad.',
    'MULTI_OPERATOR_CONFLICT': 'Moguć je konflikt dodjele operatera.',
    'REPLENISHMENT_REQUEST': 'Podnesen je zahtjev za dopunu.',
    'DATA_CHANGE_CRITICAL': 'Na nalogu je napravljena kritična izmjena.',
    'MATERIAL_NOT_READY': 'Linija je u pripremi / postavi.',
    'LOGISTIC_BLOCK': 'Nalog je blokiran zbog logistike.',
    'PROCESS_PARAM_OUT': 'Parametar ili mjerenje je van tolerancije.',
    'EVIDENCE_OUTCOME_NCR':
        'Iz evidencije je otvorena neusaglašenost. Otvorite NCR u QMS-u.',
    'NCR_REWORK_ASSIGNED': 'Dodijeljen vam je zadatak dorade.',
    'NCR_REWORK_COMPLETED': 'Dorada je završena. Potrebna je ponovna kontrola.',
    'NCR_RECHECK_FAILED': 'Ponovna kontrola nije odobrena.',
    'NCR_CLOSED': 'Neusaglašenost je zatvorena.',
    'DEVICE_OFFLINE': 'Uređaj trenutno nije dostupan.',
    'SCADA_DATA_LOSS': 'Izgubljena je veza s uređajem.',
    'SECURITY_EVENT': 'Korisnički račun je blokiran.',
    'MES_SLA_ESCALATION': 'Još nema potrebnog odgovora na obavijest.',
    'DEV_APPROVAL_PENDING': 'U razvoju čeka novi zahtjev za odobrenje.',
    'DEV_BLOCKING_RISK': 'Rizik u razvoju blokira puštanje.',
    'DEV_BLOCKING_CHANGE': 'Izmjena u razvoju blokira puštanje.',
    'FAULT_CREATED': 'Na pogonu je prijavljen novi kvar.',
    'FAULT_STATUS_CHANGE': 'Status kvara je ažuriran.',
    'WORK_ORDER_ASSIGNED': 'Dodijeljen vam je radni nalog.',
    'WORK_ORDER_STATUS_CHANGE': 'Status radnog naloga je ažuriran.',
  };

  static const String fallbackTitle = 'Obavijest';
  static const String fallbackBody = 'Otvorite obavijest za detalje.';

  /// Poslovni nazivi evidencija — nikad profile key u UI.
  static const Map<String, String> evidenceProfileLabels = {
    'first_piece_approval': 'Odobrenje prvog komada',
    'in_process_quality_check': 'Kontrola u procesu',
    'final_control': 'Finalna kontrola',
    'packaging_control': 'Kontrola pakovanja',
    'material_preparation': 'Priprema materijala',
    'operation_material_preparation': 'Priprema materijala za operaciju',
    'production_counting': 'Brojanje proizvodnje',
    'line_clearance': 'Čišćenje mašine / linije',
    'workspace_5s_cleaning': '5S čišćenje radnog prostora',
    'tool_changeover': 'Zamjena alata',
    'batch_mixing': 'Miješanje serije',
    'rework_and_painting': 'Dorada i farbanje',
    'chemical_dosing': 'Doziranje hemikalija',
    'wastewater_treatment': 'Prečišćavanje otpadnih voda',
  };

  static String filterLabel(MesInboxListFilter filter) {
    switch (filter) {
      case MesInboxListFilter.unread:
        return 'Nepročitano';
      case MesInboxListFilter.all:
        return 'Sve';
      case MesInboxListFilter.critical:
        return 'Kritično';
      case MesInboxListFilter.warnings:
        return 'Upozorenja';
      case MesInboxListFilter.info:
        return 'Informacije';
    }
  }

  static String periodLabel(MesInboxPeriodFilter period) {
    switch (period) {
      case MesInboxPeriodFilter.today:
        return 'Danas';
      case MesInboxPeriodFilter.days3:
        return '3 dana';
      case MesInboxPeriodFilter.days7:
        return '7 dana';
      case MesInboxPeriodFilter.days30:
        return '30 dana';
      case MesInboxPeriodFilter.all:
        return 'Sve';
    }
  }

  static String filterBarButtonLabel() => 'Filteri';

  static String filterBarStatusGroupLabel() => 'Status';

  static String filterBarPeriodGroupLabel() => 'Period';

  static String periodWireValue(MesInboxPeriodFilter period) {
    switch (period) {
      case MesInboxPeriodFilter.today:
        return 'today';
      case MesInboxPeriodFilter.days3:
        return 'd3';
      case MesInboxPeriodFilter.days7:
        return 'd7';
      case MesInboxPeriodFilter.days30:
        return 'd30';
      case MesInboxPeriodFilter.all:
        return 'all';
    }
  }

  static String listFilterWireValue(MesInboxListFilter filter) {
    switch (filter) {
      case MesInboxListFilter.unread:
        return 'unread';
      case MesInboxListFilter.all:
        return 'all';
      case MesInboxListFilter.critical:
        return 'critical';
      case MesInboxListFilter.warnings:
        return 'warnings';
      case MesInboxListFilter.info:
        return 'info';
    }
  }

  static DateTime? periodStart(
    MesInboxPeriodFilter period, {
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final startToday = DateTime(n.year, n.month, n.day);
    switch (period) {
      case MesInboxPeriodFilter.today:
        return startToday;
      case MesInboxPeriodFilter.days3:
        return startToday.subtract(const Duration(days: 2));
      case MesInboxPeriodFilter.days7:
        return startToday.subtract(const Duration(days: 6));
      case MesInboxPeriodFilter.days30:
        return startToday.subtract(const Duration(days: 29));
      case MesInboxPeriodFilter.all:
        return null;
    }
  }

  static bool matchesPeriod(
    MesInboxPeriodFilter period,
    DateTime? createdAt, {
    DateTime? now,
  }) {
    final start = periodStart(period, now: now);
    if (start == null) return true;
    if (createdAt == null) return false;
    return !createdAt.isBefore(start);
  }

  static String readStatusLabel(bool isRead) =>
      isRead ? 'Pročitano' : 'Nepročitano';

  static MesInboxPriorityBand bandFromSeverity(String severity) {
    switch (severity.trim().toUpperCase()) {
      case 'S4':
        return MesInboxPriorityBand.critical;
      case 'S3':
      case 'S2':
        return MesInboxPriorityBand.warnings;
      default:
        return MesInboxPriorityBand.info;
    }
  }

  static bool matchesFilter(
    MesInboxListFilter filter,
    MesInboxVisibleCopy copy,
  ) {
    switch (filter) {
      case MesInboxListFilter.unread:
        return !copy.isRead || copy.waitingAction;
      case MesInboxListFilter.all:
        return true;
      case MesInboxListFilter.critical:
        return copy.band == MesInboxPriorityBand.critical;
      case MesInboxListFilter.warnings:
        return copy.band == MesInboxPriorityBand.warnings;
      case MesInboxListFilter.info:
        return copy.band == MesInboxPriorityBand.info;
    }
  }

  static MesInboxVisibleCopy fromRow(Map<String, dynamic> row) {
    final eventCode = _asString(row['eventCode']);
    final storedTitle = _asString(row['title']);
    final storedBody = _asString(row['body']);
    final severity = _asString(row['severity']);
    final isRead = row['readAt'] != null;
    final waitingAction = MesInboxAttention.isWaitingAction(row);
    final closedWithoutAction = MesInboxAttention.isClosedWithoutAction(row);
    final profileKey = detectEvidenceProfileKey(row);
    final extra = row['extra'];
    var originalEventCode = '';
    if (extra is Map) {
      originalEventCode = _asString(extra['originalEventCode']);
    }
    final repeatCount = _repeatCount(row['repeatCount']);
    final lastAt = _parseTime(row['lastTriggeredAt']) ?? _parseTime(row['createdAt']);
    return MesInboxVisibleCopy(
      title: businessTitle(eventCode: eventCode, storedTitle: storedTitle),
      body: businessBody(
        eventCode: eventCode,
        storedBody: storedBody,
        profileKey: profileKey,
      ),
      isRead: isRead,
      readLabel: MesInboxAttention.statusLabel(
        isRead: isRead,
        waitingAction: waitingAction,
        closedWithoutAction: closedWithoutAction,
      ),
      band: bandFromSeverity(severity),
      waitingAction: waitingAction,
      closedWithoutAction: closedWithoutAction,
      canCloseWithoutAction:
          waitingAction && row['isActionOwner'] == true && !closedWithoutAction,
      repeatCount: repeatCount,
      repeatLabel: repeatCountLabel(repeatCount),
      lastCheckLabel: lastCheckLabel(lastAt),
      actionGuide: actionGuideFor(
        eventCode: eventCode,
        waitingAction: waitingAction,
        profileKey: profileKey,
        originalEventCode: originalEventCode,
      ),
    );
  }

  static int _repeatCount(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      final d = (v as dynamic).toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }

  static String repeatCountLabel(int n) {
    if (n < 2) return '';
    return 'Ponovljeno: $n puta';
  }

  static String lastCheckLabel(DateTime? at, {DateTime? now}) {
    if (at == null) return '';
    final n = now ?? DateTime.now();
    final local = at.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final sameDay = local.year == n.year &&
        local.month == n.month &&
        local.day == n.day;
    if (sameDay) return 'Zadnja provjera: danas $hh:$mm';
    final yday = n.subtract(const Duration(days: 1));
    final yesterday = local.year == yday.year &&
        local.month == yday.month &&
        local.day == yday.day;
    if (yesterday) return 'Zadnja provjera: jučer $hh:$mm';
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return 'Zadnja provjera: $dd.$mo.${local.year}. $hh:$mm';
  }

  static String businessTitle({
    required String eventCode,
    required String storedTitle,
  }) {
    final mapped = titles[eventCode] ?? fallbackTitle;
    if (eventCode == 'EVIDENCE_OUTCOME_NCR') return mapped;
    final cleaned = sanitizeVisible(storedTitle, eventCode: eventCode);
    if (cleaned.length < 8 || looksInternal(cleaned, eventCode: eventCode)) {
      return mapped;
    }
    return cleaned;
  }

  static String businessBody({
    required String eventCode,
    required String storedBody,
    String profileKey = '',
  }) {
    if (eventCode == 'EVIDENCE_OUTCOME_NCR') {
      return evidenceOutcomeNcrBody(
        profileKey.isNotEmpty
            ? profileKey
            : detectEvidenceProfileKey({'body': storedBody}),
      );
    }
    final mapped = bodies[eventCode] ?? fallbackBody;
    final cleaned = sanitizeVisible(storedBody, eventCode: eventCode);
    if (cleaned.length < 8 || looksInternal(cleaned, eventCode: eventCode)) {
      return mapped;
    }
    return cleaned;
  }

  static String evidenceOutcomeNcrBody(String profileKey) {
    switch (profileKey.trim()) {
      case 'first_piece_approval':
        return 'Odobrenje prvog komada je odbijeno. Otvoren je NCR u QMS-u.';
      case 'final_control':
        return 'Finalna kontrola nije odobrena za nastavak. Otvoren je NCR u QMS-u.';
      case 'in_process_quality_check':
        return 'Kontrola u procesu nije odobrena. Otvorite NCR u QMS-u.';
      case 'packaging_control':
        return 'Kontrola pakovanja nije odobrena. Otvorite NCR u QMS-u.';
      case 'line_clearance':
        return 'Čišćenje mašine / linije nije odobreno. Otvorite NCR u QMS-u.';
      case 'workspace_5s_cleaning':
        return '5S čišćenje radnog prostora nije odobreno. Otvorite NCR u QMS-u.';
      default:
        final label = evidenceProfileLabels[profileKey.trim()] ?? '';
        if (label.isNotEmpty) {
          return '$label nije odobrena. Otvorite NCR u QMS-u.';
        }
        return bodies['EVIDENCE_OUTCOME_NCR'] ?? fallbackBody;
    }
  }

  static String detectEvidenceProfileKey(Map<String, dynamic> row) {
    final extra = row['extra'];
    if (extra is Map) {
      final fromExtra = _asString(extra['evidenceProfileKey']);
      if (evidenceProfileLabels.containsKey(fromExtra)) return fromExtra;
    }
    final direct = _asString(row['evidenceProfileKey']);
    if (evidenceProfileLabels.containsKey(direct)) return direct;
    final blob = '${_asString(row['title'])} ${_asString(row['body'])}';
    for (final key in evidenceProfileLabels.keys) {
      if (blob.contains(key)) return key;
    }
    return '';
  }

  static MesInboxActionGuide? actionGuideFor({
    required String eventCode,
    required bool waitingAction,
    String profileKey = '',
    String originalEventCode = '',
  }) {
    if (!waitingAction) return null;
    final guideCode = eventCode == 'MES_SLA_ESCALATION' &&
            originalEventCode.isNotEmpty
        ? originalEventCode
        : eventCode;
    switch (guideCode) {
      case 'EVIDENCE_OUTCOME_NCR':
        final label = evidenceProfileLabels[profileKey] ?? '';
        final need = label.isEmpty
            ? 'Otvorite NCR u QMS-u i odredite sljedeću mjeru.'
            : 'Otvorite NCR u QMS-u i odredite sljedeću mjeru za $label.';
        return MesInboxActionGuide(
          need: need,
          owner: 'Kvalitet',
          nextStep:
              'Otvorite ovu obavijest — rješava se u QMS (neusaglašenosti).',
          doneWhen: 'Kad je neusaglašenost obrađena u QMS-u.',
        );
      case 'VERIFIKACIJA_EVIDENCIJE':
        return const MesInboxActionGuide(
          need: 'Verificirajte evidenciju.',
          owner: 'Ovlašteni verifikator',
          nextStep: 'Otvorite ovu obavijest — ista evidencija.',
          doneWhen: 'Kad je verifikacija potpisana.',
        );
      case 'NCR_REWORK_ASSIGNED':
        return const MesInboxActionGuide(
          need: 'Izvršite dodijeljenu doradu.',
          owner: 'Dodijeljeni izvršilac',
          nextStep: 'Otvorite ovu obavijest — zadatak dorade.',
          doneWhen: 'Kad je dorada predana.',
        );
      case 'NCR_REWORK_COMPLETED':
        return const MesInboxActionGuide(
          need: 'Ponovo pregledajte evidenciju nakon dorade.',
          owner: 'Kvalitet',
          nextStep: 'Otvorite ovu obavijest — ponovna kontrola.',
          doneWhen: 'Kad je ponovna kontrola završena.',
        );
      case 'NCR_RECHECK_FAILED':
        return const MesInboxActionGuide(
          need: 'Odlučite sljedeću mjeru jer ponovna kontrola nije odobrena.',
          owner: 'Kvalitet',
          nextStep: 'Otvorite ovu obavijest — QMS neusaglašenost.',
          doneWhen: 'Kad je sljedeća mjera upisana.',
        );
      case 'QUALITY_HOLD':
        return const MesInboxActionGuide(
          need: 'Pregledajte lot na zadržavanju i odlučite dalje.',
          owner: 'Kvalitet',
          nextStep: 'Otvorite ovu obavijest — kvalitet / lot.',
          doneWhen: 'Kad je zadržavanje skinuto ili lot raspoložen.',
        );
      case 'FAULT_CREATED':
        return const MesInboxActionGuide(
          need: 'Pregledajte prijavljeni kvar i preuzmite rad.',
          owner: 'Održavanje',
          nextStep: 'Otvorite ovu obavijest — detalj kvara.',
          doneWhen: 'Kad je kvar preuzet ili zatvoren.',
        );
      case 'WORK_ORDER_ASSIGNED':
        return const MesInboxActionGuide(
          need: 'Preuzmite i izvršite radni nalog.',
          owner: 'Dodijeljeni izvršilac',
          nextStep: 'Otvorite ovu obavijest — detalj radnog naloga.',
          doneWhen: 'Kad je radni nalog završen.',
        );
      case 'DEVICE_OFFLINE':
        return const MesInboxActionGuide(
          need: 'Provjerite uređaj koji nije dostupan.',
          owner: 'Menadžer održavanja',
          nextStep: 'Otvorite ovu obavijest — nadzor uređaja.',
          doneWhen: 'Kad je veza s uređajem uspostavljena.',
        );
      case 'SCADA_DATA_LOSS':
        return const MesInboxActionGuide(
          need: 'Provjerite izgubljenu vezu s uređajem.',
          owner: 'Menadžer održavanja',
          nextStep: 'Otvorite ovu obavijest — nadzor uređaja.',
          doneWhen: 'Kad je veza ponovo uspostavljena.',
        );
      case 'USER_PENDING':
        return const MesInboxActionGuide(
          need: 'Pregledajte zahtjev i odobrite ili odbijte pristup.',
          owner: 'Administrator',
          nextStep: 'Otvorite ovu obavijest — čekajući korisnici.',
          doneWhen: 'Kad je zahtjev obrađen.',
        );
      case 'SECURITY_EVENT':
        return const MesInboxActionGuide(
          need: 'Pregledajte sigurnosni događaj i poduzmite mjeru.',
          owner: 'Administrator',
          nextStep: 'Otvorite ovu obavijest — korisnici.',
          doneWhen: 'Kad je mjera poduzeta.',
        );
      case 'PROD_ORDER_AT_RISK':
        return const MesInboxActionGuide(
          need:
              'Provjerite zašto nalog kasni, uskladite rok ili pokrenite korektivnu akciju.',
          owner: 'Menadžer proizvodnje',
          nextStep:
              'Otvorite proizvodni nalog i provjerite status izvršenja, radni centar, HOLD, materijal i zastoj.',
          doneWhen:
              'Rizik je obrađen, rok usklađen ili je nalog vraćen u plan.',
        );
      case 'DOWNTIME_EXCEEDED':
        return const MesInboxActionGuide(
          need: 'Pregledajte zastoj koji traje duže od praga.',
          owner: 'Proizvodnja / održavanje',
          nextStep: 'Otvorite ovu obavijest — zastoj.',
          doneWhen: 'Kad je zastoj završen ili obrađen.',
        );
      default:
        return const MesInboxActionGuide(
          need: 'Otvorite obavijest i uradite traženi posao.',
          owner: 'Dodijeljena odgovorna osoba',
          nextStep: 'Otvorite ovu obavijest — povezani ekran.',
          doneWhen: 'Kad je traženi posao završen.',
        );
    }
  }

  static bool looksInternal(String raw, {String eventCode = ''}) {
    final t = raw.trim();
    if (t.isEmpty) return true;
    if (eventCode.isNotEmpty && t == eventCode) return true;
    if (titles.containsKey(t)) return true;
    if (RegExp(r'^S[1-4]$').hasMatch(t)) return true;
    if (t.contains('@')) return true;
    if (RegExp(r'^PLANT_[A-Za-z0-9_]+$', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'quality hold', caseSensitive: false).hasMatch(t)) return true;
    if (RegExp(r'\bSCADA\b').hasMatch(t)) return true;
    if (RegExp(r'\bSLA\b').hasMatch(t)) return true;
    if (RegExp(r'\boffline\b', caseSensitive: false).hasMatch(t)) return true;
    if (RegExp(r'\bfeed(a|s)?\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'\b(ack|permission|pending|verify|notification)\b',
            caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^[A-Z][A-Z0-9_]{3,}$').hasMatch(t)) return true;
    if (RegExp(r'^NCR-[A-Z0-9]+(?:-[A-Z0-9]+)*$', caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    if (RegExp(r'\bNCR-[A-Z0-9]+(?:-[A-Z0-9]+)*\b', caseSensitive: false)
        .hasMatch(t)) {
      return true;
    }
    for (final key in evidenceProfileLabels.keys) {
      if (t.contains(key)) return true;
    }
    return false;
  }

  static String sanitizeVisible(String raw, {String eventCode = ''}) {
    var out = raw.trim();
    if (out.isEmpty) return '';
    if (eventCode.isNotEmpty) {
      out = out.replaceAll(eventCode, '');
    }
    for (final code in titles.keys) {
      out = out.replaceAll(code, '');
    }
    for (final entry in evidenceProfileLabels.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    out = out.replaceAll(
      RegExp(r'\bNCR-[A-Z0-9]+(?:-[A-Z0-9]+)*\b', caseSensitive: false),
      '',
    );
    out = out.replaceAll(RegExp(r'\bS[1-4]\b'), '');
    out = out.replaceAll(RegExp(r'\bPLANT_[A-Za-z0-9_]+\b', caseSensitive: false), '');
    out = out.replaceAll(
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'),
      '',
    );
    out = out.replaceAll(RegExp(r'\b[0-9a-f]{20,}\b', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\b[A-Za-z0-9]{28}\b'), '');
    out = out.replaceAll(RegExp(r'quality hold', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\bSCADA\b'), '');
    out = out.replaceAll(RegExp(r'\(SLA\)', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\bSLA\b'), '');
    out = out.replaceAll(RegExp(r'\(ack\)', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\(telemetrija\)', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\boffline\b', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\bfeed(a|s)?\b', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'\brelease\b', caseSensitive: false), 'puštanje');
    out = out.replaceAll(RegExp(r'\(\s*\)'), '');
    out = out.replaceAll(RegExp(r'\s*[—\-]\s*[—\-]\s*'), ' — ');
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
    out = out.replaceAll(RegExp(r'^[\s—\-:/,]+|[\s—\-:/,]+$'), '');
    return out.trim();
  }

  static String _asString(dynamic v) => (v ?? '').toString().trim();
}
