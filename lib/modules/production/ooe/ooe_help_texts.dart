/// Tekstovi za [OoeInfoIcon] — kratki tooltip + duži dijalog (nije UI stalno vidljiv).
abstract final class OoeHelpTexts {
  static const liveDashboardTooltip = 'Što je OOE live';
  static const liveDashboardTitle = 'OOE — live pregled';
  static const liveDashboardBody =
      'Prikazuje zadnji agregirani status po stroju za ovaj pogon '
      '(ooe_live_status). Naziv stroja dolazi iz imovine (assets) kad postoji '
      'podudaranje šifre; podaci dolaze iz izvršenja naloga i događaja stanja '
      '/ brojanja. Ažuriranje nije ručno ovdje — slijedi proizvodni modul. '
      '„Po liniji“ grupira strojeve prema liniji iz live zapisa (izvršenje) ili '
      'prema poljima linije na imovini (npr. productionLineId / productionLineName). '
      'Iznad liste možeš sortirati kartice po OOE (silazno) ili po nazivu/šifri '
      'stroja; unutar grupe vrijedi isto sortiranje.';

  static const shiftSummaryTooltip = 'Sažetak smjene i preračun';
  static const shiftSummaryTitle = 'Sažetak smjene (OOE)';
  static const shiftSummaryBody =
      'Biraš kalendarski dan i oznaku smjene (npr. DAY, NIGHT). Prozor događaja '
      'za agregat koristi planirani početak i kraj iz „Kontekst smjene“ ako su '
      'oba unesena; inače 06:00–22:00 na taj dan (zona Europe/Sarajevo, ista kao '
      'na serveru). Noćna smjena (kraj iza ponoći) radi preko vremena kraja na '
      'sljedeći dan.\n\n'
      'Sažetak se računa na serveru (Callable recomputeOoeShiftSummary) i sprema '
      'u ooe_shift_summaries. Neto operativno vrijeme za Availability dolazi iz '
      'konteksta smjene ako postoji; inače zadano na serveru.\n\n'
      'Performance (P): idealni ciklus s proizvoda ako uneseš productId ili '
      'orderId (nalog razrješuje proizvod).';

  static const dailyOverviewTooltip = 'Kako čitati dnevni pregled';
  static const dailyOverviewTitle = 'Dnevni pregled OOE';
  static const dailyOverviewBody =
      'Za odabrani kalendarski dan možeš gledati jedan stroj (šifra) ili '
      '„Sav pogon“ — tada se učitaju svi sažeci za taj dan u pogonu '
      '(ooe_shift_summaries). Isti kalendarski dan kao u „Sažetak smjene“. '
      'Ponderirani OOE množi OOE s operativnim vremenom po smjeni ili stroju, '
      'ovisno o prikazu. Pareto po smjeni kao na sažetku smjene.';

  static const lossAnalysisTooltip = 'Kako čitati Pareto';
  static const lossAnalysisTitle = 'Analiza gubitaka';
  static const lossAnalysisBody =
      'Zadnji segmenti stanja mašine grupirani su po kodu razloga ili stanju '
      '(što nije running). Trajanja u sekundama sumiraju se; Pareto prikazuje '
      'gdje je najviše „izgubljenog“ vremena. Ne uključuje sve historije — '
      'ograničen je na zadnje segmente u upitu.';

  static const machineDetailsOoeTooltip = 'Što znači ovaj OOE';
  static const machineDetailsOoeTitle = 'OOE na detalju mašine';
  static const machineDetailsOoeBody =
      'Isti brojevi kao na OOE live kartici za ovu mašinu (dokument '
      'ooe_live_status — A, P, Q i brojanje od ponoći za taj pogon). '
      'Performance i kvaliteta ovise o idealnom ciklusu proizvodu i događajima '
      'brojanja; ako kartica na početnom ekranu pokazuje podatke, ovdje ih '
      'vidiš u istom obliku.';

