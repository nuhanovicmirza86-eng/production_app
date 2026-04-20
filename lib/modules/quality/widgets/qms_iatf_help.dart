import 'package:flutter/material.dart';

/// Kratka IATF-usklađena objašnjenja (hr) za QMS modul.
abstract final class QmsIatfStrings {
  static const hubModule = 'QMS (Quality Management System) u smislu IATF 16949: '
      'strukturirano upravljanje kvalitetom kroz planiranje, kontrolu, nesklade i korektivne akcije. '
      'Lanac u aplikaciji: kontrolni plan → plan inspekcije → evidencija rezultata → NCR → CAPA → sljedljivost (LOT/nalog).';

  static const dashboard = 'Pregled brojeva u tvojoj kompaniji. '
      'Kontrolni planovi i planovi inspekcije su „master” definicije; NCR su zapisani neskladi; '
      'CAPA su korektivne/preventivne akcije vezane uz NCR. Podaci dolaze samo preko sigurnih Callable-a.';

  static const kpiControlPlans = 'Kontrolni plan (control plan): dokument koji za proizvod/proces '
      'definira koje karakteristike se kontroliraju, kako i na kojim operacijama (APQP/PPAP kontekst). '
      'To je izvor tolerancija za inspekcije.';

  static const kpiInspectionPlans = 'Plan inspekcije veže tip kontrole (ulazna, u procesu, završna) '
      'na podskup karakteristika iz kontrolnog plana (pokazivači ref, npr. 0:0).';

  static const kpiNcr = 'NCR (Non-Conformance Report): formalni zapis nesklada — što je otkriveno, '
      'ozbiljnost, status i privremene mjere (containment). Otvoreni su dok su u aktivnom rješavanju.';

  static const kpiCapa = 'CAPA (Corrective Action / Preventive Action): strukturirano rješavanje uzroka; '
      'u sustavu su zapisane kao action_plans s izvorom NCR. Praćen su status, rok i verifikacija.';

  static const listControlPlans = 'Lista kontrolnih planova po kompaniji. Uređivanje i čitanje '
      'master podataka ide preko poslužitelja (Callable), ne izravno iz klijenta — u skladu s tankim pravilima.';

  static const listInspectionPlans = 'Plan inspekcije određuje koji se dio kontrolnog plana provjerava '
      'za određeni tip kontrole (INCOMING / IN_PROCESS / FINAL).';

  static const editControlPlan = 'Kontrolni plan: operacije (redoslijed procesa) i karakteristike '
      '(dimenzija, tolerancije, jedinica). Indeksi 0:0, 1:0… koriste se u planu inspekcije kao ref.';

  static const editInspectionPlan = 'Plan inspekcije: povezuje proizvod i kontrolni plan s tipom inspekcije. '
      'characteristicRefs (npr. 0:0) određuju koje stavke kontrolnog plana ulaze u ovo izvršenje; prazno = sve.';

  static const executeInspection = 'Izvršenje inspekcije: unos izmjerenih vrijednosti uz plan; '
      'LOT i proizvodni nalog osiguravaju sljedljivost (traceability). Rezultat može automatski otvoriti NCR pri NOK.';

  static const listNcr = 'NCR: evidencija nesklada (IATF 10.2). Statusi vode životni ciklus od otvaranja do zatvaranja; '
      'prilozi pri zatvaranju služe kao dokaz (evidence).';

  static const detailNcr = 'NCR: opis nesklada, ozbiljnost, containment (privremena zaštita od isporuke nesklada), '
      'prilozi (https). Prijelaz u Pregled/Contained može automatski otvoriti CAPA. Zatvoreno/Odbačeno zahtijeva prilog.';

  static const listCapa = 'CAPA: korektivne i preventivne akcije za uklanjanje uzroka nesklada; '
      'praćenje statusa, uzroka, akcija i verifikacije.';

  static const detailCapa = 'CAPA: root cause (uzrok), plan akcija, odgovorna osoba, rok, verifikacija učinkovitosti. '
      'Status vodi od otvaranja do zatvaranja uz audit trag.';

  static const termApqp = 'APQP (Advanced Product Quality Planning): strukturirano planiranje kvaliteta proizvoda; '
      'kontrolni plan je tipičan izlaz te faze.';

  static const termInspectionType = 'INCOMING — kontrola ulazne robe; IN_PROCESS — tijekom proizvodnje; '
      'FINAL — završna prije otpreme ili prije predaje.';

  static const termCharacteristicRefs = 'Ref u obliku operacija:indeks (npr. 1:2) pokazuje na stavku u kontrolnom planu. '
      'Prazan popis znači da se pri izvršenju uzimaju sve karakteristike iz plana.';

  static const termContainment = 'Containment: brza izolacija ili zaštita od daljnje isporuke ili uporabe nesklada '
      '(privremena mjera dok se ne riješi uzrok).';

  static const termRootCause = 'Root cause: utvrđeni uzrok nesklada (ne simptom); osnova za trajnu korektivnu akciju.';

  static const termLot = 'LOT / serija: jedinica sljedljivosti u logistici i kvaliteti — koja je roba, kada i gdje proizvedena.';

  static const termQms = 'QMS: sustav upravljanja kvalitetom organizacije (IATF 16949 za automotive).';

  static const termTraceability = 'Sljedljivost: povezivanje rezultata kontrole s nalogom, LOT-om i planom — '
      'zahtjev IATF za identifikaciju i praćenje.';

  static const termSeverity = 'Ozbiljnost (severity): procjena utjecaja nesklada na proizvod, kupca ili sigurnost; '
      'pomaže prioritetima i eskalaciji.';

  static const termVerification = 'Verifikacija CAPA: dokaz da su akcije provedene i da je uzrok uklonjen '
      '(učinkovitost korekcije).';
}

/// Info ikona koja otvara dijalog s IATF objašnjenjem.
class QmsIatfInfoIcon extends StatelessWidget {
  const QmsIatfInfoIcon({
    super.key,
    required this.title,
    required this.message,
    this.size = 22,
  });

  final String title;
  final String message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(Icons.info_outline, size: size, color: cs.primary),
      tooltip: title,
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Text(
                message,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Zatvori'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Naslov sekcije + IATF info (za ListView/Column).
class QmsIatfSectionTitle extends StatelessWidget {
  const QmsIatfSectionTitle({
    super.key,
    required this.label,
    required this.iatfTitle,
    required this.iatfMessage,
    this.style,
  });

  final String label;
  final String iatfTitle;
  final String iatfMessage;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: style ?? Theme.of(context).textTheme.titleSmall,
          ),
        ),
        QmsIatfInfoIcon(title: iatfTitle, message: iatfMessage, size: 20),
      ],
    );
  }
}
