import 'package:flutter/material.dart';

import '../finance_strings.dart';
import 'finance_assistant_context.dart';

/// Brza izgradnja [FinanceAssistantContext] iz companyData i string ključeva.
abstract final class FinanceAssistantContextFactory {
  FinanceAssistantContextFactory._();

  static FinanceAssistantContext fromCompany({
    required BuildContext context,
    required Map<String, dynamic> companyData,
    required String screenKey,
    required String tabKey,
    String? tabLabelKey,
    String? entityStatus,
    List<({String key, bool enabled})> actions = const [],
    Map<String, String> extraFacts = const {},
    Map<String, String> screenFacts = const {},
    String? prefilledQuestionKey,
  }) {
    final available = <String>[];
    final disabled = <String>[];
    for (final action in actions) {
      final label = FinanceStrings.t(context, action.key);
      if (action.enabled) {
        available.add(label);
      } else {
        disabled.add(label);
      }
    }

    return FinanceAssistantContext(
      companyId: (companyData['companyId'] ?? '').toString().trim(),
      screenKey: screenKey,
      tabKey: tabKey,
      tabLabelKey: tabLabelKey,
      role: (companyData['role'] ?? '').toString().trim(),
      entityStatus: entityStatus,
      availableActions: available,
      disabledActions: disabled,
      extraFacts: extraFacts,
      screenFacts: screenFacts,
      prefilledQuestionKey: prefilledQuestionKey,
    );
  }

  static List<({String key, bool enabled})> refreshOnly() => const [
        (key: 'refresh', enabled: true),
      ];

  static List<({String key, bool enabled})> createAndRefresh({
    required String createKey,
    required bool canCreate,
  }) =>
      [
        (key: createKey, enabled: canCreate),
        (key: 'refresh', enabled: true),
      ];
}
