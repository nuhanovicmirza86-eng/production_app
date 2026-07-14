import 'package:flutter/material.dart';

/// Jedna stavka na početnom zaslonu (izvor istine za standard i ikonski prikaz).
class ProductionDashboardModuleEntry {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? noticeText;
  final Widget Function(BuildContext context)? customTileBuilder;

  const ProductionDashboardModuleEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.noticeText,
    this.customTileBuilder,
  });
}

/// Grupa modula na početnom zaslonu (npr. Proizvodnja, Kvalitet).
class ProductionDashboardModuleSection {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ProductionDashboardModuleEntry> entries;

  const ProductionDashboardModuleSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
  });

  bool get isVisible => entries.isNotEmpty;
}
