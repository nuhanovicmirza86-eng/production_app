import 'package:flutter/material.dart';

void showWorkCenterHelpDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Zatvori'),
        ),
      ],
    ),
  );
}

/// Tekstovi za info dijaloge na ekranima radnih centara.
/// Normativ / kontekst: `maintenance_app/docs/architecture/archive/2026-04-24_MES_WORK_CENTERS_MASTER_DATA.md`.
class WorkCenterHelpTexts {
  WorkCenterHelpTexts._();

  static const basicDataTitle = 'Osnovni podaci';
  static const basicDataBody =
      'Tip određuje klasu mjesta rada (stroj, linija, pakovanje, kontrola …). '
      'Status je trenutno operativno stanje (u radu, miruje, održavanje …). '
      'Pogon je vezan uz `plantKey` u okviru kompanije — osnova za ispravne upite i kapacitet.';

  static const capacityResourcesTitle = 'Kapacitet i resursi';
  static const capacityResourcesBody =
      'Kapacitet u kom/h je nominalni ili planirani protok pod standardnim uslovima. '
      'Standardni ciklus (s) je referentno vrijeme po jedinici za tipičnu operaciju — koristi se za '
      'performans i usporedbe. Broj operatera opisuje koliko ljudi tipično treba za rad centra '
      '(posebno važno za ručne stanice).';

  static const oeeBlockTitle = 'OEE, OOE i TEEP';
  static const oeeBlockBody =
      'OEE (Overall Equipment Effectiveness) fokusira se na usko grlo stroja/linije. '
      'OOE širi pogled na organizacijske i operativne gubitke. TEEP uključuje kalendar '
      '(smjene, planirane zaustave) u odnosu na puni kalendar. Zastavice označavaju '
      'u koje agregate ovaj centar ulazi u izvještajima.';

  static const overviewTitle = 'Radni centri u MES-u';
  static const overviewBody =
      'Radni centar je mjesto gdje se u proizvodnji stvarno izvršava operacija: '
      'može biti stroj, linija, ćelija, ručna ili montažna stanica, pakovanje, '
      'kontrola ili eksterni korak. Šifrarnik radnih centara povezuje planiranje, '
      'kapacitet, izvršenje, sljedljivost i kasnije agregate (npr. OEE / OOE / TEEP). '
      'To nije zamjena za šifrarnik uređaja (assets): asset je tehnički objekat, '
      'radni centar je operativni MES koncept — često su povezani, ali uloga im je drugačija.';

  static const plantTitle = 'Pogon (plantKey)';
  static const plantBody =
      'Svaki zapis je vezan uz jednu kompaniju (`companyId`) i jedan pogon (`plantKey`). '
      'To osigurava multi-tenant izolaciju i ispravan kontekst kapaciteta. '
      'Lista i upiti uvijek filtriraju po pogonu koji odgovara vašoj sesiji ili izboru u filteru.';

  static const listCardTitle = 'Šta kartica prikazuje';
  static const listCardBody =
      'Red „šifra | naziv“ je brzi identifikator u planiranju i na podu. Tip i status '
      'opisuju vrstu mjesta rada i trenutno stanje. Kapacitet (kom/h) i ciklus (s) su referentne '
      'vrijednosti za plan i performans. „OEE relevantan“ govori uključuje li se centar u klasične '
      'OEE agregate. Pogon je `plantKey` u kontekstu kompanije.';

  static const filtersTitle = 'Filteri na listi';
  static const filtersBody =
      'Status i tip opisuju operativno stanje odnosno vrstu mjesta rada. '
      '„OEE relevantan“ označava da se ovaj centar uključuje u klasične OEE proračune '
      '(dostupnost × performans × kvalitet na uskom grlu). '
      '„Aktivan u šifrarniku“ je master-data zastavica: neaktivan centar se ne bi trebao '
      'birati za nove planove, ali ostaje u historiji.';

  static const codeTitle = 'Šifra radnog centra';
  static const codeBody =
      'Jedinstvena šifra unutar istog pogona (npr. RC-001, CNC-01). '
      'Koristi se u izvještajima, routing-u i na ekranima umjesto internog ID-a.';

  static const nameTitle = 'Naziv';
  static const nameBody =
      'Ljudski čitljiv naziv (npr. „CNC 01“, „Linija pakovanja A“). '
      'Prikazuje se operatorima i u planiranju.';

  static const typeTitle = 'Tip radnog centra';
  static const typeBody =
      'Klasa mjesta rada: mašina, linija, montaža, pakovanje, kontrola, ručni centar ili eksterni proces. '
      'Tip pomaže pravilima planiranja i kasnijim izvještajima po kategoriji resursa.';

