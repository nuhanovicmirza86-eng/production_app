import 'package:flutter/material.dart';

import '../../branding/operonix_ai_branding.dart';
import 'operonix_premium_icon.dart';
import 'premium_icon_accent.dart';

/// Mapiranje poslovnih naziva i profila na Premium simbole.
///
/// Classic i dalje koristi svoje Material ikone. Ovaj sloj vrijedi samo
/// kad Premium widget sam zatraži simbol.
class OperonixPremiumIconography {
  const OperonixPremiumIconography._();

  static const Map<String, OperonixPremiumGlyph> _titles = {
    'Korisnici': OperonixPremiumGlyph.usersAccess,
    'Registracije': OperonixPremiumGlyph.usersAccess,
    'Proizvodnja': OperonixPremiumGlyph.productionCell,
    'Proizvodi': OperonixPremiumGlyph.products,
    'Proizvodni nalozi': OperonixPremiumGlyph.productionOrder,
    'Planiranje proizvodnje': OperonixPremiumGlyph.planningFlow,
    'Napredno planiranje': OperonixPremiumGlyph.planningFlow,
    'Praćenje proizvodnje (tabovi)': OperonixPremiumGlyph.liveTracking,
    'Praćenje': OperonixPremiumGlyph.liveTracking,
    'Radni centri': OperonixPremiumGlyph.workCenter,
    'Procesi': OperonixPremiumGlyph.process,
    'Radna snaga': OperonixPremiumGlyph.workforce,
    'Obračun radnog vremena': OperonixPremiumGlyph.workDay,
    'Zastoji': OperonixPremiumGlyph.downtime,
    'OOE — učinak pogona': OperonixPremiumGlyph.analytics,
    'OOE — praćenje uživo': OperonixPremiumGlyph.liveTracking,
    'TEEP i kapacitet': OperonixPremiumGlyph.analytics,
    'Operonix Analytics': OperonixPremiumGlyph.analytics,
    'Prijava problema': OperonixPremiumGlyph.maintenance,
    'Izvršenje proizvodnje': OperonixPremiumGlyph.productionCell,
    'Izvještaji': OperonixPremiumGlyph.reports,
    'Način rada na ovom uređaju': OperonixPremiumGlyph.station,
    'Operativne stanice (profil)': OperonixPremiumGlyph.station,
    'Operativne evidencije': OperonixPremiumGlyph.evidence,
    'Kontrolne evidencije': OperonixPremiumGlyph.inspectionRoute,
    'Moje otvorene akcije': OperonixPremiumGlyph.openActions,
    'Evidencije procesa': OperonixPremiumGlyph.processCheck,
    'Analitika evidencija procesa': OperonixPremiumGlyph.analytics,
    'Evidencije kompanije': OperonixPremiumGlyph.evidence,
    'Stanice proizvodnje': OperonixPremiumGlyph.station,
    'Kvalitet': OperonixPremiumGlyph.qualityShield,
    'Kvalitet — središnji izbornik': OperonixPremiumGlyph.qualityShield,
    'Metodologija · IATF': OperonixPremiumGlyph.methodology,
    'Pregled kvaliteta': OperonixPremiumGlyph.qualityOverview,
    'Dokumentacija': OperonixPremiumGlyph.controlledDocument,
    'Izvještaj za vodstvo': OperonixPremiumGlyph.managementReport,
    'PFMEA (proces)': OperonixPremiumGlyph.pfmea,
    'Kontrolni planovi': OperonixPremiumGlyph.controlPlan,
    'Planovi kontrole': OperonixPremiumGlyph.inspectionRoute,
    'Izvrši kontrolu': OperonixPremiumGlyph.qrScan,
    'Povijest kontrola': OperonixPremiumGlyph.history,
    'Reklamacija kupca': OperonixPremiumGlyph.ncr,
    'Reklamacija dobavljača': OperonixPremiumGlyph.ncr,
    'NCR': OperonixPremiumGlyph.ncr,
    'Historija akcija NCR-a': OperonixPremiumGlyph.history,
    'CAPA': OperonixPremiumGlyph.capa,
    'Interni audit': OperonixPremiumGlyph.audit,
    'Razvoj / NPI / Projekti': OperonixPremiumGlyph.development,
    'Razvoj i projekti': OperonixPremiumGlyph.development,
    'Razvoj': OperonixPremiumGlyph.development,
    'Financije · ERP integracije': OperonixPremiumGlyph.finance,
    'Financije · integracije': OperonixPremiumGlyph.finance,
    'Finance & Controlling': OperonixPremiumGlyph.finance,
    'Financije': OperonixPremiumGlyph.finance,
    'Narudžbe': OperonixPremiumGlyph.orders,
    'Podaci za ispis PDF': OperonixPremiumGlyph.controlledDocument,
    'Kupci / dobavljači': OperonixPremiumGlyph.partners,
    'Komercijalno': OperonixPremiumGlyph.orders,
    'Centralni magacin / Hub': OperonixPremiumGlyph.logistics,
    'Upakovane kutije Stanica 1': OperonixPremiumGlyph.packingSeal,
    'Logistika i magacin': OperonixPremiumGlyph.logistics,
    'Karbonski otisak': OperonixPremiumGlyph.carbon,
    'Održivost': OperonixPremiumGlyph.carbon,
    'O aplikaciji': OperonixPremiumGlyph.about,
    'Izgled aplikacije': OperonixPremiumGlyph.appearance,
    'Općenito': OperonixPremiumGlyph.about,
    'Radni dan': OperonixPremiumGlyph.workDay,
    'Datum unosa': OperonixPremiumGlyph.entryDate,
    'Pogon': OperonixPremiumGlyph.plant,
    'Brzi unos': OperonixPremiumGlyph.quickEntry,
    'Ručni unos': OperonixPremiumGlyph.manualEntry,
    'Skeniraj QR': OperonixPremiumGlyph.qrScan,
    'Kolone': OperonixPremiumGlyph.tableColumns,
    'Količina': OperonixPremiumGlyph.quantity,
    'Doziranje hemikalija': OperonixPremiumGlyph.chemicalDose,
    'Evidencija količina proizvodnje': OperonixPremiumGlyph.productionCount,
    'Procesna kontrola': OperonixPremiumGlyph.processCheck,
    'Priprema materijala': OperonixPremiumGlyph.materialPrep,
    'Obrada otpadnih voda': OperonixPremiumGlyph.wastewater,
    'Kontrola pakovanja': OperonixPremiumGlyph.packingSeal,
    'Odobrenje prvog komada': OperonixPremiumGlyph.firstPiece,
    'Finalna kontrola': OperonixPremiumGlyph.finalInspection,
    'Čišćenje mašine': OperonixPremiumGlyph.machineClean,
  };

