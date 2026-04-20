import 'package:flutter/material.dart';

/// Kratka IATF-usklađena objašnjenja (hr) za QMS modul.
abstract final class QmsIatfStrings {
  static const hubModule = 'QMS (Quality Management System) u smislu IATF 16949: '
      'strukturirano upravljanje kvalitetom kroz planiranje, kontrolu, nesklade i korektivne akcije. '
      'Lanac u aplikaciji: kontrolni plan → plan inspekcije → evidencija rezultata → NCR (reakcijski plan) → CAPA (akcijski plan) → sljedljivost. '
      'PFMEA i ocjene rizika u pozadini podržavaju prioritete; vidi ekran „Metodologija · IATF”.';

  /// Kratak uvod za ekran [QmsMethodologyReferenceScreen].
  static const methodologyWhy = 'Ovaj pregled povezuje četiri često miješana pojma: što je na NCR-u brzo, '
      'što je u CAPA-i trajno, što je PFMEA prije nego što se problem dogodi, i gdje su „ocjene rizika” u sustavu.';

  static const methodologyOverview = '1) PFMEA (procesna FMEA) procjenjuje moguća otkazivanja i posljedice procesa '
      '(S, O, D → RPN; AP = prioritet akcije). Utječe na to što kontroliramo u kontrolnom planu i inspekcijama.\n\n'
      '2) Ocjene rizika u sustavu agregiraju procjene po entitetima (npr. proizvod, stroj, partner) u jedinstveni motor — '
      'vidljive su razine rizika i gdje postoji RPN.\n\n'
      '3) Reakcijski plan na NCR-u je kratkoročan odgovor (što odmah radimo); containment je izolacija nesklada.\n\n'
      '4) Akcijski plan (CAPA) uklanja uzrok trajno (8D, Ishikawa, verifikacija) — nije isto što reakcijski plan ni PFMEA red.';

  static const termActionPlan = 'Akcijski plan: u smislu IATF-a strukturirani niz koraka za uklanjanje uzroka nesklada '
      '(root cause, trajna korekcija, verifikacija učinkovitosti). U aplikaciji to je CAPA zapis (action_plan). '
      'Razlikuje se od reakcijskog plana na NCR-u, koji je brzi odgovor u kratkom roku.';

  static const termPfmea = 'PFMEA (Process Failure Mode and Effects Analysis): metodologija za identifikaciju mogućih '
      'grešaka procesa, njihovih učinaka i uzroka prije nego se dogode. Tipična polja: težina (S), učestalost (O), '
      'otkrivanje (D), RPN = S×O×D, te AP (Action Priority) za rangiranje mjera. Kontrolni plan i inspekcije provode odabrane kontrole iz PFMEA konteksta.\n\n'
      'U ovom projektu postoje dva konteksta: PFMEA na stroju (Maintenance app, polje risk na imovini) i — za automotive QMS bez Maintenance modula — '
      'predviđena zasebna PFMEA po proizvodu/procesu unutar Production QMS-a (isti tenant, Callable).';

  /// Strategija kad kompanija ima samo Production; ne ovisi o Maintenance aplikaciji.
  static const methodologyProductionOnlyPfmea =
      'Maintenance aplikacija sadrži PFMEA vezan uz imovinu (stroj) i pripadajuće ekrane. '
      'Production aplikacija ih ne uključuje: ako kompanija nema Maintenance pretplatu, ne može „otvoriti” taj dio sustava.\n\n'
      'Za puni PFMEA u scenariju samo Production potrebna je implementacija u QMS modulu ove aplikacije: '
      'master podaci PFMEA redova po proizvodu ili procesu (companyId, opcionalno plantKey, veza na proizvod iz kontrolnog plana), '
      'čitanje i zapis isključivo preko Cloud Functions (Callable), kao i za kontrolne planove — tanki Firestore, jak backend.\n\n'
      'Dijeljenje koda s Maintenance-om moguće je izdvajanjem zajedničkih widgeta (S/O/D, RPN, AP) u zajednički paket; '
      'model podataka ipak treba prilagoditi (stroj vs proizvod/proces).';

