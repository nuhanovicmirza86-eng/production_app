/// Kanonski tekstovi usklađeni s backend `computeLaunchReadinessScore`
/// (`development_project_writes.js`) — jedan izvor za KPI / Command Center UI.
abstract final class DevelopmentLaunchReadinessCanonical {
  static const List<({String label, int weightPercent})> segmentWeights = [
    (label: 'APQP faze završene', weightPercent: 10),
    (label: 'PPAP kompletiranost', weightPercent: 15),
    (label: 'PFMEA / rizici zatvoreni', weightPercent: 15),
    (label: 'Control Plan usklađen', weightPercent: 10),
    (label: 'Probna serija uspješna (G5)', weightPercent: 15),
    (label: 'Procesna kapabilnost', weightPercent: 10),
    (label: 'Alat / mašina spremni', weightPercent: 10),
    (label: 'Dobavljači i materijali', weightPercent: 5),
    (label: 'Quality nalazi zatvoreni', weightPercent: 5),
    (label: 'Lekcije (G9)', weightPercent: 5),
  ];

  static const List<({String range, String systemBehavior})> scoreRules = [
    (range: '90–100', systemBehavior: 'Može SOP (release prema pravilima i bez blokera)'),
    (range: '75–89', systemBehavior: 'Uslovno — SOP uz odobrenje menadžmenta u Operonixu'),
    (range: '60–74', systemBehavior: 'Blokada SOP-a dok se rizici i prag ne poprave'),
    (range: '<60', systemBehavior: 'Nije spremno za serijsku proizvodnju'),
  ];

  static const List<String> intelligenceLayerPillars = [
    'Launch Readiness Score (0–100) i pragovi',
    'SOP blocker-i (čvrsta pravila prije serije)',
    'Change impact analiza (što promjena dira — BOM, PPAP, PFMEA…)',
    'Lessons learned / slični projekti u tenantu',
    'Dynamic Control Plan prijedlozi (živi plan, ne samo PDF)',
  ];

  static const List<String> heatmapLevelLabels = [
    'OK (zeleno)',
    'Pratiti (žuto)',
    'Akcija (narandžasto)',
    'Blokira SOP (crveno)',
  ];
}
