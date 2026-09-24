/// AI-M2-G3 — context binding s detalj ekrana → postojeći Operonix AI Asistent.
///
/// `businessKey` ide u Callable poruku (F routing), **ne** kao raw ID u UI chipu.
/// `displayLabel` je jedini korisnički vidljiv identifikator konteksta.
enum OperonixAiEntityChatKind {
  ncr,
  evidenceSession,
  productionOrder,
  machine,
  worker,
  materialLot,
}

class OperonixAiEntityChatBinding {
  const OperonixAiEntityChatBinding({
    required this.kind,
    required this.businessKey,
    required this.displayLabel,
  });

  final OperonixAiEntityChatKind kind;

  /// Poslovni identifikator za F router (NCR broj, šifra naloga, …).
  /// Za evidenciju: session lookup ključ (ne prikazuje se u chipu).
  final String businessKey;

  /// BCS labela u chatu (bez Firestore path / Auth UID).
  final String displayLabel;

  bool get isReady {
    final key = businessKey.trim();
    final label = displayLabel.trim();
    return key.isNotEmpty && label.isNotEmpty;
  }

  /// D4 feedback `contract` (postojeći ALLOWED_CONTRACTS).
  String get feedbackContract {
    switch (kind) {
      case OperonixAiEntityChatKind.ncr:
        return 'aiGetNcrContext';
      case OperonixAiEntityChatKind.evidenceSession:
        return 'aiGetEvidenceSessionContext';
      case OperonixAiEntityChatKind.productionOrder:
        return 'aiGetProductionOrderContext';
      case OperonixAiEntityChatKind.machine:
        return 'aiGetMachineRiskContext';
      case OperonixAiEntityChatKind.worker:
        return 'aiGetWorkerFitContext';
      case OperonixAiEntityChatKind.materialLot:
        return 'aiGetMaterialLotRiskContext';
    }
  }

  String get feedbackModule {
    switch (kind) {
      case OperonixAiEntityChatKind.ncr:
      case OperonixAiEntityChatKind.evidenceSession:
        return 'quality';
      case OperonixAiEntityChatKind.worker:
      case OperonixAiEntityChatKind.machine:
      case OperonixAiEntityChatKind.productionOrder:
      case OperonixAiEntityChatKind.materialLot:
        return 'production';
    }
  }

  String get contextChipTitle {
    switch (kind) {
      case OperonixAiEntityChatKind.ncr:
        return 'Kontekst: neusaglašenost';
      case OperonixAiEntityChatKind.evidenceSession:
        return 'Kontekst: evidencija';
      case OperonixAiEntityChatKind.productionOrder:
        return 'Kontekst: proizvodni nalog';
      case OperonixAiEntityChatKind.machine:
        return 'Kontekst: radno mjesto';
      case OperonixAiEntityChatKind.worker:
        return 'Kontekst: radnik';
      case OperonixAiEntityChatKind.materialLot:
        return 'Kontekst: materijalni lot';
    }
  }

  /// Početno pitanje (BCS) — bez raw ID-a u prikazu.
  String get starterQuestion {
    switch (kind) {
      case OperonixAiEntityChatKind.ncr:
        return 'Sažmi kontekst, status i rizike za ovu neusaglašenost.';
      case OperonixAiEntityChatKind.evidenceSession:
        return 'Sažmi kontekst i ishod ove evidencije.';
      case OperonixAiEntityChatKind.productionOrder:
        return 'Sažmi status i rizike za ovaj proizvodni nalog.';
      case OperonixAiEntityChatKind.machine:
        return 'Koji su rizici za ovo radno mjesto?';
      case OperonixAiEntityChatKind.worker:
        return 'Kakav je operativni fit za ovog radnika?';
      case OperonixAiEntityChatKind.materialLot:
        return 'Koji su rizici za ovaj materijalni lot?';
    }
  }

  /// Fraza koju F router prepoznaje (ne prikazuje se u bubble-u ako je drugačiji display).
  String get routingAnchorPhrase {
    final key = businessKey.trim();
    switch (kind) {
      case OperonixAiEntityChatKind.ncr:
        return key;
      case OperonixAiEntityChatKind.evidenceSession:
        return 'evidencija $key';
      case OperonixAiEntityChatKind.productionOrder:
        return 'nalog $key';
      case OperonixAiEntityChatKind.machine:
        return 'radno mjesto $key';
      case OperonixAiEntityChatKind.worker:
        return 'radnik $key';
      case OperonixAiEntityChatKind.materialLot:
        return 'lot $key';
    }
  }

  /// Obogaćuje korisničku poruku za F routing bez mijenjanja freeze routera.
  String toRoutableMessage(String userVisibleText) {
    final visible = userVisibleText.trim();
    final key = businessKey.trim();
    if (key.isEmpty) return visible;
    final anchor = routingAnchorPhrase;
    if (visible.toLowerCase().contains(key.toLowerCase()) &&
        visible.toLowerCase().startsWith(anchor.toLowerCase())) {
      return visible;
    }
    if (visible.isEmpty) {
      return anchor;
    }
    // Radno mjesto: sidro NAKON pitanja. F2 capture dozvoljava razmak,
    // pa „radno mjesto RC-001\nKoji su rizici…“ postane pogrešan ključ.
    if (kind == OperonixAiEntityChatKind.machine) {
      return '$visible\n$anchor';
    }
    return '$anchor\n$visible';
  }
}
