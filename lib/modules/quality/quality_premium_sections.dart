/// Vizuelne grupe Premium huba. Redoslijed unutar grupe ostaje poslovni.
String qualityPremiumSectionForTitle(String title) {
  switch (title) {
    case 'Moje otvorene akcije':
    case 'Kontrolne evidencije':
      return 'Prioritet';
    case 'Metodologija · IATF':
    case 'Pregled kvaliteta':
    case 'Dokumentacija':
      return 'Sistem';
    case 'PFMEA (proces)':
    case 'Kontrolni planovi':
    case 'Planovi kontrole':
      return 'Planiranje';
    case 'Izvještaj za vodstvo':
      return 'Izvještavanje';
    default:
      return 'Operativa';
  }
}

const List<String> qualityPremiumSectionOrder = [
  'Prioritet',
  'Sistem',
  'Planiranje',
  'Izvještavanje',
  'Operativa',
];