  static const termRiskRatings = 'Ocjene rizika: u sustavu se procjene (npr. kolekcija risk_assessments u jedinstvenom motoru) povezuju s entitetima '
      'i izračunom razine rizika te po potrebi maksimalnim RPN-om. Služe za IATF trag i odluke (što prvo riješiti). '
      'Kad postoji samo Production modul, isti motor može se hraniti iz QMS PFMEA Callable-a (proizvod/proces), ne samo iz Maintenance imovine.';

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
      'LOT, proizvodni nalog te opcionalno ID kupca/dobavljača osiguravaju sljedljivost i segment. '
      'Rezultat može automatski otvoriti NCR pri NOK.';

  static const listNcr = 'NCR: evidencija nesklada (IATF 10.2). Statusi vode životni ciklus od otvaranja do zatvaranja; '
      'prilozi pri zatvaranju služe kao dokaz (evidence).';

  static const detailNcr = 'NCR: opis nesklada, ozbiljnost, containment, reakcijski plan (brzi odgovor), '
      'prilozi (https). Prijelaz u Pregled/Contained može automatski otvoriti CAPA. Zatvoreno/Odbačeno zahtijeva prilog.';

  static const listCapa = 'CAPA (akcijski plan): korektivne i preventivne akcije za uklanjanje uzroka nesklada; '
      'praćenje statusa, uzroka, akcija i verifikacije. Razlikuj od reakcijskog plana na NCR-u i od PFMEA-e.';

  static const detailCapa = 'CAPA je akcijski plan: root cause (uzrok), plan trajnih akcija, odgovorna osoba, rok, verifikacija učinkovitosti. '
      'U sklopu zapisa mogu se ispuniti 8D disciplina i Ishikawa (riblja kost). Status vodi od otvaranja do zatvaranja uz audit trag. '
      'Ne miješati s reakcijskim planom na NCR-u (brzi odgovor) niti s PFMEA retkom (preventivno prije nesklada).';

  static const claimCustomer = 'Reklamacija kupca: NCR s izvorom CUSTOMER, vezan uz kupca iz master podataka (customers). '
      'IATF 10.2 — nesklad izvan tvornice (npr. pritužba kupca); dalje isti CAPA tok kao za interni NCR.';

  static const claimSupplier = 'Reklamacija / prigovor prema dobavljaču: NCR s izvorom SUPPLIER, vezan uz dobavljača (suppliers). '
      'Tipično SCAR ili 8D s vanjske strane; u aplikaciji je evidencija i CAPA prema internom procesu.';

  static const capaEightD = '8D disciplina: strukturirano rješavanje problema (tim, opis, privremene mjere, uzrok, trajna korekcija, '
      'implementacija, prevencija, priznanje). Polja su vezana uz CAPA zapis za audit trag.';

  static const capaIshikawa = 'Ishikawa (riblja kost): analiza uzroka po kategorijama (6M + okolina). Svaki red u polju je jedan potencijalni uzrok; '
      'D4 u 8D može se nadopuniti ovim alatom.';

  static const termApqp = 'APQP (Advanced Product Quality Planning): strukturirano planiranje kvaliteta proizvoda; '
      'kontrolni plan je tipičan izlaz te faze.';

  static const termInspectionType = 'INCOMING — kontrola ulazne robe; IN_PROCESS — tijekom proizvodnje; '
      'FINAL — završna prije otpreme ili prije predaje.';

  static const termCharacteristicRefs = 'Ref u obliku operacija:indeks (npr. 1:2) pokazuje na stavku u kontrolnom planu. '
      'Prazan popis znači da se pri izvršenju uzimaju sve karakteristike iz plana.';

  static const termContainment = 'Containment: brza izolacija ili zaštita od daljnje isporuke ili uporabe nesklada '
      '(privremena mjera dok se ne riješi uzrok).';

  static const termReactionPlan = 'Reakcijski plan (brzi odgovor): što radimo odmah u kratkom roku (npr. sortiranje, '
      'zadržavanje, obavijest kupcu) — odvojeno od containmenta i od trajnog korektivnog plana (CAPA).';

  static const termPartnerIdsInspection = 'ID kupca / dobavljača (opcionalno): ako su uneseni, šalju se uz rezultat '
      'inspekcije i na automatski NCR pri NOK — korisno za segment i reklamacije.';

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
