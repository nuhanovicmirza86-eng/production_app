import 'package:flutter/material.dart';

/// Kratka objašnjenja za P3 raspored po resursima (ⓘ). Tehnički Gantt u kodu/dokumentaciji.
abstract final class ApsGanttInfoCopy {
  static const draftPlannedTitle = 'Nacrt plana';

  static const draftPlannedBody =
      'Sistem je predložio termin u okviru početnog rasporeda; plan još nije '
      'potvrđen niti poslan u proizvodnju.';

  static const screenTitle = 'Raspored po resursima';

  static const screenSubtitle = 'Samo za pregled';

  static const hubSectionSubtitle = 'Napredno planiranje';

  static const hubScheduleTileTitle = 'Raspored po resursima';

  static const hubScheduleTileSubtitle =
      'Vizuelni prikaz plana po resursima i vremenu. Potvrda plana i pilotsko '
      'slanje u MES su odvojeni koraci.';

  /// Opšti naziv AI asistenta na razini Operonix platforme.
  static const aiAssistantProductName = 'Operonix AI Asistent';

  /// Naziv AI asistenta u modulu Napredno planiranje / APS (P6).
  static const aiApsAssistantModuleName = 'Operonix AI APS Asistent';

  static const aiApsAssistantHubTileSubtitle =
      'Prati izvršenje plana, prepoznaje rizike, upozorava i predlaže sljedeće korake.';

  static const aiApsAssistantDescription =
      'Operonix AI APS Asistent prati izvršenje plana, prepoznaje rizike, '
      'upozorava korisnika i predlaže sljedeće korake. Ne mijenja raspored i '
      'ne šalje plan u MES bez potvrde korisnika.';

  static const openScheduleButtonLabel = 'Otvori raspored';

  static const hubModuleInfoBody =
      'Ulaz u modul Napredno planiranje. Odavde birate korak u lancu: '
      'pripremu scenarija, provjeru kapaciteta, optimizaciju ili pregled rasporeda. '
      'Svaka kartica ima vlastito objašnjenje (ⓘ) — pročitajte ga prije ulaska u ekran.';

  static const hubScenariosDemandsCardInfoBody =
      'Šta ova kartica radi:\n'
      'Kreirate potražnje i scenarije planiranja, povezujete potražnje sa scenarijem, '
      'postavljate cilj optimizacije i generirate početni raspored.\n\n'
      'Kada je koristiti:\n'
      'Na početku planiranja i kad mijenjate sastav potražnji, period ili cilj scenarija.\n\n'
      'Cilj ekrana:\n'
      'Pripremiti valjan scenarij s početnim rasporedom spremnim za kapacitete, '
      'optimizaciju i pregled.\n\n'
      'Šta očekivati:\n'
      'Sastav scenarija (dodavanje potražnji) moguć je samo dok je scenarij u statusu Nacrt. '
      'Generisanje rasporeda zamjenjuje prethodni nacrt za taj scenarij. Plan se ne šalje u MES '
      's ovog ekrana.';

  static const hubCapacityCardInfoBody =
      'Šta ova kartica radi:\n'
      'Pokreće grubu procjenu kapaciteta (rough capacity) za odabrani scenarij i prikazuje '
      'opterećenje resursa te upozorenja.\n\n'
      'Kada je koristiti:\n'
      'Nakon što scenarij ima povezane potražnje, prije ili nakon generisanja početnog rasporeda — '
      'da provjerite ima li dovoljno kapaciteta.\n\n'
      'Cilj ekrana:\n'
      'Rano otkriti uska grla i nedostatke u podacima (kalendar, trajanje, rokovi) prije '
      'daljnjih odluka o planu.\n\n'
      'Šta očekivati:\n'
      'Rezultat je procjena, ne konačan operativni raspored. Upozorenja objašnjavaju problem '
      'poslovnim jezikom; proračun možete ponoviti nakon izmjene scenarija.';

