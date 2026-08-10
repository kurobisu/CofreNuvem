import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double value) {
    final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return formatCurrency.format(value);
  }
}