  static OperonixPremiumGlyph? forTitle(String title) {
    final key = title.trim();
    final direct = _titles[key];
    if (direct != null) return direct;
    if (key == kOperonixAiAssistantTitle || key == kOperonixAiShortLabel) {
      return OperonixPremiumGlyph.aiInsight;
    }
    if (key.startsWith('Stanica')) return OperonixPremiumGlyph.station;
    if (key.startsWith('Praćenje')) return OperonixPremiumGlyph.liveTracking;
    if (key.startsWith('OOE')) return OperonixPremiumGlyph.analytics;
    return null;
  }

  static OperonixPremiumGlyph? forProfile(String profileKey) {
    switch (profileKey.trim()) {
      case 'chemical_dosing':
        return OperonixPremiumGlyph.chemicalDose;
      case 'wastewater_treatment':
        return OperonixPremiumGlyph.wastewater;
      case 'production_counting':
        return OperonixPremiumGlyph.productionCount;
      case 'in_process_quality_check':
        return OperonixPremiumGlyph.processCheck;
      case 'final_control':
        return OperonixPremiumGlyph.finalInspection;
      case 'first_piece_approval':
        return OperonixPremiumGlyph.firstPiece;
      case 'packaging_control':
        return OperonixPremiumGlyph.packingSeal;
      case 'material_preparation':
      case 'operation_material_preparation':
        return OperonixPremiumGlyph.materialPrep;
      case 'line_clearance':
        return OperonixPremiumGlyph.machineClean;
      case 'workspace_5s_cleaning':
        return OperonixPremiumGlyph.workspace5s;
      case '':
        return null;
      default:
        return OperonixPremiumGlyph.evidence;
    }
  }

