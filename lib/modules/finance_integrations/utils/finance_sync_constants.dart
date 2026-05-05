/// Tipovi synca za `finance_connections.enabledSyncTypes` (usklađeno s Callable).
abstract final class FinanceEnabledSyncTypes {
  static const String partnersImport = 'partners_import';
  static const String itemsImport = 'items_import';
  static const String supplierInvoicesImport = 'supplier_invoices_import';
  static const String productionCostExport = 'production_cost_export';
  static const String maintenanceCostExport = 'maintenance_cost_export';
  static const String developmentCostExport = 'development_cost_export';
  static const String csvExport = 'csv_export';

  static const List<String> allCodes = <String>[
    partnersImport,
    itemsImport,
    supplierInvoicesImport,
    productionCostExport,
    maintenanceCostExport,
    developmentCostExport,
    csvExport,
  ];

  static String displayLabel(String code) {
    switch (code.trim().toLowerCase()) {
      case partnersImport:
        return 'Uvoz partnera';
      case itemsImport:
        return 'Uvoz artikala';
      case supplierInvoicesImport:
        return 'Ulazni računi (dobavljači)';
      case productionCostExport:
        return 'Izvoz troška proizvodnje';
      case maintenanceCostExport:
        return 'Izvoz troška održavanja';
      case developmentCostExport:
        return 'Izvoz troška razvoja';
      case csvExport:
        return 'CSV / Excel izvoz';
      default:
        return code;
    }
  }
}

/// Predloženi statusi sync poslova (`finance_sync_jobs`) — za buduće ekrane.
abstract final class FinanceSyncJobStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String synced = 'synced';
  static const String failed = 'failed';
}