  static const hubOptimizationCardInfoBody =
      'Šta ova kartica radi:\n'
      'Pokreće prijedlog optimiziranog rasporeda, prikazuje usporedbu s početnim rasporedom '
      'i omogućava primjenu ili odbacivanje prijedloga.\n\n'
      'Kada je koristiti:\n'
      'Kad scenarij ima generiran početni raspored, postavljen cilj optimizacije i želite '
      'pregledati alternativni prijedlog prije potvrde plana.\n\n'
      'Cilj ekrana:\n'
      'Dati planeru kontrolisan korak između početnog rasporeda i aktivnog plana — uz '
      'eksplicitnu odluku, bez automatskog prepisivanja.\n\n'
      'Šta očekivati:\n'
      'Prijedlog se ne primjenjuje sam. Nakon primjene otvorite Raspored po resursima za pregled. '
      'Slanje u MES nije dio ovog ekrana.';

  static const hubScheduleCardInfoBody =
      'Šta ova kartica radi:\n'
      'Prikazuje raspored po resursima i vremenu (Gantt) za odabrani scenarij — samo za pregled.\n\n'
      'Kada je koristiti:\n'
      'Nakon generisanja ili primjene rasporeda, prije potvrde plana i pilotskog slanja u MES.\n\n'
      'Cilj ekrana:\n'
      'Vizuelno provjeriti raspored po resursima i donijeti odluku o potvrdi plana ili '
      'pilot releaseu.\n\n'
      'Šta očekivati:\n'
      'Prikaz je read-only — ne pomičete operacije ovdje. Potvrdi plan i Pošalji u MES (pilot) '
      'su odvojeni koraci u donjoj traci, uz ljudsku potvrdu.';

  static const hubAiCardInfoBody =
      'Šta ova kartica radi:\n'
      '$aiApsAssistantDescription\n\n'
      'Kada je koristiti:\n'
      'Nakon potvrde plana i slanja u MES (pilot), te tijekom izvršenja — kad trebate '
      'nadzor plana naspram stvarnosti (zastoji, kašnjenja, smjene, materijal).\n\n'
      'Cilj ekrana:\n'
      'Nadzorni sloj uz postojeći APS tok — upozorenja, utjecaj na plan i prijedlozi '
      'sljedećih koraka. Dio proizvoda $aiAssistantProductName.\n\n'
      'Šta očekivati:\n'
      'Prikaz aktivnih rizika i prilika za izvršenje plana. Asistent ne mijenja raspored '
      'automatski niti šalje plan u MES — sve akcije zahtijevaju vašu potvrdu.';

  static const scenarioPickerScheduleInfoBody =
      'Odaberite scenarij čiji raspored želite pregledati. '
      'Period planiranja određuje vremensku liniju prikaza.';

  static const readOnlyHint =
      'Prikaz ne omogućava pomjeranje operacija. Potvrdu plana i pilotsko '
      'slanje u MES obavite kao zasebne korake u donjoj traci.';

  static const planConfirmDialogBody =
      'Potvrđujete početni raspored koji je sistem izračunao kao radni plan. '
      'Ovo ne šalje ništa u MES — pilot release dolazi kao sljedeći, odvojeni korak.';

  static const planConfirmSuccessPrefix = 'Plan je potvrđen —';

  static const emptyScheduleMessage =
      'Scenarij nema generiran raspored. Pokrenite generisanje početnog '
      'rasporeda za odabrani scenarij.';

  static const missingHorizonMessage =
      'Scenarij nema valjan period planiranja (početak i kraj).';

  static const missingPlantKeyMessage =
      'Nedostaje plantKey — unesite pogon u profilu ili odaberite pogon rada.';

  static const pilotValidationBadge = 'Pilot — kontrolisana validacija';

  static const pilotReleaseDialogBody =
      'Ovo je pilotsko slanje plana u MES — kontrolisana validacija, ne konačni '
      'proizvodni release. Planirani termini na proizvodnom nalogu upisuju se '
      'samo ako postoji sigurna veza s potražnjom.';

  static const pilotReleaseCheckboxLabel =
      'Razumijem da je ovo pilot validacija, a ne konačno slanje plana u pogon';

