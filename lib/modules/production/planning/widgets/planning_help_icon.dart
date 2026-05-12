import 'package:flutter/material.dart';

/// Ikona pomoći: kratki [tooltip] (ili [title]) i puni tekst u dijalogu na dodir.
class PlanningHelpIcon extends StatelessWidget {
  const PlanningHelpIcon({
    super.key,
    required this.title,
    required this.message,
    this.size = 20,
    this.tooltip,
    this.dense = false,
    this.icon = Icons.info_outlined,
  });

  final String title;
  final String message;
  final double size;
  final String? tooltip;
  final bool dense;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tip = tooltip ?? title;
    final iconSize = dense ? (size * 0.85).clamp(14.0, 18.0) : size;
    return IconButton(
      icon: Icon(icon, size: iconSize),
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: dense ? 26 : 32,
        minHeight: dense ? 26 : 32,
      ),
      padding: EdgeInsets.zero,
      tooltip: tip,
      style: IconButton.styleFrom(foregroundColor: t.colorScheme.primary),
      onPressed: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: SelectableText(
                message,
                style: Theme.of(ctx).textTheme.bodyMedium,
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

/// Tekstovi pomoći za planiranje (jedan jezik u UI-ju, bez miješanja EN).
abstract final class PlanningHelpTexts {
  static const workflowTitle = 'Kako planirati proizvodnju';

  static const workflowMessage =
      'Planiranje ide u tri glavna koraka: odabir naloga, generiranje rasporeda, spremanje i puštanje.\n\n'
      '1) Tab Nalozi — učitavaju se proizvodni nalozi u statusima „Pušten” i „U toku”, isto kao na ekranu Nalozi za taj pogon. '
      'Kvačicom označite koje naloge motor uključuje u sljedeće generiranje. Gumbi „Sve”, „+ filtrirane” i „Očisti odabir” '
      'odgovaraju odabiru; filtri s desne strane samo sužavaju prikaz.\n\n'
      '2) Zaglavlje — Horizont (d) je duljina razdoblja u danima za koje se traži raspored od današnjeg dana. '
      'Prikaz vremena (smjena / dan / tjedan) postavlja kontekst prikaza za buduću vezu s MES prikazima. '
      'Scenarij (nacrt, simulacija, potvrđeno) označava namjeru rada; opcija „U produkciji” dolazi kasnije uz užu integraciju.\n\n'
      '3) Generiši plan i Preračunaj pokreću isti rasporedni motor (FCS) nad odabranim nalozima i parametrima s taba Nalozi. '
      'Nakon uspjeha otvorite tab Raspored za Gantt. Simuliraj postavlja scenarij simulacije — zatim ponovo pokrenite generiranje za „što ako”.\n\n'
      '4) Spremi nacrt i Gantt nalaze se u desnoj traci (na užem ekranu u ladici „Kontekst / KPI”). '
      'Otpusti plan (detalji) vodi na ekran detalja kad postoji spremljen nacrt u sesiji.\n\n'
      '5) Tab Provedba uspoređuje plan i MES; Kapacitet povezuje plan s pregledima opterećenja; Scenariji čuva varijante (baseline / what-if).';

  static const horizonTitle = 'Horizont (dani)';

  static const horizonMessage =
      'Broj kalendarskih dana plana od početka „danas” do kraja horizonta. Motor u tom razdoblju pokušava smjestiti odabrane naloge. '
      'Kraći horizont brži je za pregled; dulji pokriva više redoslijeda, ali može biti teži za sve naloge odjednom.';

  static const timeScopeTitle = 'Prikaz vremena';

  static const timeScopeMessage =
      'Odabir smjene, dana ili tjedna zadan je za usklađivanje s načinom čitanja rasporeda na tvorničkom terenu i budućim MES prikazima. '
      'Ne mijenja sama matematiku motora u ovoj verziji; služi kontekstu prikaza i slaganju s radnim smjenama.';

  static const scenarioTitle = 'Scenarij';

  static const scenarioMessage =
      'Nacrt — radna verzija plana prije odluke. Simulacija — isti motor, poslovno označava „što ako” bez obveze kao potvrđen plan. '
      'Potvrđeno — oznaka namjere kad plan prihvaćate operativno. „U produkciji” bit će aktivno kad postoji kontinuirana veza s MES-om u realnom vremenu.';

  static const headerActionsTitle = 'Gumbi u zaglavlju';

  static const headerActionsMessage =
      'Generiši plan — pokreće raspored nad odabranim nalozima (mora biti barem jedan).\n\n'
      'Preračunaj — ponovno pokreće isti motor s istim pravilima; korisno nakon izmjene parametara ili odabira.\n\n'
      'Simuliraj — postavlja scenarij „Simulacija”; zatim kliknite Generiši plan ili Preračunaj da vidite rezultat.\n\n'
      'Otpusti plan (detalji) — otvara detalje spremljenog nacrta (nakon „Spremi nacrt” u kontekstu). Ako nacrt nije spremljen, gumb je onemogućen.';

  static const ordersPanelTitle = 'Nalozi za planiranje';

  static const ordersPanelMessage =
      'Lista učitava naloge u statusima „Pušten” i „U toku” za trenutačni pogon — isto što i ekran Nalozi prikazuje za te operativne statuse. '
      'Pretraživanje filtrira prikaz po šifri i proizvodu. '
      'Kvačicom uključujete nalog u sljedeće generiranje; iz izbornika u tablici možete isključiti nalog iz plana. '
      'Gornja granica po broju naloga po potezu određena je tehničkim ograničenjem motora (poruka ispod gumba). '
      'Prikaz tablice ili kartica pamti se za tvrtku i pogon.';

  static const filtersTitle = 'Filtri liste naloga';

  static const filtersMessage =
      'Filtri sužavaju koji se nalozi vide u listi; ne označavaju automatski sve naloge za plan. '
      'Rok — prikaz naloga čiji je traženi rok isporuke unutar N dana od sada. '
      'Stroj i segment (operacija) dolaze s podataka na nalogu. Poništi filtere vraća širok prikaz.';

  static const motorParamsTitle = 'Parametri motora';

  static const motorParamsMessage =
      'Strategija reda (EDD po roku, SPT po kraćem poslu) utječe na redoslijed u heuristici raspoređivača. '
      'Performansa (0–1) skalira efektivno iskorištenje vremena obrade. '
      'Setup u minutama i ciklus u sekundama po komadu koriste se kad nema dovoljno podataka iz routingsa — približno trajanje po nalogu.';

  static const precheckTitle = 'Pre-check (stalno)';

  static const precheckMessage =
      'Automatski pregled prije i nakon pokretanja: upozorenja o nedodijeljenom stroju, kratkim rokovima, nedostatku routingsa ili lota ulaza (IATF), '
      'te nakon planiranja eventualno o alatima i operaterima u zapisima operacija. To je pomoć, ne blokada — motor ipak možete pokrenuti.';

  static const kpiRowTitle = 'Sažetak brojki';

  static const kpiRowMessage =
      'Odabrano — broj naloga s kvačicom za plan. Mogući / Nemogući — procjena motora o izvedivosti u zadnjem potezu. '
      'Rizik (rok) — broj naloga s bliskim rokom. Gruba iskoristivost i zbir kašnjenja dolaze iz zadnjeg rezultata motora.';

  static const engineAfterRunTitle = 'Motor (nakon generiranja)';

  static const engineAfterRunMessage =
      'Sažetak konflikata i upozorenja iz zadnjeg pokretanja rasporednog motora. '
      'Za detalje i akcije (simulacija, FCS) koristite desnu traku „Kontekst / KPI”.';

  static const contextSidebarTitle = 'Kontekst / KPI';

  static const contextSidebarMessage =
      'Prikaz odabranog naloga s taba Nalozi, upozorenja motora s prijedlozima (npr. prebacivanje na simulaciju), KPI iz zadnjeg plana te gumbi za '
      'Gantt preko cijelog ekrana i Spremi nacrt u bazu. Na užem ekranu ovu traku otvara ikona bočne trake u AppBar-u; značenje ikona u traci vidi '
      'pomoć „?” pokraj osvježavanja.';

  static const scheduleTabTitle = 'Tab Raspored';

  static const scheduleTabMessage =
      'Gantt prikazuje operacije po stroju u vremenu. Preklapanja na istom stroju naglašena su u motoru i u legendi. '
      'Stvarno (MES) uključuje očitanja iz izvršenja kad su dostupna. Cijeli ekran ili nova ruta otvaraju isti sadržaj u većem pogledu. '
      'Ponovno uklopi (FCS) ponovno pokreće motor; ručna pomicanja blokova u nacrtu će se izgubiti ako ih ne spremite drugačije.';

  static const executionTabTitle = 'Tab Provedba';

  static const executionTabMessage =
      'Povezuje plan s operativnim slikom: KPI iz zadnjeg nacrta, usko grlo, preklapanja, smjenska tabla i varijance plana i stvarnog. '
      'Za detalje izvršenja koristite i operativne MES ekrane aplikacije.';

  static const capacityTabTitle = 'Tab Kapacitet';

  static const capacityTabMessage =
      'Poveznica između zadnjeg plana i modula OEE / OOE / TEEP: kalendar kapaciteta, TEEP analiza i hijerarhija pokazatelja. '
      'Koristite za uvid u opterećenje resursa uz plan.';

  static const scenariosTabTitle = 'Tab Scenariji';

  static const scenariosTabMessage =
      'Spremanje imenovanih scenarija (npr. baseline i what-if) s vezom na ID nacrta plana. '
      'Ne briše proizvodne naloge; služi dokumentiranju varijanti i usporedbi. Unos i pohrana idu kroz pozadinski servis (Callable).';

  static const appBarShortcutsTitle = 'Alatke u gornjoj traci';

  static const appBarShortcutsMessage =
      'Lista (ikona s crtama) — Spremljeni planovi: pregled planova u bazi za ovu tvrtku i pogon.\n\n'
      'Osvježi (ikona kružne strelice) — ponovo učitava naloge za planiranje (statusi „Pušten” i „U toku”, kao na ekranu Nalozi). '
      'Koristite nakon izmjena naloga u drugim ekranima ili ako učitavanje nije uspjelo.\n\n'
      'Ladica (ikona bočne trake) — samo na užem ekranu: otvara isti sadržaj kao desni stupac Kontekst / KPI (odabrani nalog, upozorenja, KPI, Gantt, Spremi nacrt).';
}
