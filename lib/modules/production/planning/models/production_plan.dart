import 'package:flutter/foundation.dart';

import 'production_plan_item.dart';
import 'production_plan_status.dart';

@immutable
class ProductionPlan {
  const ProductionPlan({
    required this.id,
    required this.companyId,
    required this.plantKey,
    required this.planCode,
    required this.status,
    required this.createdAt,
    this.createdBy = '',
    this.planningStart,
    this.planningEnd,
    this.strategy = 'mvp_fifo_due',
    this.notes = '',
    this.items = const [],
    this.totalOrders = 0,
    this.totalConflicts = 0,
    this.onTimeRate01,
    this.estimatedUtilization01,
  });

  final String id;
  final String companyId;
  final String plantKey;
  final String planCode;
  final ProductionPlanStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime? planningStart;
  final DateTime? planningEnd;
  final String strategy;
  final String notes;
  final List<ProductionPlanItem> items;
  final int totalOrders;
  final int totalConflicts;
  final double? onTimeRate01;
  final double? estimatedUtilization01;
}
