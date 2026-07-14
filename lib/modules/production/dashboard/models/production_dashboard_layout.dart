enum ProductionDashboardLayout {
  standard('standard'),
  iconGrid('icon_grid');

  const ProductionDashboardLayout(this.storageValue);

  final String storageValue;

  static const String preferenceKey = 'productionDashboardLayout';

  static ProductionDashboardLayout fromStorage(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final layout in ProductionDashboardLayout.values) {
      if (layout.storageValue == normalized) {
        return layout;
      }
    }
    return ProductionDashboardLayout.standard;
  }
}
