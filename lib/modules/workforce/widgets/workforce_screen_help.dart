import 'package:flutter/material.dart';

/// Info ikona s objašnjenjem ekrana — bez zauzimanja prostora u tijelu liste.
class WorkforceScreenHelpIcon extends StatelessWidget {
  const WorkforceScreenHelpIcon({
    super.key,
    required this.title,
    required this.message,
    this.tooltip,
  });

  final String title;
  final String message;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: tooltip ?? 'Objašnjenje ekrana',
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

abstract final class WorkforceHelpTexts {
  static const shiftPlanningTitle = 'Raspored smjena';

  static const shiftPlanningMessage =
      'Plan dodjele radnika na smjenu za odabrani dan i pogon.\n\n'
      'Odaberite datum u kalendaru, filtrirajte smjenu ikonom filtera, '
      'a novu dodjelu unosite ikonom plus u gornjem desnom uglu.\n\n'
      'Svaki red prikazuje radnika, smjenu, mjesto rada (linija ili stroj) '
      'i ulogu na smjeni. Podaci služe operativnom planiranju i usklađivanju '
      's matricom kvalifikacija — ovdje se ne unosi ocjena rada niti zapis u kadrovski dosije.';

  static const attendanceTitle = 'Prisutnost';

  static const attendanceMessage =
      'Evidencija operativne prisutnosti radnika po danu i smjeni.\n\n'
      'Kalendar mijenja dan, filter smjene sužava prikaz, a plus ikona otvara unos '
      'novog zapisa (prisutan, odsutan, kašnjenje ili operativno odsustvo).\n\n'
      'Napomena je kratka i ne smije sadržavati zdravstvene podatke. '
      'Ovo nije obračun radnog vremena niti HR ocjena.';

  static const skillsMatrixTitle = 'Matrica kvalifikacija';

  static const skillsMatrixMessage =
      'Pregled i unos kvalifikacija radnika za stroj, proces ili operaciju.\n\n'
      'Svaki red vezuje radnika s nivoom spremnosti, statusom (u obuci, kvalificiran, …) '
      'i rokom važenja. Ikona plus dodaje novi red; ikona kalendara vodi na pregled isteka.\n\n'
      'Red koji čeka odobrenje možete otvoriti da donesete odluku (odobri / odbij).';

  static const employeeKpiTitle = 'KPI radnika';

  static const employeeKpiMessage =
      'Objektivni pokazatelji učinka za odabranog radnika i period.\n\n'
      'Gornji blok koristi zatvorene evidencije procesa (doziranje, otpadne vode, dorada). '
      'Donji blok koristi starije izvore: operativno praćenje proizvodnje i događaje stanja stroja '
      'gdje je radnik povezan mrežnim nalogom.\n\n'
      'Subjektivnu ocjenu rukovodioca unosite u „Performanse i povratne informacije“. '
      'Ovdje nema automatske HR ocjene.';

  static const evidenceKpiSectionTitle = 'KPI iz evidencija procesa';

  static const evidenceKpiSectionMessage =
      'Brojevi dolaze isključivo iz zatvorenih evidencija na stanicama '
      '(obrađeno, OK, škart, vrijeme, normativno poređenje).\n\n'
      'Ako normativ postoji u sustavu, vidite usporedbu stvarnog učinka sa standardom. '
      'Ako normativ nije pronađen, KPI i dalje prikazuje stvarne brojeve bez usporedbe.';

  static const legacyKpiSectionTitle = 'Operativno praćenje i stanje stroja';

  static const legacyKpiSectionMessage =
      'Agregat iz unosa operativnog praćenja (dobra količina i škart) '
      'te događaja stanja stroja povezanih s mrežnim nalogom radnika.\n\n'
      'Koristi se dok svi izvori rada nisu povezani u jedinstveni KPI.';

  static const feedbackTitle = 'Performanse i povratne informacije';

  static const feedbackMessage =
      'Strukturirane povratne informacije i evidencija ocjena rukovodioca.\n\n'
      'Tab „Povratne informacije“ — coaching, priznanje ili područje za poboljšanje. '
      'Tab „Evidencija ocjena“ — formalniji zapis po mjesecu.\n\n'
      'Plus ikona u gornjem desnom uglu dodaje novi zapis ovisno o aktivnom tabu. '
      'Objektivni KPI iz evidencija vidite na ekranu KPI radnika.';

  static const linkedAccountTitle = 'Povezivanje mrežnog naloga';

  static const linkedAccountMessage =
      'Radnik nema povezan mrežni nalog u sustavu. '
      'Unosi s proizvodne stanice i automatska analiza u punom opsegu '
      'mogu se pouzdano povezati s imenom tek nakon povezivanja u operativnom profilu radnika.';

