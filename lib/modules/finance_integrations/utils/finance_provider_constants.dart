/// Kanonski kodovi ERP providera (modul `finance_integrations`).
/// Usklađeno s arhitekturom — ne svi moraju biti implementirani u MVP-u.
abstract final class FinanceProviderConstants {
  static const String pantheon = 'pantheon';
  static const String sapBusinessOne = 'sap_business_one';
  static const String microsoftDynamics = 'microsoft_dynamics';
  static const String odoo = 'odoo';
  static const String quickbooks = 'quickbooks';
  static const String xero = 'xero';
  static const String customRestApi = 'custom_rest_api';
  static const String customSqlReadonly = 'custom_sql_readonly';
  static const String csvExcelImportExport = 'csv_excel_import_export';
  static const String minimax = 'minimax';
  static const String synesis = 'synesis';
  static const String datalabPantheon = 'datalab_pantheon';
  static const String localErpCustom = 'local_erp_custom';

  static const List<String> selectableProviderCodes = <String>[
    pantheon,
    sapBusinessOne,
    microsoftDynamics,
    odoo,
    quickbooks,
    xero,
    customRestApi,
    customSqlReadonly,
    csvExcelImportExport,
    minimax,
    synesis,
    datalabPantheon,
    localErpCustom,
  ];

  static String displayLabel(String code) {
    switch (code.trim().toLowerCase()) {
      case pantheon:
        return 'Pantheon';
      case sapBusinessOne:
        return 'SAP Business One';
      case microsoftDynamics:
        return 'Microsoft Dynamics';
      case odoo:
        return 'Odoo';
      case quickbooks:
        return 'QuickBooks';
      case xero:
        return 'Xero';
      case customRestApi:
        return 'Prilagođeni REST API';
      case customSqlReadonly:
        return 'SQL (samo čitanje)';
      case csvExcelImportExport:
        return 'CSV / Excel';
      case minimax:
        return 'Minimax';
      case synesis:
        return 'Synesis';
      case datalabPantheon:
        return 'Pantheon (Datalab)';
      case localErpCustom:
        return 'Lokalni ERP';
      default:
        if (code.trim().isEmpty) return '—';
        return code;
    }
  }
}
