import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_attention.dart';
import 'package:production_app/modules/production/notifications/mes_inbox_presentation.dart';

void main() {
  test('NOTIF-M1-C counts new and waiting action without raw codes', () {
    final rows = [
      {
        'eventCode': 'EXEC_STARTED',
        'title': 'Rad pokrenut',
        'body': 'Izvršenje naloga je pokrenuto.',
        'severity': 'S1',
      },
      {
        'eventCode': 'VERIFIKACIJA_EVIDENCIJE',
        'title': 'Evidencija čeka verifikaciju',
        'body': 'Evidencija čeka verifikaciju ovlaštene osobe.',
        'severity': 'S2',
      },
      {
        'eventCode': 'QUALITY_HOLD',
        'title': 'Lot na zadržavanju kvaliteta',
        'body': 'Lot je stavljen na zadržavanje kvaliteta.',
        'severity': 'S4',
        'requiresAction': true,
        'readAt': Object(),
      },
    ];
    final counts = MesInboxAttention.countsFromRows(rows);
    expect(counts.newCount, 2);
    expect(counts.waitingActionCount, 2);
    expect(MesInboxAttention.badgeLabel(counts), '2');
    expect(MesInboxAttention.badgeLabel(counts).contains('/'), isFalse);
    expect(
      MesInboxAttention.homeCardBody(counts),
      '2 nove obavijesti · 2 čeka akciju',
    );
    expect(MesInboxAttention.homeCardChipLabels(counts), [
      '2 nove',
      '2 čeka akciju',
    ]);
    expect(
      MesInboxAttention.badgeTooltip(counts).contains('VERIFIKACIJA'),
      isFalse,
    );
  });

  test('NOTIF-M1-C hides home card copy when nothing waits', () {
    final counts = MesInboxAttention.countsFromRows(const [
      {
        'eventCode': 'EXEC_STARTED',
        'title': 'Rad pokrenut',
        'readAt': Object(),
      },
    ]);
    expect(counts.hasAttention, isFalse);
    expect(MesInboxAttention.badgeLabel(counts), '');
  });

  test('NOTIF-M1-C in-app message uses business title', () {
    expect(
      MesInboxAttention.inAppMessage('Puštanje naloga još čeka'),
      'Nova obavijest: Puštanje naloga još čeka',
    );
  });

  test('NOTIF-M1-C-UI-HOTFIX-02 skips in-app banner on inbox screen', () {
    expect(
      MesInboxAttention.shouldShowInAppBanner(isOnInboxScreen: true),
      isFalse,
    );
    expect(
      MesInboxAttention.shouldShowInAppBanner(isOnInboxScreen: false),
      isTrue,
    );
    expect(MesInboxAttention.inAppHeadline(), 'Nova obavijest');
    expect(
      MesInboxAttention.inAppSubtitle('Rizik kašnjenja roka'),
      'Rizik kašnjenja roka',
    );
    expect(MesInboxAttention.inAppOpenLabel(), 'Otvori');
    expect(MesInboxAttention.inAppCloseTooltip(), 'Zatvori');
    expect(MesInboxAttention.inAppBannerVisibleFor.inSeconds, 4);
    expect(
      MesInboxAttention.inAppHeadline().contains('PROD_ORDER'),
      isFalse,
    );
  });

  test('NOTIF-M1-C-UI-HOTFIX-01 caps only the nav badge', () {
    const crowded = MesInboxAttentionCounts(
      newCount: 198,
      waitingActionCount: 50,
    );
    expect(MesInboxAttention.badgeLabel(crowded), '99+');
    expect(MesInboxAttention.badgeLabel(crowded).contains('/'), isFalse);
    expect(MesInboxAttention.homeCardChipLabels(crowded), [
      '198 novih',
      '50 čeka akciju',
    ]);
    expect(
      MesInboxAttention.homeCardBody(crowded),
      '198 novih obavijesti · 50 čeka akciju',
    );
    const exact = MesInboxAttentionCounts(newCount: 12, waitingActionCount: 3);
    expect(MesInboxAttention.badgeLabel(exact), '12');
    const waitingOnly = MesInboxAttentionCounts(
      newCount: 0,
      waitingActionCount: 4,
    );
    expect(MesInboxAttention.badgeLabel(waitingOnly), '4');
    expect(MesInboxAttention.homeCardChipLabels(waitingOnly), [
      '4 čeka akciju',
    ]);
  });

  test('NOTIF-M1-C unread filter keeps waiting action after open', () {
    final copy = MesInboxPresentation.fromRow({
      'eventCode': 'QUALITY_HOLD',
      'title': 'Lot na zadržavanju kvaliteta',
      'body': 'Lot je stavljen na zadržavanje kvaliteta.',
      'severity': 'S4',
      'requiresAction': true,
      'readAt': Object(),
    });
    expect(copy.waitingAction, isTrue);
    expect(copy.readLabel, 'Čeka akciju');
    expect(
      MesInboxPresentation.matchesFilter(MesInboxListFilter.unread, copy),
      isTrue,
    );
  });

  test('NOTIF-M1-B3-HOTFIX-02 keeps production order risk in Production app', () {
    expect(
      MesInboxAttention.isVisibleInThisApp({
        'eventCode': 'PROD_ORDER_AT_RISK',
      }),
      isTrue,
    );
    expect(
      MesInboxAttention.isVisibleInThisApp({
        'eventCode': 'FAULT_CREATED',
      }),
      isFalse,
    );
    expect(
      MesInboxAttention.isVisibleInThisApp({
        'eventCode': 'MES_SLA_ESCALATION',
        'extra': {'originalEventCode': 'PROD_ORDER_AT_RISK'},
        'status': 'archived',
      }),
      isFalse,
    );
  });
}