  static OperonixPremiumGlyph? forKpi(String label) {
    switch (label.trim()) {
      case 'Ukupno':
        return OperonixPremiumGlyph.kpiTotal;
      case 'Otvoreni':
        return OperonixPremiumGlyph.kpiOpen;
      case 'U toku':
        return OperonixPremiumGlyph.kpiRunning;
      case 'Završeni':
        return OperonixPremiumGlyph.kpiDone;
      default:
        return null;
    }
  }

  static OperonixPremiumGlyph? forIcon(IconData icon) {
    if (icon == Icons.science_outlined) return OperonixPremiumGlyph.chemicalDose;
    if (icon == Icons.water_outlined) return OperonixPremiumGlyph.wastewater;
    if (icon == Icons.numbers_outlined) {
      return OperonixPremiumGlyph.productionCount;
    }
    if (icon == Icons.fact_check_outlined || icon == Icons.fact_check) {
      return OperonixPremiumGlyph.processCheck;
    }
    if (icon == Icons.verified_outlined || icon == Icons.verified) {
      return OperonixPremiumGlyph.firstPiece;
    }
    if (icon == Icons.verified_user_outlined) {
      return OperonixPremiumGlyph.finalInspection;
    }
    if (icon == Icons.assignment_turned_in_outlined ||
        icon == Icons.assignment_turned_in) {
      return OperonixPremiumGlyph.qualityShield;
    }
    if (icon == Icons.inventory_outlined) return OperonixPremiumGlyph.materialPrep;
    if (icon == Icons.inventory_2_outlined || icon == Icons.inventory_2) {
      return OperonixPremiumGlyph.products;
    }
    if (icon == Icons.precision_manufacturing_outlined ||
        icon == Icons.precision_manufacturing) {
      return OperonixPremiumGlyph.workCenter;
    }
    if (icon == Icons.groups_outlined ||
        icon == Icons.groups ||
        icon == Icons.groups_2_outlined ||
        icon == Icons.groups_2 ||
        icon == Icons.person_add_alt_1_outlined ||
        icon == Icons.person_add_alt_1 ||
        icon == Icons.badge_outlined ||
        icon == Icons.manage_accounts_outlined) {
      return OperonixPremiumGlyph.usersAccess;
    }
    if (icon == Icons.task_alt_rounded || icon == Icons.task_alt_outlined) {
      return OperonixPremiumGlyph.kpiDone;
    }
    if (icon == Icons.pending_actions_outlined) return OperonixPremiumGlyph.kpiOpen;
    if (icon == Icons.play_circle_outline || icon == Icons.play_circle) {
      return OperonixPremiumGlyph.liveTracking;
    }
    if (icon == Icons.account_tree_outlined || icon == Icons.account_tree) {
      return OperonixPremiumGlyph.process;
    }
    if (icon == Icons.assignment_outlined || icon == Icons.assignment) {
      return OperonixPremiumGlyph.productionOrder;
    }
    if (icon == Icons.view_timeline_outlined || icon == Icons.view_timeline) {
      return OperonixPremiumGlyph.planningFlow;
    }
    if (icon == Icons.smart_toy_outlined || icon == Icons.smart_toy) {
      return OperonixPremiumGlyph.aiInsight;
    }
    if (icon == Icons.insights_outlined ||
        icon == Icons.query_stats_outlined ||
        icon == Icons.analytics_outlined ||
        icon == Icons.speed_outlined ||
        icon == Icons.speed ||
        icon == Icons.assessment_outlined ||
        icon == Icons.assessment) {
      return OperonixPremiumGlyph.analytics;
    }
    if (icon == Icons.picture_as_pdf_outlined) {
      return OperonixPremiumGlyph.managementReport;
    }
    if (icon == Icons.warning_amber_outlined || icon == Icons.warning_amber) {
      return OperonixPremiumGlyph.downtime;
    }
    if (icon == Icons.report_problem_outlined ||
        icon == Icons.report_problem ||
        icon == Icons.report_gmailerrorred_outlined) {
      return OperonixPremiumGlyph.ncr;
    }
    if (icon == Icons.calendar_today_outlined ||
        icon == Icons.edit_calendar_outlined) {
      return OperonixPremiumGlyph.workDay;
    }
    if (icon == Icons.factory_outlined) return OperonixPremiumGlyph.plant;
    if (icon == Icons.qr_code_scanner_outlined || icon == Icons.qr_code_scanner) {
      return OperonixPremiumGlyph.qrScan;
    }
    if (icon == Icons.inbox_outlined) return OperonixPremiumGlyph.openActions;
    if (icon == Icons.menu_book_outlined) return OperonixPremiumGlyph.methodology;
    if (icon == Icons.dashboard_outlined) {
      return OperonixPremiumGlyph.qualityOverview;
    }
    if (icon == Icons.folder_special_outlined) {
      return OperonixPremiumGlyph.controlledDocument;
    }
    if (icon == Icons.engineering_outlined) return OperonixPremiumGlyph.controlPlan;
    if (icon == Icons.history || icon == Icons.history_toggle_off) {
      return OperonixPremiumGlyph.history;
    }
    if (icon == Icons.eco_outlined || icon == Icons.eco) {
      return OperonixPremiumGlyph.carbon;
    }
    if (icon == Icons.cleaning_services_outlined) {
      return OperonixPremiumGlyph.machineClean;
    }
    if (icon == Icons.grid_view_outlined) return OperonixPremiumGlyph.workspace5s;
    if (icon == Icons.bolt_outlined) return OperonixPremiumGlyph.quickEntry;
    if (icon == Icons.edit_note_outlined) return OperonixPremiumGlyph.manualEntry;
    if (icon == Icons.view_column_outlined) return OperonixPremiumGlyph.tableColumns;
    if (icon == Icons.notifications_active_outlined) {
      return OperonixPremiumGlyph.attention;
    }
    if (icon == Icons.hub_outlined) return OperonixPremiumGlyph.logistics;
    if (icon == Icons.receipt_long_outlined || icon == Icons.receipt_long) {
      return OperonixPremiumGlyph.orders;
    }
    if (icon == Icons.account_balance_outlined || icon == Icons.account_balance) {
      return OperonixPremiumGlyph.finance;
    }
    if (icon == Icons.support_agent_outlined ||
        icon == Icons.local_shipping_outlined) {
      return OperonixPremiumGlyph.ncr;
    }
    if (icon == Icons.fullscreen_outlined || icon == Icons.fullscreen) {
      return OperonixPremiumGlyph.station;
    }
    if (icon == Icons.access_time_outlined || icon == Icons.access_time_filled) {
      return OperonixPremiumGlyph.workDay;
    }
    if (icon == Icons.display_settings_outlined) {
      return OperonixPremiumGlyph.station;
    }
    return null;
  }

