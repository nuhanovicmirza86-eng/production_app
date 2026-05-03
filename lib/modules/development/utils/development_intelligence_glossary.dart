/// Kratka objašnjenja za Launch Intelligence (tooltips / info ikone).
class DevelopmentIntelligenceGlossary {
  DevelopmentIntelligenceGlossary._();

  static const launchReadinessScore = 'Operonix Launch Readiness Score (0–100): '
      'agregat spremnosti za serijsku proizvodnju iz APQP faza, PPAP dokaza, PFMEA rizika, '
      'Control Plana, probne serije (G5), KPI kapabilnosti, alata/mašine, dobavljača i lekcija (G9). '
      'Pragovi: ≥90 može SOP; 75–89 uslovno (admin može release u sustavu); 60–74 blokada rizika; '
      '<60 nije spremno.';

  static const sopBlockers =
      'SOP blocker: čvrsti uvjet koji sistem veže uz puštanje u seriju — uključuje Gate dokumentaciju, '
      'odobrenja, blokirajuće rizike/izmjene i Launch Readiness ispod praga.';

  static const digitalThread = 'Digitalni trag: od zahtjeva kupca do BOM, routinga, probe, PPAP-a, '
      'SOP-a i MES metrika — jedan lanac dokaza umjesto izolovanih PDF-ova.';

  static const changeImpact = 'AI / rules change impact: za svaku otvorenu izmjenu (ECO, dobavljač, alat…) '
      'sistem predloži koje domene (BOM, PFMEA, PPAP…) su vjerovatno pogođene — polazište za IATF kontrolu promjena.';

  static const lessonsLearned = 'Lessons learned engine (MVP): traži slične NPI projekte u istom tenantu/pogonu '
      '(kupac, tip, naziv proizvoda) i podsjeti na CSR i historiju.';

  static const dynamicControlPlan = 'Dynamic Control Plan (MVP): predlozi jačanja ili smanjenja kontrole '
      'na osnovu rizika, dobavljača i statusa G5 — živi plan, ne samo statičan dokument.';

  static const predictiveRisk = 'Prediktivni launch rizik: heuristika iz otvorenih rizika, KPI i statusa projekta; '
      'puni profil (smjena, OEE, alat) nadograđuje se MES podacima nakon série.';

  static const redTeam = 'Red Team pregled: pitanja kao interni auditor prije SOP-a. '
      'AI asistent s fokusom „red_team” generira dublju analizu iz istog JSON konteksta.';

  static const heatmap = 'Risk heatmap: vizuelni pregled intenziteta rizika po dimenzijama (proizvod, proces, '
      'dobavljač, alat, mašina, kvaliteta, kupac). Nivoi 0–3: od OK do blokade SOP-a.';

  static const noSilentChange =
      'No silent change: bitne promjene (BOM, routing, alat, dobavljač, mašina, kontrola) '
      'evidenciraju se u modulu kao `changes` i ne bi smjele ući u seriju bez odobrenja.';

  static String? forSegmentId(String id) {
    switch (id) {
      case 'apqp_phases':
        return 'Udio završenih Gate faza (G0–G9) u projektu.';
      case 'ppap_completeness':
        return 'Procjena PPAP paketa iz broja odobrenih dokumenata i ključnih tragova (npr. PSW).';
      case 'pfmea_risks':
        return 'Zatvorenost rizika u evidenciji; otvoreni visoki rizici snažno smanjuju segment.';
      case 'control_plan':
        return 'Dokaz usklađenosti kontrolnog plana u metapodacima dokumenata.';
      case 'trial_run':
        return 'Status faze G5 (probna serija / pilot).';
      case 'process_capability':
        return 'Polje KPI qualityReadiness na projektu (ako postoji).';
      case 'tool_machine':
        return 'Rizici vezani uz alat i mašinu — zatvorenost u PFMEA evidenciji.';
      case 'supplier_material':
        return 'Otvorene promjene tipa supplier u projektu.';
      case 'quality_findings':
        return 'Certifikati i odobreni dokumenti kvalitete u evidenciji.';
      case 'lessons_learned':
        return 'Formalno zatvaranje G9 / lekcije naučene.';
      default:
        return null;
    }
  }
}