  static const pilotReleaseSuccessPrefix = 'Plan je poslan u MES (pilot) —';

  static const scenariosDemandsScreenTitle = 'Scenariji i potrebe';

  static const scenariosDemandsIntro =
      'Kreirajte potražnje i scenarije planiranja, povežite potražnje sa scenarijem, '
      'generirajte početni raspored i otvorite prikaz po resursima.';

  static const optimizationGoalLabel = 'Cilj optimizacije';

  static const optimizationGoalBalancedPlan = 'Balansiran plan';

  static const optimizationGoalMissingHint =
      'Scenarij nema cilj optimizacije. Postavite cilj prije optimizacije rasporeda.';

  static const optimizationGoalMissingForCreate =
      'Nema profila cilja optimizacije u pogonu. Kreirajte profil u APS master '
      'podacima (P0), zatim ponovite.';

  static const optimizationGoalSetAction = 'Postavi cilj optimizacije';

  static const optimizationStartRunInfoBody =
      'Pokreće izradu predloženog optimiziranog rasporeda iznad trenutnog početnog '
      'rasporeda. Rezultat morate pregledati i eksplicitno primijeniti ili odbaciti — '
      'plan se ne mijenja automatski.';

  static const optimizationApplyInfoBody =
      'Primjenjuje predloženi optimizirani raspored kao aktivni plan scenarija. '
      'Početni raspored ostaje u historiji. Ovo ne šalje plan u MES — potvrda plana '
      'i pilotsko slanje su odvojeni koraci.';

  static const pilotValidationInfoBody =
      'Oznaka pilotske validacije: plan je poslan u MES kao kontrolisani test, '
      'ne kao konačni proizvodni release. Operateri i MES koriste ga za provjeru '
      'termina i toka prije šireg uvođenja.';

  static const optimizationDiscardInfoBody =
      'Odbacuje predloženi optimizirani raspored. Aktivni plan scenarija ostaje '
      'početni raspored.';

  static const scenarioDraftCompositionHint =
      'Sastav scenarija (dodavanje/uklanjanje potražnji) moguć je samo dok je '
      'scenarij u statusu Nacrt.';

  static const generateScheduleConfirmBody =
      'Sistem će izračunati početni raspored po pravilima planiranja za odabrani '
      'scenarij. Postojeći nacrt rasporeda za taj scenarij bit će zamijenjen '
      'novim proračunom.';

  static const capacityScreenTitle = 'Kapaciteti';

  static const capacityIntro =
      'Gruba procjena kapaciteta (rough capacity) za odabrani scenarij planiranja. '
      'Pokrenite proračun da vidite opterećenje resursa i upozorenja.';

  static const capacityCalculateConfirmBody =
      'Pokreće se gruba procjena kapaciteta za odabrani scenarij. '
      'Rezultat uključuje opterećenje resursa i listu upozorenja.';

  static const capacityNoResourcesHint =
      'Nema prikaza opterećenja po resursima. Pokrenite proračun kapaciteta '
      'ili provjerite da scenarij ima povezane potražnje i aktivne resurse.';

  static const capacityNoWarningsHint = 'Nema upozorenja za zadnji proračun.';

  static const optimizationScreenTitle = 'Optimizacija';

  static const optimizationHubTileSubtitle =
      'Pokrenite prijedlog optimizacije, pregledajte usporedbu s početnim '
      'rasporedom i primijenite prijedlog prije potvrde plana.';

  static const optimizationOperationalIntro =
      'Odaberite scenarij s generiranim početnim rasporedom i ciljem optimizacije. '
      'Pokrenite prijedlog, pregledajte usporedbu i eksplicitno primijenite ili '
      'odbacite prijedlog prije sljedećih koraka u planiranju.';

  static const optimizationStartRunAction = 'Pokreni prijedlog optimizacije';

  static const optimizationRunListTitle = 'Prijedlozi optimizacije';

  static const optimizationRunDetailTitle = 'Detalj prijedloga';

  static const optimizationComparisonTitle = 'Usporedba rasporeda';

