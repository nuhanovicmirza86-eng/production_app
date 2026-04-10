import 'package:flutter/material.dart';

import 'models/order_model.dart';

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.draft:
      return 'Draft';
    case OrderStatus.confirmed:
      return 'Potvrđena';
    case OrderStatus.inProduction:
      return 'U proizvodnji';
    case OrderStatus.partiallyFulfilled:
      return 'Djelomično isporučeno';
    case OrderStatus.fulfilled:
      return 'Realizovana';
    case OrderStatus.cancelled:
      return 'Otkazana';
    case OrderStatus.closed:
      return 'Zatvorena';
    case OrderStatus.late:
      return 'Kasni';
    case OrderStatus.open:
      return 'Otvorena';
    case OrderStatus.partiallyReceived:
      return 'Djelomično zaprimljeno';
    case OrderStatus.received:
      return 'Zaprimljeno';
    case OrderStatus.qualityHold:
      return 'Kvalitetna blokada';
  }
}

Color orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.draft:
      return Colors.grey;
    case OrderStatus.confirmed:
    case OrderStatus.open:
      return Colors.blue;
    case OrderStatus.inProduction:
    case OrderStatus.partiallyFulfilled:
    case OrderStatus.partiallyReceived:
      return Colors.orange;
    case OrderStatus.fulfilled:
    case OrderStatus.received:
    case OrderStatus.closed:
      return Colors.green;
    case OrderStatus.cancelled:
      return Colors.red;
    case OrderStatus.late:
      return Colors.deepOrange;
    case OrderStatus.qualityHold:
      return Colors.purple;
  }
}