  static const processEvidenceAnalyticsTitle = 'Analitika evidencija procesa';

  static const processEvidenceAnalyticsMessage =
      'Agregirani pregled zatvorenih evidencija procesa za odabrani period i pogon.\n\n'
      'Filteri sužavaju prikaz; osvježavanje ponovo učitava podatke. '
      'Ekran je samo za čitanje — ne mijenja unos operatera na stanici.\n\n'
      'Izvor podataka trenutno uključuje evidencije procesa (tri profila stanica). '
      'Normativno poređenje prikazuje se kad postoji odgovarajući standard učinka.';

  static const normsListTitle = 'Normativi rada';

  static const normsListMessage =
      'Administracija standarda učinka (brzina, vrijeme, dopušteni škart).\n\n'
      'Filtrirate po statusu, pogonu i profilu procesa, zatim odaberete normativ s liste '
      'i otvarate detalj. Plus ikona kreira novi nacrt.\n\n'
      'Aktivacija uvijek stvara novu verziju; stara verzija se arhivira s audit tragom.';

  static const normDetailTitle = 'Detalj normativa';

  static const normDetailMessage =
      'Definicija standarda učinka: opseg (pogon, profil, stanica, operacija, proizvod), '
      'metrike i rok važenja.\n\n'
      'Nacrt se uređuje i sprema ikonom diskete; aktivacija i arhiviranje su u gornjem desnom uglu. '
      'Probno podudaranje provjerava hoće li se normativ primijeniti na zadani kontekst.\n\n'
      'Identifikatori verzija služe internom praćenju — u operativnom radu koristite naziv normativa.';

  static const employeeProfileTitle = 'Operativni profil radnika';

  static const employeeProfileMessage =
      'Evidencija radnika za operativno planiranje: šifra, ime, pogon, smjena i kontakt.\n\n'
      'Administrator može filtrirati po pogonu. Plus ikona dodaje novog radnika; '
      'QR ikona otvara skener bedža.\n\n'
      'Ovo nije kadrovski dosije niti HR modul — samo operativni profil za proizvodnju.';

  static const trainingTitle = 'Evidencija obuka';

  static const trainingMessage =
      'Planirane i završene obuke radnika u pogonu.\n\n'
      'Plus ikona otvara unos nove obuke. Svaki red prikazuje radnika, temu, status i trenera.\n\n'
      'Obuke se mogu povezati sa strojem, procesom ili operacijom iz matrice kvalifikacija.';

  static const qualificationExpiryTitle = 'Istek i revalidacija';

  static const qualificationExpiryMessage =
      'Pregled kvalifikacija kojima ističe rok u narednih 30 dana ili su već istekle.\n\n'
      'Sortirano po datumu isteka. Koristite matricu kvalifikacija za ažuriranje nakon revalidacije.';

  static const complianceTitle = 'Dokumenti usklađenosti';

  static const complianceMessage =
      'Potvrde procedura, izjave i slični zapisi — samo za administratore kompanije.\n\n'
      'Plus ikona dodaje novi zapis. Radnik može biti prazan za opće dokumente kompanije.\n\n'
      'Ovo nije zamjena za puni HR arhiv — operativni sloj za IATF trag.';

  static const leaveTitle = 'Odsustva (operativno)';

  static const leaveMessage =
      'Operativna dostupnost radnika za planiranje smjena — bez zdravstvenih podataka.\n\n'
      'Plus ikona otvara unos razdoblja odsustva. Napomena mora biti kratka i ne smije '
      'sadržavati osjetljive medicinske detalje.\n\n'
      'Ovo nije obračun godišnjeg odmora niti HR dosije.';

  static const recommendationsTitle = 'Preporuke i rizik';

  static const recommendationsMessage =
      'Automatski sažetak upozorenja iz matrice kvalifikacija, rasporeda smjena, '
      'obuka i operativnih odsustava.\n\n'
      'Odaberite horizont (7, 14 ili 30 dana) i osvježite ikonom u gornjem desnom uglu. '
      'Stavke su informativne — provjerite prije operativne odluke.';

  static const aiPlanningTitle = 'AI preporuke za planiranje rada';

  static const aiPlanningMessage =
      'Savjetodavne preporuke iz zatvorenih evidencija procesa za odabrani period.\n\n'
      'Postavite filtere, po želji unesite kontekst planiranja, zatim pokrenite analizu '
      'ikonom AI u gornjem desnom uglu.\n\n'
      'AI ne donosi HR odluke niti kreira disciplinske zapise. '
      'Normativno poređenje prikazuje se kad postoji odgovarajući standard učinka.';
}
