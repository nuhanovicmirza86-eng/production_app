/// P6.2 — jedan prijedlog akcije u AI objašnjenju.

class ApsExecutionWatchProposedActionView {

  const ApsExecutionWatchProposedActionView({

    required this.rank,

    required this.label,

    required this.meaning,

  });



  final int rank;

  final String label;

  final String meaning;



  factory ApsExecutionWatchProposedActionView.fromMap(

    Map<String, dynamic> map,

  ) {

    return ApsExecutionWatchProposedActionView(

      rank: int.tryParse((map['rank'] ?? '0').toString()) ?? 0,

      label: (map['label'] ?? '').toString().trim(),

      meaning: (map['meaning'] ?? map['label'] ?? '').toString().trim(),

    );

  }

}



/// P6.2 — strukturirano AI objašnjenje na execution watch alertu.

class ApsExecutionWatchAiExplanationView {

  const ApsExecutionWatchAiExplanationView({

    required this.disclaimerText,

    this.systemFacts = const [],

    this.aiAssessment,

    this.recommendedNextStep,

    this.narrativeSummary,

    this.whyItMatters,

    this.delayCause,

    this.solutionProposal,

    this.proposedActions = const [],

    this.confidence,

    this.limitations,

    this.generatedAt,

    this.locale,

    this.promptVersion,

  });



  /// Usklađeno s backend `EXPLAIN_PROMPT_VERSION` / `EXPLAIN_LOCALE`.

  static const currentPromptVersion = 5;

  static const currentLocale = 'bs';



  final String disclaimerText;

  final List<String> systemFacts;

  final String? aiAssessment;

  final String? recommendedNextStep;

  final String? narrativeSummary;

  final String? whyItMatters;

  final String? delayCause;

  final String? solutionProposal;

  final List<ApsExecutionWatchProposedActionView> proposedActions;

  final String? confidence;

  final String? limitations;

  final String? generatedAt;

  final String? locale;

  final int? promptVersion;



  factory ApsExecutionWatchAiExplanationView.fromMap(

    Map<String, dynamic>? map,

  ) {

    if (map == null || map.isEmpty) {

      return const ApsExecutionWatchAiExplanationView(disclaimerText: '');

    }

    final facts = <String>[];

    final rawFacts = map['systemFacts'];

    if (rawFacts is List) {

      for (final f in rawFacts) {

        final s = (f ?? '').toString().trim();

        if (s.isNotEmpty) facts.add(s);

      }

    }



    final actions = <ApsExecutionWatchProposedActionView>[];

    final rawActions = map['recommendedActionsInterpretation'];

    if (rawActions is List) {

      for (final item in rawActions) {

        if (item is Map) {

          final view = ApsExecutionWatchProposedActionView.fromMap(

            Map<String, dynamic>.from(item),

          );

          if (view.label.isNotEmpty || view.meaning.isNotEmpty) {

            actions.add(view);

          }

        }

      }

    }



    return ApsExecutionWatchAiExplanationView(

      disclaimerText: (map['disclaimerText'] ?? '').toString().trim(),

      systemFacts: facts,

      aiAssessment: _optString(map['aiAssessment'] ?? map['narrativeSummary']),

      recommendedNextStep: _optString(

        map['recommendedNextStep'] ?? map['safestNextStep'],

      ),

      narrativeSummary: _optString(map['narrativeSummary']),

      whyItMatters: _optString(map['whyItMatters']),

      delayCause: _optString(map['delayCause']),

      solutionProposal: _optString(map['solutionProposal']),

      proposedActions: actions,

      confidence: _optString(map['confidence']),

      limitations: _optString(map['limitations']),

      generatedAt: _optString(map['generatedAt']),

      locale: _optString(map['locale']),

      promptVersion: int.tryParse((map['promptVersion'] ?? '').toString()),

    );

  }



  static String? _optString(dynamic raw) {

    final s = (raw ?? '').toString().trim();

    return s.isEmpty ? null : s;

  }



  bool get isFreshForDisplay =>

      locale == currentLocale &&

      (promptVersion ?? 0) >= currentPromptVersion;



  bool get hasContent =>

      isFreshForDisplay &&

      (disclaimerText.isNotEmpty ||

          systemFacts.isNotEmpty ||

          (delayCause?.isNotEmpty ?? false) ||

          (solutionProposal?.isNotEmpty ?? false) ||

          proposedActions.isNotEmpty ||

          (aiAssessment?.isNotEmpty ?? false) ||

          (recommendedNextStep?.isNotEmpty ?? false));

}


