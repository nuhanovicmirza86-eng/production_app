// Kanonski šifarnik djelatnosti (NACE Rev. 2 — sekcije + uobičajene grane).
// U Firestore polju `activitySector` čuva se isključivo ActivitySectorDef.code.

class ActivitySectorDef {
  const ActivitySectorDef({required this.code, required this.label});

  /// Stabilan ASCII kod (bez razmaka i dijakritika u problemima).
  final String code;

  /// Prikaz korisniku (BS/HR).
  final String label;
}

/// Sortirano po oznaci za dropdown.
List<ActivitySectorDef> get activitySectorCatalogSorted {
  final copy = List<ActivitySectorDef>.from(kActivitySectorCatalog);
  copy.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return copy;
}

/// Poznati kodovi (brza provjera).
Set<String> get activitySectorKnownCodes =>
    kActivitySectorCatalog.map((e) => e.code).toSet();

const List<ActivitySectorDef> kActivitySectorCatalog = [
  // Sekcije NACE A–U (sažeto)
  ActivitySectorDef(
    code: 'nace_a',
    label: 'A — Poljoprivreda, šumarstvo i ribolov',
  ),
  ActivitySectorDef(
    code: 'nace_b',
    label: 'B — Rudarstvo i vađenje',
  ),
  ActivitySectorDef(
    code: 'nace_c',
    label: 'C — Prerađivačka industrija',
  ),
  ActivitySectorDef(
    code: 'nace_d',
    label: 'D — Snadbijevanje električnom energijom, plinom, parom, klimom',
  ),
  ActivitySectorDef(
    code: 'nace_e',
    label: 'E — Snadbijevanje vodom; otpadne vode, upravljanje otpadom',
  ),
  ActivitySectorDef(
    code: 'nace_f',
    label: 'F — Građevinarstvo',
  ),
  ActivitySectorDef(
    code: 'nace_g',
    label: 'G — Trgovina na veliko i na malo; popravak motornih vozila',
  ),
  ActivitySectorDef(
    code: 'nace_h',
    label: 'H — Prijevoz i skladištenje',
  ),
  ActivitySectorDef(
    code: 'nace_i',
    label: 'I — Ugostiteljstvo',
  ),
  ActivitySectorDef(
    code: 'nace_j',
    label: 'J — Informacije i komunikacije',
  ),
  ActivitySectorDef(
    code: 'nace_k',
    label: 'K — Finansijske djelatnosti i osiguranje',
  ),
  ActivitySectorDef(
    code: 'nace_l',
    label: 'L — Poslovanje nekretninama',
  ),
  ActivitySectorDef(
    code: 'nace_m',
    label: 'M — Stručne, naučne i tehničke djelatnosti',
  ),
  ActivitySectorDef(
    code: 'nace_n',
    label: 'N — Administrativne i pomoćne usluge',
  ),
  ActivitySectorDef(
    code: 'nace_o',
    label: 'O — Javna uprava i odbrana; obavezno socijalno osiguranje',
  ),
  ActivitySectorDef(
    code: 'nace_p',
    label: 'P — Obrazovanje',
  ),
  ActivitySectorDef(
    code: 'nace_q',
    label: 'Q — Zdravstvo i socijalna zaštita',
  ),
  ActivitySectorDef(
    code: 'nace_r',
    label: 'R — Umjetnost, zabava i rekreacija',
  ),
  ActivitySectorDef(
    code: 'nace_s',
    label: 'S — Ostale uslužne djelatnosti',
  ),
  ActivitySectorDef(
    code: 'nace_t',
    label: 'T — Djelatnosti domaćinstava kao poslodavaca; proizv. za vlastitu potr.',
  ),
  ActivitySectorDef(
    code: 'nace_u',
    label: 'U — Djelatnosti eksteritorijalnih organizacija',
  ),
  // Češće grane unutar prerađivačke industrije (C)
  ActivitySectorDef(
    code: 'nace_c10',
    label: 'C10 — Proizvodnja prehrambenih proizvoda',
  ),
  ActivitySectorDef(
    code: 'nace_c13',
    label: 'C13 — Proizvodnja tekstila',
  ),
  ActivitySectorDef(
    code: 'nace_c14',
    label: 'C14 — Proizvodnja odjeće',
  ),
  ActivitySectorDef(
    code: 'nace_c20',
    label: 'C20 — Proizvodnja kemikalija i hemijskih proizvoda',
  ),
  ActivitySectorDef(
    code: 'nace_c22',
    label: 'C22 — Proizvodnja gumenskih i plastičnih proizvoda',
  ),
  ActivitySectorDef(
    code: 'nace_c24',
    label: 'C24 — Proizvodnja metala osim željeza i čelika',
  ),
  ActivitySectorDef(
    code: 'nace_c25',
    label: 'C25 — Proizvodnja metala, osim strojeva i opreme',
  ),
  ActivitySectorDef(
    code: 'nace_c26',
    label: 'C26 — Proizvodnja računarske, elektronske i optičke opreme',
  ),
  ActivitySectorDef(
    code: 'nace_c27',
    label: 'C27 — Proizvodnja električne opreme',
  ),
  ActivitySectorDef(
    code: 'nace_c28',
    label: 'C28 — Proizvodnja ostalih strojeva i aparata',
  ),
  ActivitySectorDef(
    code: 'nace_c29',
    label: 'C29 — Proizvodnja motornih vozila, prikolica i poluprikolica',
  ),
  ActivitySectorDef(
    code: 'nace_c30',
    label: 'C30 — Proizvodnja ostalih transportnih sredstava',
  ),
  ActivitySectorDef(
    code: 'nace_c31',
    label: 'C31 — Proizvodnja namještaja',
  ),
  ActivitySectorDef(
    code: 'nace_c32',
    label: 'C32 — Ostala proizvodnja',
  ),
  ActivitySectorDef(
    code: 'nace_c33',
    label: 'C33 — Popravak i ugradnja strojeva i opreme',
  ),
  ActivitySectorDef(
    code: 'logistics_3pl',
    label: 'Logistika / 3PL / skladištenje (usluga)',
  ),
  ActivitySectorDef(
    code: 'packaging_supplier',
    label: 'Ambalaža i materijali za pakovanje',
  ),
  ActivitySectorDef(
    code: 'tooling_service',
    label: 'Alati, kalupi, opravka (alatnica)',
  ),
  ActivitySectorDef(
    code: 'it_software',
    label: 'IT / softver / integracije',
  ),
  ActivitySectorDef(
    code: 'consulting_qms',
    label: 'Konsalting (kvalitet, IATF, ISO, sistemi)',
  ),
  ActivitySectorDef(
    code: 'other',
    label: 'Ostalo (nije pokriveno gore)',
  ),
];

/// Prikaz u listama i filterima.
String activitySectorLabel(String? stored) {
  final t = (stored ?? '').trim();
  if (t.isEmpty) return '';
  for (final e in kActivitySectorCatalog) {
    if (e.code == t) return e.label;
  }
  return t;
}

/// `null` ako nije poznat kod (npr. stari slobodan unos).
ActivitySectorDef? activitySectorDefForCode(String? stored) {
  final t = (stored ?? '').trim();
  if (t.isEmpty) return null;
  for (final e in kActivitySectorCatalog) {
    if (e.code == t) return e;
  }
  return null;
}

bool activitySectorIsKnownCode(String? stored) =>
    activitySectorDefForCode(stored) != null;
