import 'package:flutter_test/flutter_test.dart';
import 'package:production_app/features/station_evidence/models/profile_driven_evidence_session.dart';
import 'package:production_app/features/station_evidence/utils/evidence_detail_handoff.dart';

void main() {
  test('HOTFIX-22 handoff labels stay BCS without Operator audit', () {
    expect(EvidenceDetailHandoff.sectionTitle, 'Predaja i verifikacija');
    expect(EvidenceDetailHandoff.performedByLabel, 'Izvršio');
    expect(EvidenceDetailHandoff.verifiedByLabel, 'Verifikovao');
    expect(EvidenceDetailHandoff.statusLabel, 'Status');
    expect(
      EvidenceDetailHandoff.looksLikeInternalEvidenceText('Operator audit'),
      isTrue,
    );
    expect(
      EvidenceDetailHandoff.looksLikeInternalEvidenceText('operater@firma.ba'),
      isTrue,
    );
    expect(
      EvidenceDetailHandoff.looksLikeInternalEvidenceText('Test korisnik'),
      isFalse,
    );
  });

  test('HOTFIX-22 names come from audit then snapshots, never email', () {
    final save = ProductionEvidenceAuditItem(
      action: 'evidence_session_updated',
      actionLabel: 'Spremanje izmjene',
      summary: 'Sačuvana izmjena evidencije. Izvršio: Test korisnik.',
      performedByName: 'Test korisnik',
      performedByRoleLabel: 'Operater proizvodnje',
      performedAt: DateTime(2026, 9, 11, 12, 0),
    );
    final verify = ProductionEvidenceAuditItem(
      action: 'evidence_session_verified',
      actionLabel: 'Verifikacija / odobrenje',
      summary: 'Verifikovao neposredni rukovodilac.',
      performedByName: 'Mirza Nuhan',
      performedByRoleLabel: 'Menadžer proizvodnje',
      performedAt: DateTime(2026, 9, 11, 12, 30),
    );
    expect(
      EvidenceDetailHandoff.performedByName(
        fieldValues: const {},
        auditItems: [verify, save],
      ),
      'Test korisnik',
    );
    expect(
      EvidenceDetailHandoff.verifiedByName(
        fieldValues: const {},
        auditItems: [verify, save],
      ),
      'Mirza Nuhan',
    );
    expect(
      EvidenceDetailHandoff.performedByName(
        fieldValues: const {
          'performedByNameSnapshot': 'Test korisnik',
          'verifiedByNameSnapshot': 'Mirza Nuhan',
        },
        auditItems: const [],
      ),
      'Test korisnik',
    );
  });
}
