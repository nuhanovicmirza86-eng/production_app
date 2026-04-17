import 'package:flutter/foundation.dart';

import 'package:production_app/modules/production/tracking/models/production_operator_tracking_entry.dart';

/// Način pokretanja „samo stanica“ na jednom računalu (jednokratno u prečicu / build).
///
/// Postavlja se pri **kompilaciji**:
///
/// ```text
/// flutter run --dart-define=OPERONIX_STATION=preparation
/// ```
///
/// Ili u Visual Studio / prečicu na `.exe`:
///
/// ```text
/// operonix_production.exe --dart-define=OPERONIX_STATION=preparation
/// ```
///
/// (Za release build isti `dart-define` mora biti u `flutter build windows` naredbi.)
///
/// Podržane vrijednosti [raw] (case-insensitive):
/// - `preparation` / `prep` → pripremna stanica (+ traka sesije)
/// - `first_control` / `first` → prva kontrola
/// - `final_control` / `final` → završna kontrola
///
/// Prazno = normalan ulaz u [ProductionDashboardScreen].
///
/// **Prioritet:** ako je ovdje postavljeno, **nadjačava** lokalnu postavku s prijave
/// ([StationLaunchPreference] na uređaju).
class StationLaunchConfig {
  StationLaunchConfig._();

  static const String _raw = String.fromEnvironment(
    'OPERONIX_STATION',
    defaultValue: '',
  );

  /// Je li build namijenjen jednom PC-ju koji uvijek otvara stanicu nakon prijave.
  static bool get isDedicatedLaunch => _raw.trim().isNotEmpty;

  /// Faza stanice ili `null` ako nije dedicated ili je nepoznata vrijednost.
  static String? get phaseOrNull {
    final v = _raw.trim().toLowerCase();
    switch (v) {
      case 'preparation':
      case 'prep':
        return ProductionOperatorTrackingEntry.phasePreparation;
      case 'first_control':
      case 'first':
        return ProductionOperatorTrackingEntry.phaseFirstControl;
      case 'final_control':
      case 'final':
        return ProductionOperatorTrackingEntry.phaseFinalControl;
      default:
        if (kDebugMode && v.isNotEmpty) {
          debugPrint(
            'StationLaunchConfig: nepoznata OPERONIX_STATION="$v" — koristi se dashboard.',
          );
        }
        return null;
    }
  }
}
