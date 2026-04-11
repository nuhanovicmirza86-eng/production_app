class OrderStatusEngine {
  const OrderStatusEngine();

  OrderTotals calculateOrderTotals(
    List<Map<String, dynamic>> items, {
    required DateTime now,
  }) {
    int totalItems = items.length;
    double totalOrderedQty = 0;
    double totalConfirmedQty = 0;
    double totalDeliveredQty = 0;
    double totalReceivedQty = 0;
    bool hasProductionLink = false;
    bool isLate = false;

    for (final item in items) {
      totalOrderedQty += _toDouble(item['orderedQty']);
      totalConfirmedQty += _toDouble(item['confirmedQty']);
      totalDeliveredQty += _toDouble(item['deliveredQty']);
      totalReceivedQty += _toDouble(item['receivedQty']);

      if ((item['hasProductionLink'] ?? false) == true) {
        hasProductionLink = true;
      }

      final dueDate = _toDateTimeOrNull(item['dueDate']);
      final lineStatus = (item['status'] ?? '').toString().trim().toLowerCase();
      final closedStates = {'fulfilled', 'received', 'closed', 'cancelled'};

      if (dueDate != null &&
          dueDate.isBefore(now) &&
          !closedStates.contains(lineStatus)) {
        isLate = true;
      }
    }

    return OrderTotals(
      totalItems: totalItems,
      totalOrderedQty: totalOrderedQty,
      totalConfirmedQty: totalConfirmedQty,
      totalDeliveredQty: totalDeliveredQty,
      totalReceivedQty: totalReceivedQty,
      hasProductionLink: hasProductionLink,
      isLate: isLate,
    );
  }

  void validateManualStatusTransition({
    required String orderType,
    required String currentStatus,
    required String newStatus,
  }) {
    final normalizedOrderType = orderType.trim().toLowerCase();
    final from = currentStatus.trim().toLowerCase();
    final to = newStatus.trim().toLowerCase();

    if (from.isEmpty || to.isEmpty) {
      throw Exception('Status transition requires both current and new status');
    }

    if (from == to) return;

    _validateOrderType(normalizedOrderType);

    final allowed = normalizedOrderType == 'customer_order'
        ? _customerManualTransitionMap
        : _supplierManualTransitionMap;

    final allowedNext = allowed[from];
    if (allowedNext == null) {
      throw Exception('Unsupported current status: $from');
    }

    if (!allowedNext.contains(to)) {
      throw Exception('Invalid status transition: $from -> $to');
    }
  }

  /// Provjera bez bacanja iznimke (npr. vidljivost dugmadi Zatvori / Otkaži).
  bool canManualTransition({
    required String orderType,
    required String currentStatus,
    required String newStatus,
  }) {
    final from = currentStatus.trim().toLowerCase();
    final to = newStatus.trim().toLowerCase();
    if (from.isEmpty || to.isEmpty || from == to) return false;
    try {
      validateManualStatusTransition(
        orderType: orderType,
        currentStatus: currentStatus,
        newStatus: newStatus,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String calculateCustomerOrderStatus({
    required String currentStatus,
    required int totalItems,
    required double totalOrderedQty,
    required double totalConfirmedQty,
    required double totalDeliveredQty,
    required bool hasProductionLink,
    required bool isLate,
  }) {
    if (currentStatus == 'cancelled' || currentStatus == 'closed') {
      return currentStatus;
    }

    if (totalItems == 0 || totalOrderedQty <= 0) {
      return 'draft';
    }

    if (totalDeliveredQty >= totalOrderedQty && totalOrderedQty > 0) {
      return 'fulfilled';
    }

    if (totalDeliveredQty > 0 && totalDeliveredQty < totalOrderedQty) {
      return isLate ? 'late' : 'partially_fulfilled';
    }

    if (hasProductionLink) {
      return isLate ? 'late' : 'in_production';
    }

    if (totalConfirmedQty > 0) {
      return isLate ? 'late' : 'confirmed';
    }

    return isLate ? 'late' : 'draft';
  }

  String calculateSupplierOrderStatus({
    required String currentStatus,
    required int totalItems,
    required double totalOrderedQty,
    required double totalConfirmedQty,
    required double totalReceivedQty,
    required bool isLate,
  }) {
    if (currentStatus == 'cancelled' ||
        currentStatus == 'closed' ||
        currentStatus == 'quality_hold') {
      return currentStatus;
    }

    if (totalItems == 0 || totalOrderedQty <= 0) {
      return 'draft';
    }

    if (totalReceivedQty >= totalOrderedQty && totalOrderedQty > 0) {
      return 'received';
    }

    if (totalReceivedQty > 0 && totalReceivedQty < totalOrderedQty) {
      return isLate ? 'late' : 'partially_received';
    }

    if (totalConfirmedQty > 0) {
      return isLate ? 'late' : 'open';
    }

    return isLate ? 'late' : 'draft';
  }

  String calculateCustomerOrderItemStatus({
    required double orderedQty,
    required double confirmedQty,
    required double deliveredQty,
    required bool hasProductionLink,
    required bool isLate,
  }) {
    if (orderedQty <= 0) {
      return 'draft';
    }

    if (deliveredQty >= orderedQty) {
      return 'fulfilled';
    }

    if (deliveredQty > 0 && deliveredQty < orderedQty) {
      return isLate ? 'late' : 'partially_fulfilled';
    }

    if (hasProductionLink) {
      return isLate ? 'late' : 'in_production';
    }

    if (confirmedQty > 0) {
      return isLate ? 'late' : 'confirmed';
    }

    return isLate ? 'late' : 'draft';
  }

  String calculateSupplierOrderItemStatus({
    required double orderedQty,
    required double confirmedQty,
    required double receivedQty,
    required bool isLate,
  }) {
    if (orderedQty <= 0) {
      return 'draft';
    }

    if (receivedQty >= orderedQty) {
      return 'received';
    }

    if (receivedQty > 0 && receivedQty < orderedQty) {
      return isLate ? 'late' : 'partially_received';
    }

    if (confirmedQty > 0) {
      return isLate ? 'late' : 'open';
    }

    return isLate ? 'late' : 'draft';
  }

  double calculateOpenQty({
    required String orderType,
    required double orderedQty,
    required double deliveredQty,
    required double receivedQty,
  }) {
    final executedQty = orderType == 'customer_order'
        ? deliveredQty
        : receivedQty;

    final openQty = orderedQty - executedQty;
    return openQty < 0 ? 0.0 : openQty;
  }

  bool calculateItemIsLate({
    required String orderType,
    required DateTime? dueDate,
    required DateTime now,
    required double orderedQty,
    required double deliveredQty,
    required double receivedQty,
  }) {
    if (dueDate == null) return false;

    final executedQty = orderType == 'customer_order'
        ? deliveredQty
        : receivedQty;

    final isComplete = executedQty >= orderedQty && orderedQty > 0;
    if (isComplete) return false;

    return dueDate.isBefore(now);
  }

  double sanitizeQty(double value) {
    if (value < 0) return 0.0;
    return value;
  }

  double toDouble(dynamic value) {
    return _toDouble(value);
  }

  DateTime? toDateTimeOrNull(dynamic value) {
    return _toDateTimeOrNull(value);
  }

  void _validateOrderType(String orderType) {
    const allowed = {'customer_order', 'supplier_order'};
    if (!allowed.contains(orderType)) {
      throw Exception('Invalid orderType');
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return 0.0;
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  DateTime? _toDateTimeOrNull(dynamic value) {
    if (value == null) return null;

    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate() as DateTime;
    }

    if (value is DateTime) return value;

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static const Map<String, Set<String>> _customerManualTransitionMap = {
    'draft': {'confirmed', 'cancelled'},
    'confirmed': {'in_production', 'cancelled', 'closed'},
    'in_production': {'partially_fulfilled', 'fulfilled', 'late', 'cancelled'},
    'partially_fulfilled': {'fulfilled', 'late', 'closed', 'cancelled'},
    'fulfilled': {'closed'},
    'late': {
      'in_production',
      'partially_fulfilled',
      'fulfilled',
      'closed',
      'cancelled',
    },
    'closed': {},
    'cancelled': {},
  };

  static const Map<String, Set<String>> _supplierManualTransitionMap = {
    'draft': {'confirmed', 'cancelled'},
    'confirmed': {'open', 'cancelled'},
    'open': {
      'partially_received',
      'received',
      'quality_hold',
      'late',
      'cancelled',
    },
    'partially_received': {
      'received',
      'quality_hold',
      'late',
      'closed',
      'cancelled',
    },
    'received': {'closed', 'quality_hold'},
    'quality_hold': {
      'open',
      'partially_received',
      'received',
      'closed',
      'cancelled',
    },
    'late': {
      'open',
      'partially_received',
      'received',
      'quality_hold',
      'closed',
      'cancelled',
    },
    'closed': {},
    'cancelled': {},
  };
}

class OrderTotals {
  final int totalItems;
  final double totalOrderedQty;
  final double totalConfirmedQty;
  final double totalDeliveredQty;
  final double totalReceivedQty;
  final bool hasProductionLink;
  final bool isLate;

  const OrderTotals({
    required this.totalItems,
    required this.totalOrderedQty,
    required this.totalConfirmedQty,
    required this.totalDeliveredQty,
    required this.totalReceivedQty,
    required this.hasProductionLink,
    required this.isLate,
  });
}