  static const statusTitle = 'Status radnog centra';
  static const statusBody =
      'Operativno stanje mjesta: u radu, miruje, održavanje ili van pogona. '
      'Razlikuje se od polja „aktivan u šifrarniku“: status je dnevno/operativno, '
      'aktivan/neaktivan je trajni master-data životni ciklus zapisa.';

  static const locationTitle = 'Lokacija / zona';
  static const locationBody =
      'Gdje se centar nalazi u pogonskoj hijerarhiji (hala, zona, linija). '
      'Olakšava navigaciju na terenu i filtriranje u izvještajima.';

  static const capacityTitle = 'Kapacitet (kom/h)';
  static const capacityBody =
      'Planirani ili nominalni protok u komadima na sat za tipične uslove. '
      'Koristi se za planiranje opterećenja i usporedbu s ostvarenjem; '
      'nije zamjena za detaljno vremensko planiranje svake operacije.';

  static const cycleTitle = 'Standardni ciklus (sekunde)';
  static const cycleBody =
      'Očekivano vrijeme po jedinici (npr. po komadu) u sekundama za referentu operaciju. '
      'Služi kao referenca za performans i OOE; stvarni ciklus može varirati po proizvodu.';

  static const operatorsTitle = 'Broj operatera';
  static const operatorsBody =
      'Tipičan broj ljudi potrebnih za rad centra u standardnom režimu. '
      'Bitno za planiranje smjena i kapaciteta rada, posebno kod ručnih stanica.';

  static const assetTitle = 'Povezana mašina / linija (asset)';
  static const assetBody =
      'Opcionalna veza na dokument u šifrarniku `assets` (isti tenant i pogon). '
      'Asset nosi tehničke podatke o uređaju; radni centar nosi MES logiku (šifra, tip, kapacitet, OEE zastavice). '
      'Jedan asset može biti referenca više radnih centara samo ako poslovno ima smisla.';

  static const oeeFlagTitle = 'OEE relevantan';
  static const oeeFlagBody =
      'Ako je uključeno, ovaj centar ulazi u skup za klasični OEE (Availability × Performance × Quality). '
      'Isključite za pomoćne ili ne-uska-grla resurse da izvještaji ostanu smisleni.';

  static const ooeFlagTitle = 'OOE relevantan';
  static const ooeFlagBody =
      'OOE (Overall Operations Effectiveness) širi pogled na cjelokupne operativne gubitke '
      '(uključuje i organizacijske gubitke, ne samo stroj). '
      'Označava da se događaji i agregati za ovaj centar vode u OOE modelu aplikacije.';

  static const teepFlagTitle = 'TEEP relevantan';
  static const teepFlagBody =
      'TEEP uključuje i kalendar vrijeme (npr. smjene, planirane zaustave) u odnosu na potpuni kalendar. '
      'Koristi se za kapacitet i iskorištenje na razini pogona; označite centre koji sudjeluju u tom proračunu.';

  static const activeTitle = 'Aktivan u šifrarniku';
  static const activeBody =
      'Neaktivan zapis ostaje u bazi radi historije i integriteta, ali se ne bi smio birati za nove naloge ili planove. '
      'Za brzo „isključivanje“ bez brisanja koristite deaktivaciju.';

  static const deactivateTitle = 'Deaktivacija';
  static const deactivateBody =
      'Postavlja zapis kao neaktivan i tipično miruje status. '
      'Ne briše se dokument — održava se audit trag i veze u historiji.';

  static const auditTitle = 'Audit polja';
  static const auditBody =
      'Tko je kreirao ili zadnji izmijenio zapis i kada. '
      'Usklađeno s IATF očekivanjima da se promjene master-data zapisa mogu pratiti.';

  static const extensionsTitle = 'Proširenja (routing, nalozi, MES događaji)';
  static const extensionsBody =
      'Proizvodni nalog sada može imati workCenterId / šifru / naziv; izvršenje nasljeđuje te podatke. '
      'Na ovom ekranu vidite nedavne naloge dodijeljene centru. Routing po operacijama, agregirani zastoji, '
      'škart i performanse po smjenama bit će dodani kad događaji budu konzistentno vezani uz workCenterId.';
}

/// Mala info ikona koja otvara [AlertDialog] s objašnjenjem.
class WorkCenterInfoIcon extends StatelessWidget {
  final String title;
  final String message;

  const WorkCenterInfoIcon({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline, size: 22),
      tooltip: title,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      onPressed: () =>
          showWorkCenterHelpDialog(context, title: title, message: message),
    );
  }
}
