import 'package:intl/intl.dart';

class FinanceMoneyFormat {
  FinanceMoneyFormat._();

  static String format(double amount, String? currency) {
    final fmt = NumberFormat('#,##0.00', 'en_US');
    final cur = (currency ?? '').trim();
    if (cur.isEmpty) return fmt.format(amount);
    return '${fmt.format(amount)} $cur';
  }
}