  static OperonixPremiumGlyph? resolve({
    String? title,
    String? profileKey,
    IconData? icon,
  }) {
    if (profileKey != null) {
      final fromProfile = forProfile(profileKey);
      if (fromProfile != null) return fromProfile;
    }
    if (title != null) {
      final fromTitle = forTitle(title);
      if (fromTitle != null) return fromTitle;
      final fromKpi = forKpi(title);
      if (fromKpi != null) return fromKpi;
    }
    if (icon != null) return forIcon(icon);
    return null;
  }

  static PremiumIconRole roleFor(OperonixPremiumGlyph? glyph) {
    switch (glyph) {
      case OperonixPremiumGlyph.productionCell:
      case OperonixPremiumGlyph.productionOrder:
      case OperonixPremiumGlyph.productionCount:
      case OperonixPremiumGlyph.products:
      case OperonixPremiumGlyph.liveTracking:
      case OperonixPremiumGlyph.kpiDone:
      case OperonixPremiumGlyph.workspace5s:
      case OperonixPremiumGlyph.readyStatus:
        return PremiumIconRole.success;
      case OperonixPremiumGlyph.qualityShield:
      case OperonixPremiumGlyph.processCheck:
      case OperonixPremiumGlyph.packingSeal:
      case OperonixPremiumGlyph.firstPiece:
      case OperonixPremiumGlyph.finalInspection:
      case OperonixPremiumGlyph.qualityOverview:
      case OperonixPremiumGlyph.inspectionRoute:
      case OperonixPremiumGlyph.controlPlan:
      case OperonixPremiumGlyph.audit:
        return PremiumIconRole.quality;
      case OperonixPremiumGlyph.planningFlow:
      case OperonixPremiumGlyph.materialPrep:
      case OperonixPremiumGlyph.entryDate:
      case OperonixPremiumGlyph.quantity:
        return PremiumIconRole.material;
      case OperonixPremiumGlyph.machineClean:
      case OperonixPremiumGlyph.maintenance:
      case OperonixPremiumGlyph.kpiRunning:
      case OperonixPremiumGlyph.workCenter:
        return PremiumIconRole.active;
      case OperonixPremiumGlyph.chemicalDose:
      case OperonixPremiumGlyph.wastewater:
        return PremiumIconRole.lab;
      case OperonixPremiumGlyph.usersAccess:
      case OperonixPremiumGlyph.plant:
      case OperonixPremiumGlyph.workforce:
      case OperonixPremiumGlyph.partners:
        return PremiumIconRole.people;
      case OperonixPremiumGlyph.aiInsight:
      case OperonixPremiumGlyph.analytics:
      case OperonixPremiumGlyph.managementReport:
      case OperonixPremiumGlyph.reports:
        return PremiumIconRole.analytics;
      case OperonixPremiumGlyph.openActions:
      case OperonixPremiumGlyph.attention:
      case OperonixPremiumGlyph.kpiOpen:
        return PremiumIconRole.warning;
      case OperonixPremiumGlyph.pfmea:
      case OperonixPremiumGlyph.ncr:
      case OperonixPremiumGlyph.downtime:
        return PremiumIconRole.critical;
      case OperonixPremiumGlyph.workDay:
      case OperonixPremiumGlyph.methodology:
      case OperonixPremiumGlyph.controlledDocument:
      case OperonixPremiumGlyph.quickEntry:
      case OperonixPremiumGlyph.manualEntry:
      case OperonixPremiumGlyph.qrScan:
      case OperonixPremiumGlyph.closeBox:
      case OperonixPremiumGlyph.labelPrint:
      case OperonixPremiumGlyph.tableColumns:
      case OperonixPremiumGlyph.kpiTotal:
      case OperonixPremiumGlyph.process:
      case OperonixPremiumGlyph.logistics:
      case OperonixPremiumGlyph.orders:
      case OperonixPremiumGlyph.finance:
      case OperonixPremiumGlyph.development:
      case OperonixPremiumGlyph.carbon:
      case OperonixPremiumGlyph.station:
      case OperonixPremiumGlyph.history:
      case OperonixPremiumGlyph.capa:
      case OperonixPremiumGlyph.about:
      case OperonixPremiumGlyph.appearance:
      case OperonixPremiumGlyph.evidence:
      case null:
        return PremiumIconRole.info;
    }
  }
}
