/// Kratka objašnjenja (BA) za info ikone u modulu Razvoj — IATF i nepoznati pojmovi.
library;

class DevelopmentHelpTexts {
  DevelopmentHelpTexts._();

  // —— IATF 8.4 / dobavljači ——
  static const iatf84Tooltip =
      'Šta znači IATF 8.4 u portfelju i na projektu.';
  static const iatf84Title = 'Vanjski dobavljači (IATF 8.4)';
  static const iatf84Body =
      'Standard IATF 16949 u klauzuli 8.4 propisuje kontrolu vanjskih izvršitelja '
      '(alatnica, materijal, usluge). Ovdje pratite koje vanjske strane projekt koristi, '
      'status odobrenja, rokove i napomene za trag usklađenosti. '
      'To je operativni zapis u Operonixu — ne zamjena za cjeloviti PPAP paket niti internu ili vanjsku reviziju.';

  static const iatf84TraceTooltip =
      'Šta je polje „IATF 8.4 trag".';
  static const iatf84TraceTitle = 'IATF 8.4 trag';
  static const iatf84TraceBody =
      'Kratka bilješka šta je urađeno u kontroli vanjskog izvršitelja (npr. interni ili drugi audit, otvoreni rizik, ograničenje). '
      'Služi da Launch Intelligence i AI imaju kontekst. Formalnu dokumentaciju i dalje vodite u svom QMS-u i arhivi dokumenata.';

  static const suppliersTabTooltip =
      'Uloga liste dobavljača u modulu Razvoj i u AI analizi.';
  static const suppliersTabTitle = 'Dobavljači na projektu';
  static const suppliersTabBody =
      'Lista je izvor za praćenje vanjskih dobavljača (npr. alatnica za kalup). '
      'Status odobrenja, rok, ocjene (kvalitet, rok isporuke, cijena) i napomene IATF 8.4 ulaze u kontekst Callablea '
      'runDevelopmentProjectAiAnalysis — asistent može upozoriti na rizike i usklađenost. '
      'To ne zamjenjuje formalni PPAP niti internu reviziju.';

  static const supplierExternalRiskTooltip =
      'Procjena vanjskog rizika u kontekstu IATF 8.4.';
  static const supplierExternalRiskTitle = 'Vanjski rizik (IATF 8.4 kontekst)';
  static const supplierExternalRiskBody =
      'Opcija nizak / srednji / visok opisuje izloženost od vanjskog izvršitelja na ovom projektu. '
      'Koristi se uz trag IATF 8.4 da Launch Intelligence i tim vide prioritet — ne umjesto procedure u vašem QMS-u.';

  static const supplierIatfFieldTooltip =
      'Tekstualno polje za kontrole i trag IATF 8.4.';
  static const supplierIatfFieldTitle = 'IATF 8.4 — kontrole / trag';
  static const supplierIatfFieldBody = iatf84TraceBody;

  // —— Stage-Gate ——
  static const stageGateConceptTooltip =
      'Šta je Stage-Gate i šta znače G0–G9 u modulu Razvoj.';
  static const stageGateConceptTitle = 'Stage-Gate model';
  static const stageGateConceptBody =
      'Stage-Gate je način vođenja NPI projekta preko kontrolnih tačaka (Gate-ova). U Operonixu su faze označene kao G0 do G9. '
      'Lista „Stage-Gate" na projektu prikazuje svaku fazu i njen status; „Trenutni Gate" na kartici i u brzom pregledu je sažet položaj — koja je faza trenutno noseća u ciklusu. '
      'U portfelju možete filtrirati projekte po trenutnom Gate-u; u analitici „Dominantni Gate" pokazuje koji se kod Gate-a najčešće pojavljuje u filtriranom skupu projekata. '
      'Kod spremnosti za release i Launch Intelligence, polje „Referentni Gate" bira prema kojoj kontrolnoj tački želite provjeru pravila i blokada (može se namjerno postaviti drugačije od trenutnog Gate-a ako tim analizira drugi rez). '
      'Opcionalno „povezani Gate" kod dokumenta veže metapodatak uz određenu fazu radi izvještaja i Launch Intelligence-a. '
      'Formalno odobravanje faze ostaje u vašem poslovnom procesu i ovlaštenjima u sistemu — ovdje je operativni trag i dokaz.';

