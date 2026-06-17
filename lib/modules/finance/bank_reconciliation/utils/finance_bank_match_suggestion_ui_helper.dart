import 'package:flutter/widgets.dart';

import '../../shared/finance_display_labels.dart';
import '../../shared/finance_strings.dart';
import '../models/finance_bank_match_suggestion.dart';

/// P4-UI-M1 — pragovi usklađeni s backend [CONFIDENCE_*_MIN] i pravilima prikaza.
class FinanceBankMatchSuggestionUiHelper {
  FinanceBankMatchSuggestionUiHelper._();

  static const int highMinScore = 80;
  static const int mediumMinScore = 55;
  static const int primaryMaxCount = 10;

  static const Map<String, int> _signalWeightOrder = {
    'invoice_number_exact': 40,
    'payment_reference_exact': 30,
    'exact_amount': 25,
    'partner_account_exact': 20,
    'partner_name_normalized': 10,
    'partial_amount': 8,
    'due_date_proximity': 5,
    'booking_date_proximity': 5,
    'currency_exact': 0,
    'open_amount_compatible': 0,
  };

  static bool isHigh(FinanceBankMatchSuggestion s) => s.matchScore >= highMinScore;

  static bool isMedium(FinanceBankMatchSuggestion s) =>
      s.matchScore >= mediumMinScore && s.matchScore < highMinScore;

  static bool isWeak(FinanceBankMatchSuggestion s) => s.matchScore < mediumMinScore;

  static bool isUsefulForPrimaryList(FinanceBankMatchSuggestion s) =>
      !s.isDismissed && s.matchScore >= mediumMinScore;

  /// Visoka pouzdanost prvo, zatim srednja; unutar razine po score desc.
  static int compareForPrimaryList(
    FinanceBankMatchSuggestion a,
    FinanceBankMatchSuggestion b,
  ) {
    final tierA = isHigh(a) ? 0 : 1;
    final tierB = isHigh(b) ? 0 : 1;
    if (tierA != tierB) return tierA.compareTo(tierB);
    return b.matchScore.compareTo(a.matchScore);
  }

  static FinanceBankMatchSuggestionPartition partitionActive(
    List<FinanceBankMatchSuggestion> active,
  ) {
    final useful = active.where(isUsefulForPrimaryList).toList()
      ..sort(compareForPrimaryList);
    final primary = useful.take(primaryMaxCount).toList();
    final weak = active.where(isWeak).toList()
      ..sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return FinanceBankMatchSuggestionPartition(
      primary: primary,
      weak: weak,
      hiddenUsefulCount: useful.length > primary.length
          ? useful.length - primary.length
          : 0,
    );
  }

  static List<String> topReasonLabels(
    BuildContext context,
    FinanceBankMatchSuggestion suggestion, {
    int max = 3,
  }) {
    final ranked = [...suggestion.matchedSignals]
      ..sort((a, b) {
        final wa = _signalWeightOrder[a] ?? 0;
        final wb = _signalWeightOrder[b] ?? 0;
        return wb.compareTo(wa);
      });
    return ranked
        .take(max)
        .map((s) => signalSentence(context, s))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String signalSentence(BuildContext context, String signal) {
    final key = 'bank_match_sentence_${signal.trim().toLowerCase()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) return localized;
    return FinanceDisplayLabels.matchSignal(context, signal);
  }

  static String blockingSentence(BuildContext context, String reason) {
    final key = 'bank_match_block_sentence_${reason.trim().toLowerCase()}';
    final localized = FinanceStrings.t(context, key);
    if (localized != key) {
      return localized;
    }
    return FinanceDisplayLabels.blockingReason(context, reason);
  }

  static String confidenceLabel(BuildContext context, FinanceBankMatchSuggestion s) {
    if (isHigh(s)) {
      return FinanceStrings.t(context, 'bank_match_confidence_high');
    }
    if (isMedium(s)) {
      return FinanceStrings.t(context, 'bank_match_confidence_medium');
    }
    return FinanceStrings.t(context, 'bank_match_confidence_low');
  }

  static double amountDifference(FinanceBankMatchSuggestion s) =>
      s.bankAmount - s.invoiceOpenAmount;

  static String formatAmountDifference(
    BuildContext context,
    FinanceBankMatchSuggestion s,
    String Function(double amount, String currency) formatMoney,
  ) {
    final diff = amountDifference(s);
    if (diff.abs() < 0.005) {
      return FinanceStrings.t(context, 'bank_match_amount_diff_none');
    }
    final formatted = formatMoney(diff.abs(), s.currency);
    if (diff > 0) {
      return FinanceStrings.t(context, 'bank_match_amount_diff_over')
          .replaceAll('{amount}', formatted);
    }
    return FinanceStrings.t(context, 'bank_match_amount_diff_under')
        .replaceAll('{amount}', formatted);
  }

  static List<String> buildWarnings(
    BuildContext context,
    FinanceBankMatchSuggestion suggestion,
  ) {
    final warnings = <String>[];
    final signals = suggestion.matchedSignals.map((e) => e.toLowerCase()).toSet();

    if (isWeak(suggestion)) {
      warnings.add(FinanceStrings.t(context, 'bank_match_warn_low_score'));
    }

    if (!signals.contains('exact_amount') &&
        amountDifference(suggestion).abs() >= 0.005) {
      warnings.add(FinanceStrings.t(context, 'bank_match_warn_amount_diff'));
    }

    if (!signals.contains('partner_name_normalized') &&
        !signals.contains('partner_account_exact') &&
        !signals.contains('invoice_number_exact') &&
        !signals.contains('payment_reference_exact')) {
      if (signals.contains('currency_exact') ||
          signals.contains('due_date_proximity') ||
          signals.contains('booking_date_proximity')) {
        warnings.add(FinanceStrings.t(context, 'bank_match_warn_currency_date_only'));
      }
    } else if (signals.contains('partner_name_normalized') &&
        !signals.contains('partner_account_exact') &&
        !signals.contains('exact_amount')) {
      warnings.add(FinanceStrings.t(context, 'bank_match_warn_partner_weak'));
    }

    for (final reason in suggestion.blockingReasons) {
      warnings.add(blockingSentence(context, reason));
    }

    return warnings.toSet().toList();
  }
}

class FinanceBankMatchSuggestionPartition {
  const FinanceBankMatchSuggestionPartition({
    required this.primary,
    required this.weak,
    required this.hiddenUsefulCount,
  });

  final List<FinanceBankMatchSuggestion> primary;
  final List<FinanceBankMatchSuggestion> weak;
  final int hiddenUsefulCount;
}
