import '../models/ai_insight_model.dart';
import '../models/analytics_summary_model.dart';

/// Deterministička analiza nad [OperonixAnalyticsSnapshot] (narrativ za UI).
class OperonixAnalyticsNarrator {
  const OperonixAnalyticsNarrator._();

  static OperonixAiInsight build(OperonixAnalyticsSnapshot s) {
    final rep = s.report;
    final prev = s.previousReport;

    final topP = rep.paretoCategories.isNotEmpty ? rep.paretoCategories.first : null;
    final topWc = rep.byWorkCenter.isNotEmpty ? rep.byWorkCenter.first : null;

    final causes = <String>[];
    if (topP != null && topP.minutes > 0) {
      causes.add(
        'Najveći dio zastoja po kategoriji: ${topP.label} (${topP.minutes} min, ${topP.pctOfTotalMinutes.toStringAsFixed(1)}%).',
      );
    }
    if (topWc != null && topWc.minutesClipped > 0) {
      causes.add(
        'Radni centar s najviše minuta zastoja u periodu: ${topWc.label} (${topWc.minutesClipped} min).',
      );
    }
    if (rep.minutesOeeLoss > 0) {
      causes.add(
        'Ukupni gubitak koji utječe na OEE (prema zastojima): ${rep.minutesOeeLoss} min.',
      );
    }
    if (causes.isEmpty) {
      causes.add('U odabranom periodu nema zabilježenih zastoja koji bi generirali uzroke.');
    }

    final rec = <String>[];
    if (topP != null && topP.minutes > 0) {
      rec.add(
        'Fokus Pareto: smanjiti ${topP.label} — provjeriti uzrok na terenu i uvesti kratku kontrolnu listu pri startu smjene.',
      );
    }
    if (rep.mttrMinutesResolved != null && rep.mttrMinutesResolved! > 0) {
      rec.add(
        'MTTR u periodu: ${rep.mttrMinutesResolved!.toStringAsFixed(0)} min (zatvoreni zastoji). Razmotriti brže eskaliranje i rezervne dijelove za česte uzroke.',
      );
    }
    if (rep.correctiveActionFlagged > 0) {
      rec.add(
        '${rep.correctiveActionFlagged} zastoja označeno za korektivu — povezati s CAPA / 8D gdje je primjenjivo (IATF trag).',
      );
    }
    if (s.teepRollup.hasTeepData && s.teepRollup.avgOee < 0.65) {
      rec.add(
        'Prosječni OEE (${(s.teepRollup.avgOee * 100).toStringAsFixed(1)}%) ispod tipičnog cilja — prioritet: stabilizirati dostupnost (zastoji) i brzinu (performanse).',
      );
    }

    String? comparisonNote;
    if (prev != null && prev.minutesOeeLoss >= 0 && rep.minutesOeeLoss >= 0) {
      if (prev.minutesOeeLoss == 0 && rep.minutesOeeLoss == 0) {
        comparisonNote = 'Usporedba s prethodnim istim periodom: nema OEE gubitaka u oba intervala.';
      } else if (prev.minutesOeeLoss > 0) {
        final delta =
            (rep.minutesOeeLoss - prev.minutesOeeLoss) / prev.minutesOeeLoss * 100.0;
        final dir = delta > 1 ? 'porast' : (delta < -1 ? 'smanjenje' : 'stabilno');
        comparisonNote =
            'OEE gubitak (min) u odnosu na prethodni isti period: $dir '
            '(${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%).';
      } else if (rep.minutesOeeLoss > 0) {
        comparisonNote =
            'Prethodni period bez OEE gubitaka; u trenutnom periodu evidentirano ${rep.minutesOeeLoss} min.';
      }
    }

    String? risk;
    if (rep.unplannedMinutes > rep.plannedMinutes && rep.unplannedMinutes > 120) {
      risk =
          'Visok udio neplaniranih zastoja (${rep.unplannedMinutes} min) u odnosu na planirane (${rep.plannedMinutes} min) — rizik od kašnjenja i prekoračenja kapaciteta.';
    }

    final summary = StringBuffer();
    summary.write(
      'U periodu je zabilježeno ${rep.eventsTouchingPeriod} zastoja (${rep.totalMinutesClipped} min ukupno). ',
    );
    if (s.teepRollup.hasTeepData) {
      summary.write(
        'Prosj. OEE/OOE/TEEP (iz dnevnih sažetaka pogona): '
        '${(s.teepRollup.avgOee * 100).toStringAsFixed(1)}% / '
        '${(s.teepRollup.avgOoe * 100).toStringAsFixed(1)}% / '
        '${(s.teepRollup.avgTeep * 100).toStringAsFixed(1)}%.',
      );
    } else {
      summary.write(
        'Nema dnevnih TEEP sažetaka za pogon u ovom intervalu (ili učitavanje nije uspjelo) — KPI OEE/OOE/TEEP oslanjaju se na zastoje dok se ne popune agregati.',
      );
    }

    return OperonixAiInsight(
      title: 'OperonixAI sažetak (automatski)',
      summary: summary.toString(),
      mainCauses: causes,
      recommendations: rec.isEmpty
          ? const [
              'Kada se pojave zastoji, odmah povezati razlog, radni centar i nalog — to pokreće kvalitetniju analizu u sljedećim iteracijama.',
            ]
          : rec,
      riskNote: risk,
      comparisonNote: comparisonNote,
    );
  }
}
