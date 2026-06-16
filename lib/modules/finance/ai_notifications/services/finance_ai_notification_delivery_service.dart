import 'package:cloud_functions/cloud_functions.dart';

import '../models/finance_ai_notification_badge_summary.dart';
import '../models/finance_ai_notification_delivery.dart';

class FinanceAiNotificationDeliveryService {
  FinanceAiNotificationDeliveryService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: _region);

  static const String _region = 'europe-west1';

  final FirebaseFunctions _functions;

  Future<FinanceAiNotificationBadgeSummary> getBadgeSummary({
    required String companyId,
    String? plantKey,
  }) async {
    final callable = _functions.httpsCallable(
      'getFinanceAiNotificationBadgeSummary',
    );
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor getFinanceAiNotificationBadgeSummary');
    }
    return FinanceAiNotificationBadgeSummary.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  Future<List<FinanceAiNotificationDelivery>> listDeliveries({
    required String companyId,
    List<String>? status,
    String? plantKey,
    int limit = 50,
  }) async {
    final callable = _functions.httpsCallable(
      'listFinanceAiNotificationDeliveries',
    );
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (plantKey != null && plantKey.trim().isNotEmpty)
        'plantKey': plantKey.trim(),
      'limit': limit,
    });
    final data = response.data;
    if (data is! Map) {
      throw FormatException('Nevaljan odgovor listFinanceAiNotificationDeliveries');
    }
    final raw = data['deliveries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => FinanceAiNotificationDelivery.fromCallableMap(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();
  }

  Future<FinanceAiNotificationDelivery> getDelivery({
    required String companyId,
    required String deliveryId,
  }) async {
    final callable = _functions.httpsCallable(
      'getFinanceAiNotificationDelivery',
    );
    final response = await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'deliveryId': deliveryId.trim(),
    });
    final data = response.data;
    if (data is! Map || data['delivery'] is! Map) {
      throw FormatException('Nevaljan odgovor getFinanceAiNotificationDelivery');
    }
    return FinanceAiNotificationDelivery.fromCallableMap(
      Map<String, dynamic>.from(data['delivery'] as Map),
    );
  }

  Future<void> markDeliveryRead({
    required String companyId,
    required String deliveryId,
  }) async {
    final callable = _functions.httpsCallable(
      'markFinanceAiNotificationDeliveryRead',
    );
    await callable.call(<String, dynamic>{
      'companyId': companyId.trim(),
      'deliveryId': deliveryId.trim(),
    });
  }
}