  static const referentniGateTooltip =
      'Šta znači referentni Gate u provjeri i u Launch Intelligence.';
  static const referentniGateTitle = 'Referentni Gate';
  static const referentniGateBody =
      'To je kontrolna tačka G0–G9 prema kojoj Callable na poslužitelju provjerava blokade (dokumente, odobrenja, pragove Launch Readiness itd.). '
      'Ne mora biti isti kao „trenutni Gate" na dokumentu projekta: tim može namjerno provjeriti npr. G7 dok je aktivnost još na G6. '
      'Za cjelinu Stage-Gate modela otvorite info na listi faza projekta ili na kartici projekta u portfelju.';

  static const dominantGateTooltip =
      'Šta je dominantni Gate u ovoj analitici.';
  static const dominantGateTitle = 'Dominantni Gate';
  static const dominantGateBody =
      'U aktivnom filtru portfelja broji se koji Gate kod (G0–G9) se najčešće pojavljuje kao trenutni Gate na projektima. '
      'Brzo pokazuje u kojoj ste fazi kao „masa" inicijativa (npr. svi zaglavili na G5). '
      'Puno objašnjenje Stage-Gate modela: ista info ikona na kartici projekta ili na grafu raspodjele po fazi.';

  static const portfolioGateFilterTooltip =
      'Filtriranje portfelja po trenutnom Gate-u.';
  static const portfolioGateFilterTitle = 'Filter po Gate-u';
  static const portfolioGateFilterBody = stageGateConceptBody;

  static const linkedDocumentGateTooltip =
      'Zašto dokument ima polje povezani Gate.';
  static const linkedDocumentGateTitle = 'Povezani Gate (opcionalno)';
  static const linkedDocumentGateBody =
      'Opcionalno vezujete zapis dokumenta uz jednu Stage-Gate fazu (G0–G9) da izvještaji i Launch Intelligence znaju uz koji rez je dokaz u smislu NPI toka (npr. PPAP uz G5). '
      'Ne zamjenjuje odobrenje u QMS-u niti status same faze na listi Stage-Gate.';

  // —— Portfelj / analitika ——
  static const stageGateChartTooltip =
      'Šta prikazuje raspodjela po Gate-u.';
  static const stageGateChartTitle = 'Raspodjela po Stage-Gate fazi';
  static const stageGateChartBody =
      'Gate u Stage-Gate modelu je kontrolna tačka NPI životnog ciklusa. '
      'Graf pokazuje koliko projekata u trenutnom filtru portfelja je na kojem Gate-u (npr. G3, G5) — brz uvid gdje se inicijative zadržavaju. '
      'Cjelinu pojma Stage-Gate (G0–G9) vidi i preko info ikone na kartici projekta ili na filteru Gate u listi portfelja.';

  static const overallHealthTooltip =
      'Šta znači „overall health" u ovom grafu.';
  static const overallHealthTitle = 'Distribucija „overall health”';
  static const overallHealthBody =
      '„Overall health" je zbirni KPI na dokumentu projekta (obično 0–100). '
      'Pojasevi ovdje grupišu projekte po tom pokazatelju kako biste vidjeli koliko inicijativa je u jačem ili slabijem stanju u portfelju.';

  static const lifecyclePortfolioTooltip =
      'Pojmovi tok, pažnja, zatvoreno.';
  static const lifecyclePortfolioTitle = 'Životni ciklus u portfelju';
  static const lifecyclePortfolioBody =
      'Pojednostavljen prikaz: aktivni tok, stavke koje traže pažnju i završene projekte u trenutnom filtru portfelja.';

  static const portfolioSuppliersAggregateTooltip =
      'Zbirni pokazatelji za dobavljače kroz filtrirane projekte.';
  static const portfolioSuppliersAggregateTitle = 'Dobavljači u portfelju';
  static const portfolioSuppliersAggregateBody =
      'Agregat kroz sve projekte u aktivnom filtru: jedinstveni nazivi dobavljača, broj veza projekt–dobavljač, '
      'brojevi odobreno / odbijeno / na čekanju i prosjek ocjena kvalitete, isporuke i cijene gdje su ocjene unesene.';

  // —— Spremnost / KPI ——
  static const releaseReadinessTooltip =
      'Šta radi provjera spremnosti za release.';
  static const releaseReadinessTitle = 'Spremnost za release';
  static const releaseReadinessBody =
      'Provjera je heuristika na poslužitelju: risici, evidencija izmjena, trenutna Gate faza, odobrenja i dokumenti. '
      'Rezultat je podsjetnik za tim — ne automatizovano odobrenje serije. Detaljniji pregled i blokatori u tabu Launch Intelligence.';