  static const machineDetailsApqTooltip = 'Availability, Performance, Quality';
  static const machineDetailsApqTitle = 'Faktori A · P · Q';
  static const machineDetailsApqBody =
      'A (Availability): udio vremena u radu u odnosu na operativno vrijeme.\n'
      'P (Performance): koliko brzo u odnosu na idealni ciklus.\n'
      'Q (Quality): udio dobrih komada u ukupnom broju.\n'
      'OOE = A × P × Q (svaki 0–1).';

  static const liveCardTagsTooltip = 'Označene vrijednosti na kartici';
  static const liveCardTagsTitle = 'OOE, A, P, Q na kartici';
  static const liveCardTagsBody =
      'OOE je trenutno agregirani pokazatelj za smjenu / kontekst koji '
      'sustav drži za tu mašinu. A, P i Q su komponente (Availability, '
      'Performance, Quality). Good / Scrap su zadnji poznati brojevi iz '
      'brojanja.';

  static const paretoTooltip = 'Pareto graf gubitaka';
  static const paretoTitle = 'Gubici po razlogu';
  static const paretoBody =
      'Vodoravne trake = relativni udio sekundi po razlogu u odnosu na '
      'najveći razlog u prikazanom uzorku. Kad postoji podudaranje s katalogom '
      'razloga gubitaka, prikazuje se naziv (šifra je manjim slovima ispod). '
      'Koristi se za brzo usmjeravanje gdje skratiti zastoje.';

  static const orderDetailsOoeTooltip = 'OOE uz proizvodni nalog';
  static const orderDetailsOoeTitle = 'Segmenti stanja i nalog';
  static const orderDetailsOoeBody =
      'Prikaz zadnjih segmenata stanja mašine povezanih s ovim nalogom '
      '(machine_state_events s orderId). Ako nema segmenata, izvršenje još '
      'nije zapisalo stanja ili machineId nije postavljen. Puni OOE (A×P×Q) '
      'vidi na OOE dashboardu i sažetku smjene.';

  static const timelineTooltip = 'Segmenti stanja';
  static const timelineTitle = 'Vremenska traka';
  static const timelineBody =
      'Zadnji segmenti machine_state_events za ovu mašinu — trajanje i stanje '
      'ili razlog. Služi za vizualni pregled tijeka; puni OOE za P/Q ide kroz '
      'idealni ciklus i brojanje na dashboardu / sažetku smjene.';

  static const teepHierarchyTooltip = 'Razlika OEE, OOE i TEEP';
  static const teepHierarchyTitle = 'Tri vremenske baze — jedan A×P×Q';
  static const teepHierarchyBody =
      'OEE mjeri efikasnost u planiranom vremenu proizvodnje. OOE u operativnom '
      'vremenu (smjene). TEEP u punom kalendarskom vremenu — koliki dio dana '
      'tjedna stvarno pretvaraš u dobru proizvodnju.\n\n'
      'U ovom projektu: Utilization = planirana proizvodnja / kalendar, '
      'TEEP = OEE × Utilization (ili ekvivalentno A×P×Q×Utilization uz Availability '
      'na sloju plana). Ne uspoređuj tri broja kao ista „efikasnost“ — kontekst '
      'baze vremena je obavezan.';

  static const capacityOverviewTooltip = 'Kalendarski kapacitet';
  static const capacityOverviewTitle = 'Pregled kapaciteta';
  static const capacityOverviewBody =
      'Lista dolazi iz capacity_calendars. Menadžer smije unijeti ili '
      'izmijeniti jedan dan (Callable na serveru — klijent ne piše '
      'direktno u Firestore). Prikazuje koliko sekundi u danu otpada na '
      'kalendar, operativno vrijeme i planiranu proizvodnju — osnova za TEEP.';

  static const teepAnalysisTooltip = 'TEEP trend i ranking';
  static const teepAnalysisTitle = 'TEEP analitika';
  static const teepAnalysisBody =
      'Sažeci iz teep_summaries: OEE, OOE i TEEP zajedno s iskorištenjem kalendara. '
      'Period može biti dan, ISO tjedan ili pun mjesec; opseg cijeli pogon, linija '
      '(filtar na lineId u sažetku smjene) ili jedan stroj. Za tjedan/mjesec treba '
      'capacity_calendars za svaki dan u tom periodu (ili jednokratni zbir sekundi u Callable).';

