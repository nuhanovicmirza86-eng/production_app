import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/errors/app_error_mapper.dart';
import 'finance_strings.dart';
import 'package:flutter/widgets.dart';

/// Callable greške za Finance operativni sloj — preferira poruku s backenda.
class FinanceErrorMapper {
  FinanceErrorMapper._();

  static bool isConcurrencyAborted(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'aborted';
    }
    return false;
  }

  static String concurrencyHint(BuildContext context) {
    return FinanceStrings.t(context, 'concurrency_refresh_hint');
  }

  /// Poruka kad potvrda bankovnog uparivanja padne na revision check (aborted).
  static String bankMatchConfirmNotSavedMessage(
    BuildContext context,
    Object error,
  ) {
    final headline = FinanceStrings.t(context, 'bank_match_confirm_not_saved');
    if (error is FirebaseFunctionsException) {
      final detail = error.message?.trim();
      if (detail != null && detail.isNotEmpty) {
        return '$headline\n$detail\n${concurrencyHint(context)}';
      }
    }
    return '$headline ${concurrencyHint(context)}';
  }

  static String toMessage(Object error, {BuildContext? context}) {
    if (error is FirebaseFunctionsException) {
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty) {
        if (_isOpaqueInternalMessage(msg)) {
          return context != null
              ? FinanceStrings.t(context, 'error_server_internal')
              : 'Greška na serveru. Pokušajte ponovo kasnije.';
        }
        if (_looksLikeMissingIndex(msg)) {
          return _indexBuildMessage(msg);
        }
        return msg;
      }
      if (error.code == 'internal') {
        return context != null
            ? FinanceStrings.t(context, 'error_server_internal')
            : 'Greška na serveru. Pokušajte ponovo kasnije.';
      }
      if (error.code == 'not-found') {
        return context != null
            ? FinanceStrings.t(context, 'error_function_not_found')
            : 'Cloud funkcija nije pronađena (deploy).';
      }
    }
    if (error is TypeError || error is FormatException) {
      final raw = error.toString();
      if (context != null) {
        return '${FinanceStrings.t(context, 'error_parse')}\n$raw';
      }
      return 'Neispravan odgovor servera.';
    }
    final mapped = AppErrorMapper.toMessage(error);
    if (mapped.isNotEmpty) return mapped;
    if (context != null) {
      return FinanceStrings.t(context, 'error_generic');
    }
    return 'Došlo je do greške. Pokušajte ponovo.';
  }

  static bool _isOpaqueInternalMessage(String message) {
    final m = message.trim().toLowerCase();
    return m == 'internal' ||
        m == 'internal error' ||
        m == 'unknown' ||
        m == 'error';
  }

  static bool _looksLikeMissingIndex(String message) {
    final m = message.toLowerCase();
    return m.contains('index') || m.contains('requires an index');
  }

  static String _indexBuildMessage(String raw) {
    return 'Baza traži sastavljeni indeks za ovaj prikaz (ili se indeks još gradi). '
        'Administrator: deploy indeksa iz maintenance_app repozitorija.\n\n$raw';
  }
}