  static const optimizationBaselineLabel = 'Početni raspored';

  static const optimizationProposalLabel = 'Prijedlog';

  static const optimizationBaselineScoreLabel = 'Ciljna vrijednost (početni)';

  static const optimizationProposalScoreLabel = 'Ciljna vrijednost (prijedlog)';

  static const optimizationApplyAction = 'Primijeni prijedlog';

  static const optimizationDiscardAction = 'Odbaci prijedlog';

  static const optimizationApplyConfirmBody =
      'Primjenjujete predloženi optimizirani raspored kao aktivni plan scenarija. '
      'Početni raspored ostaje u historiji. Ovo ne šalje plan u MES — potvrda plana '
      'i pilotsko slanje su odvojeni koraci.';

  static const optimizationDiscardConfirmBody =
      'Odbacujete predloženi optimizirani raspored. Aktivni plan scenarija '
      'ostaje početni raspored.';

  static const optimizationScenarioNotEligibleHint =
      'Scenarij mora imati status Raspored generiran (ili revizija / potvrđen plan), '
      'generiran početni raspored i postavljen cilj optimizacije.';

  static const optimizationNoRunsHint =
      'Nema prijedloga optimizacije za odabrani scenarij. Pokrenite prvi prijedlog.';

  static const optimizationApplySuccessPrefix = 'Prijedlog je primijenjen —';

  static const optimizationDiscardSuccessPrefix = 'Prijedlog je odbačen —';

  static const optimizationIntroBody =
      'Ovdje će kasnije biti globalna optimizacija rasporeda iznad početnog '
      'rasporeda koji je sistem već izračunao. Pilot tok (scenariji, kapaciteti, '
      'početni raspored, potvrda i pilotsko slanje u MES) ostaje nepromijenjen '
      'dok se optimizacija ne uvede u produkciju.';

  static const optimizationPilotTodayTitle = 'Šta pilot već nudi';

  static const optimizationPilotTodayBody =
      'Početni raspored generirate u Scenariji i potrebe — sistem ga izračunava '
      'po pravilima planiranja. Kapaciteti daju grubu procjenu opterećenja. '
      'Raspored po resursima služi za pregled; Potvrdi plan i Pošalji u MES '
      '(pilot) su odvojeni koraci s ljudskom potvrdom.';

  static const optimizationPlannedTitle = 'Šta planiramo u optimizaciji';

  static const optimizationPlannedBody =
      'Napredni optimizacijski motor tražit će bolji raspored uz ograničenja '
      'planiranja, ciljne profile (rokovi, zauzetost, smjene) i usporedbu '
      'scenarija (what-if). Predloženi optimizirani raspored planer pregleda i '
      'potvrđuje prije slanja u proizvodnju — početni raspored ostaje u historiji.';

  static const optimizationNotAvailableTitle = 'Još nije u produkciji';

  static const optimizationNotAvailableBody =
      'Pokretanje optimizacije, automatsko prepisivanje plana i optimizacija u '
      'oblaku nisu dostupni u ovom pilotu kroz ovaj ekran. Ne mijenjajte '
      'operativni tok dok se P5 faza ne zatvori u backendu i entitlements modelu.';

  static const optimizationModuleHint =
      'Za punu optimizaciju bit će potreban dodatni SaaS modul Napredna optimizacija '
      'uz postojeće Napredno planiranje.';

  static String warningCodeLabel(String code) {
    switch (code.trim().toLowerCase()) {
      case 'insufficient_capacity':
        return 'Nedovoljan kapacitet';
      case 'missing_routing':
        return 'Nedostaje trajanje operacije';
      case 'missing_calendar':
        return 'Nedostaje radni kalendar';
      case 'missing_demand_data':
        return 'Nedostaju podaci potražnje';
      case 'no_finite_resources':
        return 'Nema resursa s ograničenim kapacitetom';
      case 'demand_due_outside_period':
        return 'Rok izvan perioda planiranja';
      default:
        return 'Upozorenje planiranja';
    }
  }