  static const kpiDashboardTooltip =
      'Šta znače KPI kartice na projektu.';
  static const kpiDashboardTitle = 'KPI — pregled projekta';
  static const kpiDashboardBody =
      'Kartice prikazuju agregirane metrike NPI inicijative: raspored (schedule), trošak (cost), kvalitet, prolaz kroz Gate-ove, rizik i ukupno zdravlje. '
      'Vrijednosti dolaze iz podataka u projektu; ne zaobilaze formalna odobrenja u QMS-u.';

  static const kpiScheduleTooltip = 'Schedule performance';
  static const kpiScheduleTitle = 'Schedule performance';
  static const kpiScheduleBody =
      'Metrika rasporeda: koliko se držite vremenskog plana inicijative u odnosu na datume i Gate-ove u podacima projekta.';

  static const kpiCostTooltip = 'Cost performance';
  static const kpiCostTitle = 'Cost performance';
  static const kpiCostBody =
      'Metrika troška: odnos planiranog i praćenog troška inicijative u podacima projekta.';

  static const kpiQualityTooltip = 'Quality readiness';
  static const kpiQualityTitle = 'Quality readiness';
  static const kpiQualityBody =
      'Spremnost kvalitete: dokazi i stanje u podacima projekta (dokumenti, odobrenja, nalazi) prije sljedeće kontrolne tačke.';

  static const kpiGatePassTooltip = 'Gate pass rate';
  static const kpiGatePassTitle = 'Gate pass rate';
  static const kpiGatePassBody =
      'Udio prolaska kroz Stage-Gate kontrolne tačke bez vraćanja ili ponavljanja faze, prema evidenciji na projektu.';

  static const kpiRiskTooltip = 'Risk score';
  static const kpiRiskTitle = 'Risk score';
  static const kpiRiskBody =
      'Zbirni signal izloženosti rizicima iz evidencije; veća vrijednost obično traži više pažnje tima.';

  static const kpiOverallTooltip = 'Overall health';
  static const kpiOverallTitle = 'Overall health';
  static const kpiOverallBody =
      'Jedinstveni zbirni broj „zdravlja" projekta koji se koristi u portfelju i u pragovima Launch Readiness u sistemu.';

  // —— Novi projekat ——
  static const createInitiativeTypeTooltip =
      'Zašto birate tip inicijative.';
  static const createInitiativeTypeTitle = 'Tip inicijative';
  static const createInitiativeTypeBody =
      'Tip klasifikuje NPI inicijativu (npr. novi proizvod za kupca, interni razvoj, industrializacija). '
      'Od toga zavise predloženi obrasci i kontrole u toku — ne zamjenjuje vaš APQP/PPAP plan u cjelini.';

  static const createBusinessContextTooltip =
      'Polje kupac / program i veza na šifarnik.';
  static const createBusinessContextTitle = 'Poslovni kontekst';
  static const createBusinessContextBody =
      'Tekstualno ime kupca ili programa i, po želji, veza na zapis kupca u šifrarniku. '
      'Povezivanje omogućuje CSR profil (posebni zahtjevi kupca), Launch Intelligence i trag zahtjeva u smislu IATF standarda.';

  // —— CSR / AI portfelj / MES u LC ——
  static const csrProfileTooltip =
      'Šta je CSR u Launch Intelligence.';
  static const csrProfileTitle = 'Profil zahtjeva kupca (CSR)';
  static const csrProfileBody =
      'CSR (Customer Specific Requirements) je sažetak posebnih zahtjeva kupca, često uključujući PPAP očekivanja, pravilo obavještavanja o promjenama i kontakte. '
      'U Operonixu se puni na zapisu partnera (kupca); ovdje je skraćeni prikaz vezan za ovaj projekat.';

  static const portfolioAiContextTooltip =
      'Kako AI koristi kontekst projekta.';
  static const portfolioAiContextTitle = 'Kontekst projekta';
  static const portfolioAiContextBody =
      'Jedan projekat po zahtjevu — poslužitelj učitava dopušteni JSON kontekst (Gate, rizici, dokumenti, dobavljači i sl.). '
      'Gotovi fokusi (uključujući Dobavljači IATF 8.4) su predloženi upit; asistent ne odobrava Gate niti release.';

  static const mesAggregateTooltip =
      'Šta znači MES agregat ovdje.';
  static const mesAggregateTitle = 'MES agregat (proizvodni nalozi)';
  static const mesAggregateBody =
      'Pregled da li za productId projekta u odabranom pogonu postoji trag u MES-u (proizvodni nalozi). '
      'To je signal da li je operativna proizvodnja vidljiva u sistemu; tačan opseg ovisi o uključenim modulima i politikama tenant-a.';
}
