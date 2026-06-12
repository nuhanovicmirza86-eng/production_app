import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/errors/app_error_mapper.dart';
import 'finance_strings.dart';
import 'package:flutter/widgets.dart';

/// Callable greške za Finance operativni sloj — preferira poruku s backenda.
class FinanceErrorMapper {
  FinanceErrorMapper._();

  static String toMessage(Object error, {BuildContext? context}) {
    if (error is FirebaseFunctionsException) {
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty) {
        return msg;
      }
    }
    final mapped = AppErrorMapper.toMessage(error);
    if (mapped.isNotEmpty) return mapped;
    if (context != null) {
      return FinanceStrings.t(context, 'error_generic');
    }
    return 'Došlo je do greške. Pokušajte ponovo.';
  }
}
