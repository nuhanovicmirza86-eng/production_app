import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_presentation.dart';

void main() {
  test('NOTIF-M1-B hides raw event codes and severity in list copy', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'VERIFIKACIJA_EVIDENCIJE',
      'title': 'Evidencija čeka verifikaciju',
      'body': '5S čišćenje radnog prostora čeka verifikaciju za pogon Brizganje (BR).',
      'severity': 'S2',
      'readAt': null,
    });
    expect(copy.title, 'Evidencija čeka verifikaciju');
    expect(copy.body.contains('VERIFIKACIJA_EVIDENCIJE'), isFalse);
    expect(copy.body.contains('S2'), isFalse);
    expect(copy.readLabel, 'Čeka akciju');
    expect(copy.waitingAction, isTrue);
    expect(copy.band, MesInboxPriorityBand.warnings);
  });

  test('NOTIF-M1-B maps empty title that was the event code', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'PROD_ORDER_AT_RISK',
      'title': 'PROD_ORDER_AT_RISK',
      'body': 'S3 — ORDER_RELEASE_PENDING',
      'severity': 'S3',
    });
    expect(copy.title, 'Rizik kašnjenja roka');
    expect(copy.title.contains('PROD_ORDER_AT_RISK'), isFalse);
    expect(copy.body.contains('ORDER_RELEASE_PENDING'), isFalse);
    expect(copy.body.contains('S3'), isFalse);
  });

  test('NOTIF-M1-B replaces English quality hold title', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'QUALITY_HOLD',
      'title': 'Quality hold na lotu',
      'body': 'Lot abc — stavljen na quality hold.',
      'severity': 'S4',
      'readAt': 'x',
    });
    expect(copy.title, 'Lot na zadržavanju kvaliteta');
    expect(copy.title.toLowerCase().contains('quality'), isFalse);
    expect(copy.body.toLowerCase().contains('hold'), isFalse);
    expect(copy.readLabel, 'Čeka akciju');
    expect(copy.waitingAction, isTrue);
    expect(copy.band, MesInboxPriorityBand.critical);
  });

  test('NOTIF-M1-B filters unread, all, critical, warnings, info', () {
    final unreadWarn = MesInboxPresentation.fromRow({
      'eventCode': 'VERIFIKACIJA_EVIDENCIJE',
      'title': 'Evidencija čeka verifikaciju',
      'body': 'Evidencija čeka verifikaciju ovlaštene osobe.',
      'severity': 'S2',
    });
    final readCrit = MesInboxPresentation.fromRow({
      'eventCode': 'DOWNTIME_EXCEEDED',
      'title': 'Zastoj traje duže od praga',
      'body': 'Zastoj traje duže od dopuštenog praga.',
      'severity': 'S4',
      'readAt': Object(),
    });
    final unreadInfo = MesInboxPresentation.fromRow({
      'eventCode': 'EXEC_STARTED',
      'title': 'Rad pokrenut',
      'body': 'Izvršenje naloga je pokrenuto.',
      'severity': 'S1',
    });

    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.unread, unreadWarn),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.unread, readCrit),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.all, readCrit),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.critical, readCrit),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesFilter(
        MesInboxListFilter.warnings,
        unreadWarn,
      ),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.info, unreadInfo),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.info, unreadWarn),
      isFalse,
    );
  });

  test('NOTIF-M1-B visible copy has no email, UID, plantKey or EN tokens', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'MAINTENANCE_AI_WATCH_DIGEST',
      'title': 'Sažetak PLANT_2 user@firma.com abcdefabcdefabcdefabcdefabcd',
      'body': 'permission pending verify notification SCADA feed offline',
      'severity': 'S2',
    });
    expect(copy.title.contains('@'), isFalse);
    expect(copy.title.contains('PLANT_2'), isFalse);
    expect(copy.body.contains('permission'), isFalse);
    expect(copy.body.toLowerCase().contains('scada'), isFalse);
    expect(copy.title.contains('abcdefabcdefabcdefabcdefabcd'), isFalse);
  });

  test('NOTIF-M1-B4 period filters use calendar windows', () {
    final now = DateTime(2026, 9, 16, 10, 0);
    expect(
      MesInboxPresentation.periodLabel(MesInboxPeriodFilter.today),
      'Danas',
    );
    expect(
      MesInboxPresentation.periodLabel(MesInboxPeriodFilter.days3),
      '3 dana',
    );
    expect(MesInboxPresentation.periodWireValue(MesInboxPeriodFilter.days7), 'd7');
    expect(
      MesInboxPresentation.matchesPeriod(
        MesInboxPeriodFilter.today,
        DateTime(2026, 9, 16, 1, 0),
        now: now,
      ),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesPeriod(
        MesInboxPeriodFilter.today,
        DateTime(2026, 9, 15, 23, 0),
        now: now,
      ),
      isFalse,
    );
    expect(
      MesInboxPresentation.matchesPeriod(
        MesInboxPeriodFilter.days3,
        DateTime(2026, 9, 14, 0, 0),
        now: now,
      ),
      isTrue,
    );
    expect(
      MesInboxPresentation.matchesPeriod(
        MesInboxPeriodFilter.days3,
        DateTime(2026, 9, 13, 23, 0),
        now: now,
      ),
      isFalse,
    );
    expect(
      MesInboxPresentation.matchesPeriod(
        MesInboxPeriodFilter.all,
        null,
        now: now,
      ),
      isTrue,
    );
  });

  test('NOTIF-M1-B4 action stays waiting after read', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'VERIFIKACIJA_EVIDENCIJE',
      'title': 'Evidencija čeka verifikaciju',
      'body': 'Evidencija čeka verifikaciju ovlaštene osobe.',
      'severity': 'S2',
      'readAt': Object(),
    });
    expect(copy.isRead, isTrue);
    expect(copy.waitingAction, isTrue);
    expect(copy.readLabel, 'Čeka akciju');
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.unread, copy),
      isTrue,
    );
  });

  test('NOTIF-M1-B4 information read is not waiting action', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'EXEC_STARTED',
      'title': 'Rad pokrenut',
      'body': 'Izvršenje naloga je pokrenuto.',
      'severity': 'S1',
      'readAt': Object(),
    });
    expect(copy.isRead, isTrue);
    expect(copy.waitingAction, isFalse);
    expect(copy.readLabel, 'Pročitano');
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.unread, copy),
      isFalse,
    );
  });

  test('NOTIF-M1-MA-HOTFIX-01 hides NCR ids and evidence profile keys', () {
    final firstPiece = MesInboxPresentation.fromRow({
      'eventCode': 'EVIDENCE_OUTCOME_NCR',
      'title': 'NCR-MTBFMEGA',
      'body':
          'NCR-MTBFMEGA: Odbijeno (first_piece_approval). Otvorite NCR u QMS.',
      'severity': 'S3',
      'extra': {'evidenceProfileKey': 'first_piece_approval'},
    });
    expect(firstPiece.title, 'NCR otvoren iz evidencije');
    expect(firstPiece.title.contains('NCR-MTBFMEGA'), isFalse);
    expect(firstPiece.body, contains('Odobrenje prvog komada'));
    expect(firstPiece.body.contains('first_piece_approval'), isFalse);
    expect(firstPiece.body.contains('NCR-MTBFMEGA'), isFalse);
    expect(firstPiece.body, contains('Otvoren je NCR u QMS-u.'));
    expect(firstPiece.waitingAction, isTrue);
    expect(firstPiece.actionGuide, isNotNull);
    expect(firstPiece.actionGuide!.need, contains('QMS'));
    expect(firstPiece.actionGuide!.owner, 'Kvalitet');
    expect(firstPiece.actionGuide!.nextStep, contains('neusaglašenosti'));
    expect(firstPiece.actionGuide!.doneWhen, contains('obrađena'));

    final finalControl = MesInboxPresentation.fromRow({
      'eventCode': 'EVIDENCE_OUTCOME_NCR',
      'title': 'NCR otvoren iz evidencije',
      'body': 'NCR-MT6XL6GH: Odbijeno (final_control). Otvorite NCR u QMS.',
      'severity': 'S3',
    });
    expect(finalControl.title, 'NCR otvoren iz evidencije');
    expect(
      finalControl.body,
      'Finalna kontrola nije odobrena za nastavak. Otvoren je NCR u QMS-u.',
    );
    expect(finalControl.body.contains('final_control'), isFalse);
    expect(finalControl.body.contains('NCR-MT6XL6GH'), isFalse);
    expect(finalControl.actionGuide, isNotNull);
  });

  test('NOTIF-M1-C2 waiting items expose action resolution copy', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'FAULT_CREATED',
      'title': 'Prijavljen je novi kvar',
      'body': 'Na pogonu je prijavljen novi kvar.',
      'severity': 'S4',
    });
    expect(copy.readLabel, 'Čeka akciju');
    expect(copy.actionGuide, isNotNull);
    expect(copy.actionGuide!.need, contains('kvar'));
    expect(copy.actionGuide!.owner, 'Održavanje');
    expect(copy.actionGuide!.nextStep, contains('detalj kvara'));
    expect(copy.actionGuide!.doneWhen, isNotEmpty);
  });

  test('NOTIF-M1-C3 order risk copy and close status', () {
    final waiting = MesInboxPresentation.fromRow({
      'eventCode': 'PROD_ORDER_AT_RISK',
      'title': 'Rizik kašnjenja roka',
      'body': 'Nalog -260603-93314 je i dalje u riziku.',
      'severity': 'S3',
      'isActionOwner': true,
      'repeatCount': 4,
      'lastTriggeredAt': DateTime(2026, 9, 16, 10, 54),
    });
    expect(waiting.waitingAction, isTrue);
    expect(waiting.canCloseWithoutAction, isTrue);
    expect(waiting.repeatLabel, 'Ponovljeno: 4 puta');
    expect(waiting.actionGuide!.need, contains('korektivnu akciju'));
    expect(waiting.actionGuide!.nextStep, contains('HOLD'));
    expect(waiting.actionGuide!.doneWhen, contains('vraćen u plan'));

    final closed = MesInboxPresentation.fromRow({
      'eventCode': 'PROD_ORDER_AT_RISK',
      'title': 'Rizik kašnjenja roka',
      'body': 'Nalog -260603-93314 je i dalje u riziku.',
      'severity': 'S3',
      'isActionOwner': true,
      'readAt': Object(),
      'closedWithoutActionAt': Object(),
      'status': 'closed_without_action',
    });
    expect(closed.waitingAction, isFalse);
    expect(closed.canCloseWithoutAction, isFalse);
    expect(closed.readLabel, 'Zatvoreno bez akcije');
    expect(closed.closedWithoutAction, isTrue);
  });
}
