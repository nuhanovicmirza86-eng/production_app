import 'production_station_page.dart';

/// Rezultat provjere `production_station_pages` prije ulaska u puni zaslon stanice.
///
/// **Blokada** samo ako je stanica u bazi eksplicitno `active == false` (ili nema konteksta tenant-a).
/// Nedostajući dokument ili druga faza **ne** blokiraju — tvrtka može imati 1–3 stanice bez obaveznog CRUD-a za sve slotove.
class StationPageGateResult {
  final ProductionStationPage? page;
  final String? blockingMessage;

  bool get isAllowed => blockingMessage == null;

  const StationPageGateResult._({this.page, this.blockingMessage});

  /// [page] je opcionalan ako u bazi još nema zapisa za taj slot.
  factory StationPageGateResult.ok([ProductionStationPage? page]) {
    return StationPageGateResult._(page: page);
  }

  factory StationPageGateResult.blocked(String message) {
    return StationPageGateResult._(blockingMessage: message);
  }
}
