/// Ključevi usklađeni s backendom `quality_qms_writes.js` (EIGHT_D_KEYS, ISHIKAWA_KEYS).
abstract final class CapaEightDKeys {
  static const List<String> all = [
    'd1_team',
    'd2_problem',
    'd3_containment',
    'd4_rootCause',
    'd5_corrective',
    'd6_implement',
    'd7_prevent',
    'd8_recognition',
  ];

  static String labelHr(String key) {
    switch (key) {
      case 'd1_team':
        return 'D1 — Tim';
      case 'd2_problem':
        return 'D2 — Opis problema';
      case 'd3_containment':
        return 'D3 — Privremene (među) mjere';
      case 'd4_rootCause':
        return 'D4 — Analiza uzroka (nadopunjava Ishikawa)';
      case 'd5_corrective':
        return 'D5 — Trajna korektivna akcija';
      case 'd6_implement':
        return 'D6 — Implementacija i potvrda učinkovitosti';
      case 'd7_prevent':
        return 'D7 — Prevencija ponavljanja';
      case 'd8_recognition':
        return 'D8 — Priznanje timu';
      default:
        return key;
    }
  }
}

abstract final class CapaIshikawaKeys {
  static const List<String> all = [
    'man',
    'machine',
    'material',
    'method',
    'measurement',
    'environment',
  ];

  static String labelHr(String key) {
    switch (key) {
      case 'man':
        return 'Čovjek (Man)';
      case 'machine':
        return 'Stroj (Machine)';
      case 'material':
        return 'Materijal (Material)';
      case 'method':
        return 'Metoda (Method)';
      case 'measurement':
        return 'Mjerenje (Measurement)';
      case 'environment':
        return 'Okolina (Environment)';
      default:
        return key;
    }
  }
}
