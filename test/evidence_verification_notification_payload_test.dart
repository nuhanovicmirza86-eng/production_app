import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/modules/production/notifications/evidence_verification_notification_payload.dart';

void main() {
  test('HOTFIX-17 reads evidenceConfigId from extra and FCM flatten', () {
    expect(
      EvidenceVerificationNotificationPayload.evidenceConfigIdFromData({
        'extra': {'evidenceConfigId': 'plamingo__ev_12'},
        'entityId': 'session-1',
      }),
      'plamingo__ev_12',
    );
    expect(
      EvidenceVerificationNotificationPayload.evidenceConfigIdFromData({
        'evidenceConfigId': 'plamingo__ev_12',
        'entityId': 'session-1',
      }),
      'plamingo__ev_12',
    );
    expect(
      EvidenceVerificationNotificationPayload.evidenceConfigIdFromData({
        'entityId': 'session-1',
      }),
      '',
    );
  });

  test('QA-GATE-01 reads sessionId from extra, flatten, or inbox entityId', () {
    expect(
      EvidenceVerificationNotificationPayload.sessionIdFromData({
        'extra': {'sessionId': 'sess-a'},
        'entityId': 'other',
      }),
      'sess-a',
    );
    expect(
      EvidenceVerificationNotificationPayload.sessionIdFromData({
        'sessionId': 'sess-b',
        'entityId': 'other',
      }),
      'sess-b',
    );
    expect(
      EvidenceVerificationNotificationPayload.sessionIdFromData({
        'entityId': 'sess-c',
      }),
      'sess-c',
    );
  });
}
