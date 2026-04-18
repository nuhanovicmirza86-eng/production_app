import 'package:cloud_functions/cloud_functions.dart';

/// Callable [generateProductionAiReport] — isti Firebase projekt kao Production app.
class ProductionAiReportService {
  ProductionAiReportService({
    FirebaseFunctions? functions,
  }) : _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  static String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Ako su [start] i [end] null, backend koristi zadnjih 7 kalendarskih dana.
  Future<ProductionAiReportResult> generate({
    required String companyId,
    required String plantKey,
    DateTime? start,
    DateTime? end,
  }) async {
    final cid = companyId.trim();
    final pk = plantKey.trim();
    if (cid.isEmpty || pk.isEmpty) {
      throw StateError('companyId i plantKey su obavezni.');
    }

    final payload = <String, dynamic>{
      'companyId': cid,
      'plantKey': pk,
    };
    if (start != null) payload['startDate'] = _ymd(start);
    if (end != null) payload['endDate'] = _ymd(end);

    final callable = _functions.httpsCallable('generateProductionAiReport');
    final raw = await callable.call<Map<String, dynamic>>(payload);
    final data = raw.data;
    if (data['success'] != true) {
      throw StateError('Generiranje nije uspjelo.');
    }
    final md = (data['reportMarkdown'] ?? '').toString().trim();
    if (md.isEmpty) {
      throw StateError('Prazan izvještaj.');
    }
    final period = data['period'];
    String? ps;
    String? pe;
    if (period is Map) {
      ps = period['startDate']?.toString();
      pe = period['endDate']?.toString();
    }
    return ProductionAiReportResult(
      markdown: md,
      startDate: ps,
      endDate: pe,
      generatedAt: data['generatedAt']?.toString(),
    );
  }
}

class ProductionAiReportResult {
  final String markdown;
  final String? startDate;
  final String? endDate;
  final String? generatedAt;

  const ProductionAiReportResult({
    required this.markdown,
    this.startDate,
    this.endDate,
    this.generatedAt,
  });
}