  /// Korisnički opis upozorenja kapaciteta — bez tehničkih ID-eva iz backenda.
  static String capacityWarningUserMessage({
    required String warningCode,
    required String backendMessage,
    String? demandLabel,
    String? resourceLabel,
  }) {
    final demand = _displayRef(
      demandLabel,
      _codeFromBackendMessage(backendMessage, prefix: 'Demand'),
    );
    final resource = _displayRef(
      resourceLabel,
      _codeFromBackendMessage(backendMessage, prefix: 'Resurs'),
    );

    switch (warningCode.trim().toLowerCase()) {
      case 'missing_calendar':
        final who = resource ?? 'Resurs';
        return '$who nema definisan radni kalendar. Za proračun je korišteno '
            '8 sati rada po radnom danu dok se kalendar ne dopuni.';
      case 'demand_due_outside_period':
        final who = demand ?? 'Potražnja';
        return 'Rok potrebe „$who” pada izvan perioda planiranja ovog scenarija '
            '(datum početka i kraja scenarija). Provjerite rok potrebe ili '
            'prilagodite period scenarija.';
      case 'missing_routing':
        final who = demand ?? 'Potražnja';
        return 'Potrebi „$who” nije dodijeljeno trajanje po komadu niti operacioni '
            'list. Za proračun je korištena pretpostavka od 60 minuta po komadu.';
      case 'insufficient_capacity':
        return 'Ukupna potražnja premašuje raspoloživo vrijeme resursa u periodu '
            'scenarija. Razmotrite smanjenje obima, produženje perioda ili dodatni kapacitet.';
      case 'no_finite_resources':
        return 'U pogonu nema aktivnih resursa s ograničenim kapacitetom za ovaj proračun. '
            'Provjerite šifrarnik resursa u Naprednom planiranju.';
      case 'missing_demand_data':
        final raw = backendMessage.toLowerCase();
        if (raw.contains('nije pronađen')) {
          return 'Jedna potražnja povezana sa scenarijem više ne postoji u šifrarniku.';
        }
        if (raw.contains('nije active') || raw.contains('preskočen')) {
          final who = demand ?? 'Potražnja';
          return 'Potreba „$who” nije aktivna i nije uračunata u proračun kapaciteta.';
        }
        final who = demand ?? 'Potražnja';
        return 'Podaci potrebe „$who” nisu potpuni ili količina nije ispravna.';
      default:
        return 'Provjerite podatke scenarija, potražnji i resursa, pa ponovite proračun.';
    }
  }

  static String? _displayRef(String? preferred, String? fallbackCode) {
    final p = preferred?.trim();
    if (p != null && p.isNotEmpty) return p;
    final f = fallbackCode?.trim();
    if (f != null && f.isNotEmpty) return f;
    return null;
  }

  static String? _codeFromBackendMessage(String message, {required String prefix}) {
    final pattern = RegExp('$prefix\\s+([^:]+)', caseSensitive: false);
    final match = pattern.firstMatch(message);
    return match?.group(1)?.trim();
  }

  static String scenarioStatusLabel(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'approved':
        return 'Plan potvrđen';
      case 'released_to_mes':
        return 'Poslano u MES (pilot)';
      case 'solved':
        return 'Raspored generiran';
      case 'calculated':
        return 'Kapacitet procijenjen';
      case 'review_required':
        return 'Potrebna revizija';
      case 'draft':
        return 'Nacrt';
      case 'planned':
        return 'Planirano';
      case 'firm_planned':
        return 'Čvrsto planirano';
      case 'draft_planned':
        return draftPlannedTitle;
      default:
        return rawStatus.trim().isEmpty ? '—' : rawStatus.trim();
    }
  }

  static String operationStatusLabel(String rawStatus) =>
      scenarioStatusLabel(rawStatus);
}

void showApsGanttInfoDialog(
  BuildContext context, {
  required String title,
  required String body,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxContentHeight = MediaQuery.sizeOf(ctx).height * 0.55;
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxContentHeight),
          child: SingleChildScrollView(
            child: Text(body),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      );
    },
  );
}
