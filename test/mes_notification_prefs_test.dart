import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/notifications/mes_notification_prefs.dart';

void main() {
  test('NOTIF-M1-D1 system cannot be disabled', () {
    final prefs = MesNotificationPrefs.fromUser({
      'mesNotificationPrefs': {'system': false, 'ai': false},
    });
    expect(prefs.isEnabled('system'), isTrue);
    expect(prefs.isEnabled('ai'), isFalse);
    expect(prefs.allowsEvent('SECURITY_EVENT'), isTrue);
    expect(prefs.allowsEvent('OPERONIX_AI_BRIEFING'), isFalse);
  });

  test('NOTIF-M1-D1 muted production hides info but keeps locked risk', () {
    final prefs = MesNotificationPrefs.fromUser({
      'mesNotificationPrefs': {'production': false},
    });
    expect(prefs.allowsEvent('EXEC_STARTED'), isFalse);
    expect(prefs.allowsEvent('PROD_ORDER_AT_RISK'), isTrue);
    expect(
      prefs.allowsRow({'eventCode': 'MES_SLA_ESCALATION'}),
      isTrue,
    );
  });

  test('NOTIF-M1-D1 quality lock keeps HOLD', () {
    final prefs = MesNotificationPrefs.fromUser({
      'mesNotificationPrefs': {'quality': false},
    });
    expect(prefs.allowsEvent('NCR_CLOSED'), isFalse);
    expect(prefs.allowsEvent('QUALITY_HOLD'), isTrue);
    expect(prefs.allowsEvent('VERIFIKACIJA_EVIDENCIJE'), isTrue);
  });
}
