/// Info tekst za ekran AI preporuke — objašnjenje u AppBar ikoni, ne u tijelu.
abstract final class WorkerAiPlanningHelpTexts {
  static const title = 'AI preporuke za planiranje rada';

  static const message =
      'Savjetodavne preporuke za operativno planiranje rada na temelju '
      'zatvorenih evidencija procesa za odabrani period i kontekst.\n\n'
      'Postavite filtere, po želji unesite kontekst planiranja, zatim pokrenite '
      'analizu ikonom AI u gornjem desnom uglu.\n\n'
      'AI ne ocjenjuje radnika niti donosi HR odluke — ne kreira disciplinske '
      'zapise niti zamjenjuje procjenu rukovodioca.\n\n'
      'Poređenje s normativom: kad postoji aktivan standard učinka za odabrani '
      'kontekst, preporuke uzimaju u obzir usporedbu stvarnog učinka s normativom '
      '(brzina, vrijeme, dopušteni škart).\n\n'
      'Kad normativ nije pronađen za period i kontekst, preporuke se temelje '
      'isključivo na stvarnim evidencijama rada — bez usporedbe sa standardom.';
}
