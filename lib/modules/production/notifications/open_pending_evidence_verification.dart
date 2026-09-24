import 'package:flutter/material.dart';
import 'package:production_app/features/catalog_evidence_runtime/screens/catalog_evidence_station_screen.dart';
import 'package:production_app/modules/production/station_pages/models/production_station_profile_catalog_entry.dart';
import 'package:production_app/modules/production/station_pages/screens/production_evidence_operator_launch_screen.dart';
import 'package:production_app/modules/production/station_pages/services/production_evidence_config_callable_service.dart';
import 'package:production_app/modules/production/station_pages/services/production_station_config_callable_service.dart';
import 'package:production_app/modules/production/station_work/services/production_station_work_session_callable_service.dart';

import 'evidence_verification_notification_payload.dart';

const String _openingVerificationMessage =
    'Otvaram evidenciju za verifikaciju...';

/// HOTFIX-21 — deep-link na konkretnu aktivnu sesiju, bez čekanja kataloga.
Future<void> openPendingEvidenceVerification({
  required NavigatorState navigator,
  required Map<String, dynamic> companyData,
  required Map<String, dynamic> payload,
}) async {
  final evidenceConfigId =
      EvidenceVerificationNotificationPayload.evidenceConfigIdFromData(payload);
  if (evidenceConfigId.isEmpty) {
    _showUnavailable(navigator);
    return;
  }

  final companyId = (companyData['companyId'] ?? '').toString().trim();
  if (companyId.isEmpty) {
    _showUnavailable(navigator);
    return;
  }

  final overlay = navigator.overlay;
  if (overlay == null) {
    _showUnavailable(navigator);
    return;
  }
  final entry = OverlayEntry(
    builder: (_) => const AbsorbPointer(
      child: ColoredBox(
        color: Color(0x66000000),
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(_openingVerificationMessage),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);

  try {
    final evidenceCallables = ProductionEvidenceConfigCallableService();
    final sessionCallables = ProductionStationWorkSessionCallableService();
    final evidenceFuture = evidenceCallables.getProductionEvidenceConfig(
      companyId: companyId,
      evidenceConfigId: evidenceConfigId,
    );
    final sessionFuture = sessionCallables.getActiveProductionEvidenceWorkSession(
      companyId: companyId,
      evidenceConfigId: evidenceConfigId,
    );
    final config = await evidenceFuture;
    final active = await sessionFuture;

    ProductionStationProfileCatalogEntry? profile =
        _profileFromSessionSnapshot(active);
    var catalogVersion = 0;
    if (profile == null || !profile.isComplete) {
      final profileCallables = ProductionStationConfigCallableService();
      final catalog = await profileCallables.listProductionStationProfiles(
        companyId: companyId,
      );
      catalogVersion = catalog.catalogVersion;
      for (final item in catalog.profiles) {
        if (item.profileKey == config.profileKey) {
          profile = item;
          break;
        }
      }
    }
    if (profile == null) {
      entry.remove();
      _showUnavailable(navigator);
      return;
    }
    final resolvedProfile = profile;

    final merged = Map<String, dynamic>.from(companyData);
    final plantFromPayload =
        EvidenceVerificationNotificationPayload.plantKeyFromData(payload);
    if ((merged['plantKey'] ?? '').toString().trim().isEmpty &&
        plantFromPayload.isNotEmpty) {
      merged['plantKey'] = plantFromPayload;
    }

    final expectedSessionId =
        EvidenceVerificationNotificationPayload.sessionIdFromData(payload);
    if (expectedSessionId.isNotEmpty &&
        active != null &&
        active.session.isActive &&
        active.session.id.trim() != expectedSessionId) {
      entry.remove();
      _showUnavailable(navigator);
      return;
    }

    entry.remove();
    if (!navigator.mounted) return;

    if (active != null && active.session.isActive) {
      await navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CatalogEvidenceStationScreen.companyEvidence(
            companyData: merged,
            evidenceConfig: config,
            profile: resolvedProfile,
            profileCatalogVersion: catalogVersion,
            preloadedActiveSession: active,
            skipLiveCatalogRefresh: true,
          ),
        ),
      );
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionEvidenceOperatorLaunchScreen(
          companyData: merged,
          evidenceConfig: config,
          profile: resolvedProfile,
          profileCatalogVersion: catalogVersion,
        ),
      ),
    );
  } catch (_) {
    entry.remove();
    _showUnavailable(navigator);
  }
}

ProductionStationProfileCatalogEntry? _profileFromSessionSnapshot(
  ActiveStructuredSessionResult? active,
) {
  final raw = active?.session.profileSnapshot;
  if (raw == null || raw.isEmpty) return null;
  final profile = ProductionStationProfileCatalogEntry.fromMap(raw);
  if (profile.profileKey.isEmpty || !profile.isComplete) return null;
  return profile;
}

void _showUnavailable(NavigatorState navigator) {
  final ctx = navigator.context;
  ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
    const SnackBar(
      content: Text('Evidencija nije dostupna za verifikaciju.'),
    ),
  );
}