  static const teepKpiOeeTooltip = 'OEE u ovoj kartici';
  static const teepKpiOeeTitle = 'OEE (planirana proizvodnja)';
  static const teepKpiOeeBody =
      'OEE ovdje koristi planirano vrijeme proizvodnje kao referencu: '
      'Availability = rad / planirana proizvodnja, zatim OEE = A×P×Q. '
      'Isti P i Q kao u OOE; mijenja se samo baza vremena za A.';

  static const teepKpiOoeTooltip = 'OOE u ovoj kartici';
  static const teepKpiOoeTitle = 'OOE (operativno / smjene)';
  static const teepKpiOoeBody =
      'OOE agregat koristi operativno (smensko) vrijeme: rad u odnosu na to što '
      'je zakazano za pogon. Zato je OOE tipično niži od OEE kad plan ispod '
      'operativnog povećava gubitke u kalendaru.';

  static const teepKpiTeepTooltip = 'TEEP u ovoj kartici';
  static const teepKpiTeepTitle = 'TEEP (kalendar)';
  static const teepKpiTeepBody =
      'TEEP = OEE × Utilization, gdje je Utilization = planirana proizvodnja / '
      'kalendarsko vrijeme. Vidi cijeli dan/tjedan — uključuje nerad, vikend, '
      'praznike ako su u kalendaru. Ne uspoređuj TEEP s OEE kao „istu stvar“.';

  static const teepUtilizationTooltip = 'Iskorištenje kalendara';
  static const teepUtilizationTitle = 'Utilization';
  static const teepUtilizationBody =
      'Koliki dio punog kalendara (sekunde) pretvaraš u planiranu proizvodnju. '
      'To je množitelj koji spaja OEE s „koliko dana uopće radiš plan“.';

  static const teepRecomputePanelTooltip = 'Kako preračun i sidro rade';
  static const teepRecomputePanelTitle = 'Preračun TEEP (Callable)';
  static const teepRecomputePanelBody =
      'Biraš period (dan / tjedan / mjesec) i opseg: cijeli pogon, linija '
      '(ID kao u ooe_shift_summaries.lineId) ili stroj (machineId). Sidro u kalendaru '
      'je jedan dan; za tjedan se uzima cijeli ISO tjedan od ponedjeljka, za mjesec cijeli mjesec. '
      'Pritisak na osvježi u traci otvara kalendar i šalje preračun s odabranim postavkama.';

  static const teepHistorySectionTooltip = 'Što znači lista ispod';
  static const teepHistorySectionTitle = 'Povijest perioda';
  static const teepHistorySectionBody =
      'Svaki red je jedan sačuvani proračun iz teep_summaries (s obzirom na opseg, '
      'tipu perioda i datumu). Noviji su na vrhu ako ih je više. Možeš uspoređivati '
      'OEE, OOE, TEEP i iskorištenje u istom retku.';

  static const capacitySectionCalendarHeaderTooltip = 'Ova sekcija';
  static const capacitySectionCalendarHeaderTitle = 'capacity_calendars';
  static const capacitySectionCalendarHeaderBody =
      'Dnevni zapisi: koliko u danu ima kalendarskog vremena, operativnog i '
      'planirane proizvodnje. Isti opseg (pogon, linija, stroj) mora imati kalendar '
      'za svaki dan kada preračunavaš tjedan ili mjesec.';

  static const capacitySectionUtilizationHeaderTooltip = 'Ova sekcija';
  static const capacitySectionUtilizationHeaderTitle = 'utilization_summaries';
  static const capacitySectionUtilizationHeaderBody =
      'Sažetak: koliko su plan, operativno i kalendar povezani (iskorištenje) za '
      'već izračunat period. Dolazi s istim proračunom kao TEEP.';
}
