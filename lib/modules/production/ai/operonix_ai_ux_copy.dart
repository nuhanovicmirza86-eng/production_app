import 'package:flutter/foundation.dart';

/// Business-facing copy for Production AI screens (AI-UX-PREMIUM-01).
const String kOperonixAiTransientReplyUnavailable =
    'Odgovor trenutno nije dostupan. Pokušajte ponovo.';

const String kOperonixAiEmptyAnalysisPeriod =
    'Za odabrani period nema podataka za analizu.';

const String kOperonixAiEmptyReportPeriod =
    'Za odabrani period nema podataka za izvještaj.';

const String kOperonixAiRetryActionLabel = 'Pokušajte ponovo';

const String kOperonixAiComposerHint = 'Poruka…';

/// Demo payload actions stay out of production UX.
/// Enable locally with `--dart-define=OPERONIX_AI_DEMO=true` in debug only.
const bool kOperonixAiAllowDemoPayload = bool.fromEnvironment(
  'OPERONIX_AI_DEMO',
  defaultValue: false,
);

bool showOperonixAiDemoActions({bool? isRelease}) {
  final release = isRelease ?? kReleaseMode;
  if (release) return false;
  return kDebugMode && kOperonixAiAllowDemoPayload;
}

String formatOperonixFilterDateRange(DateTime start, DateTime end) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(start.day)}.${two(start.month)}–${two(end.day)}.${two(end.month)}';
}

/// True when a structured-analysis snapshot has no operational rows.
bool isStructuredAnalysisPayloadEmpty(Map<String, dynamic> payload) {
  final losses = payload['losses'];
  if (losses is Map) {
    final entryCount = losses['entryCount'];
    if (entryCount is int) {
      final good = losses['totalGoodQty'];
      final scrap = losses['totalScrapQty'];
      final goodN = good is num ? good.toDouble() : 0;
      final scrapN = scrap is num ? scrap.toDouble() : 0;
      if (entryCount <= 0 && goodN == 0 && scrapN == 0) return true;
    }
  }

  if (payload.containsKey('telemetryPoints')) {
    final telemetry = payload['telemetryPoints'];
    if (telemetry is List && telemetry.isEmpty) return true;
  }

  if (payload.containsKey('orders')) {
    final totals = payload['totals'];
    if (totals is Map) {
      final n = totals['ordersInPeriod'];
      if (n is int && n <= 0) return true;
    }
    final orders = payload['orders'];
    if (orders is List && orders.isEmpty) return true;
  }

  return false;
}
