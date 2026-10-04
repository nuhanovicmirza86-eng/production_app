import 'package:flutter/material.dart';

import '../operonix_visual_tokens.dart';

/// Semantička porodica Premium ikona. Boja nije jedini nosilac značenja.
enum PremiumIconRole {
  info,
  success,
  warning,
  active,
  quality,
  lab,
  material,
  people,
  analytics,
  critical,
}

class PremiumIconAccent {
  const PremiumIconAccent._();

  static const Color info = Color(0xFF5B9DFF);
  static const Color success = Color(0xFF3DCF8C);
  static const Color warning = Color(0xFFE0A106);
  static const Color active = Color(0xFFFF7043);
  static const Color quality = Color(0xFF4CC3E0);
  static const Color lab = Color(0xFF2BB8C8);
  static const Color material = Color(0xFFE0A106);
  static const Color people = Color(0xFF3D9A94);
  static const Color analytics = Color(0xFF9B8CFF);
  static const Color critical = Color(0xFFE5484D);

  static const Color _midnightAccent = Color(0xFF3D9A94);

  static Color of(PremiumIconRole role, [OperonixVisualTokens? tokens]) {
    final base = switch (role) {
      PremiumIconRole.info => info,
      PremiumIconRole.success => success,
      PremiumIconRole.warning => warning,
      PremiumIconRole.active => active,
      PremiumIconRole.quality => quality,
      PremiumIconRole.lab => lab,
      PremiumIconRole.material => material,
      PremiumIconRole.people => people,
      PremiumIconRole.analytics => analytics,
      PremiumIconRole.critical => critical,
    };
    final accent = tokens?.primaryAccent;
    if (accent == null || accent == _midnightAccent) {
      return base;
    }
    var tone = base;
    final background = tokens?.background;
    if (background != null && background.computeLuminance() > 0.45) {
      tone = Color.lerp(base, const Color(0xFF102030), 0.42)!;
    }
    final mix = switch (role) {
      PremiumIconRole.warning ||
      PremiumIconRole.active ||
      PremiumIconRole.success ||
      PremiumIconRole.critical =>
        0.18,
      _ => 0.45,
    };
    return Color.lerp(tone, accent, mix)!;
  }

  static String familyLabel(PremiumIconRole role) {
    switch (role) {
      case PremiumIconRole.info:
        return 'Kontekst';
      case PremiumIconRole.success:
        return 'Proizvodnja';
      case PremiumIconRole.warning:
        return 'Pažnja';
      case PremiumIconRole.active:
        return 'Operacija';
      case PremiumIconRole.quality:
        return 'Kvalitet';
      case PremiumIconRole.lab:
        return 'Laboratorija';
      case PremiumIconRole.material:
        return 'Materijal';
      case PremiumIconRole.people:
        return 'Administracija';
      case PremiumIconRole.analytics:
        return 'Analitika';
      case PremiumIconRole.critical:
        return 'Kritično';
    }
  }

  static PremiumIconRole forProfile(String profileKey) {
    switch (profileKey.trim()) {
      case 'chemical_dosing':
      case 'wastewater_treatment':
        return PremiumIconRole.lab;
      case 'production_counting':
        return PremiumIconRole.success;
      case 'in_process_quality_check':
      case 'final_control':
      case 'first_piece_approval':
      case 'packaging_control':
        return PremiumIconRole.quality;
      case 'material_preparation':
      case 'operation_material_preparation':
        return PremiumIconRole.material;
      case 'line_clearance':
        return PremiumIconRole.active;
      case 'workspace_5s_cleaning':
        return PremiumIconRole.success;
      default:
        return PremiumIconRole.info;
    }
  }

  static PremiumIconRole forIcon(IconData icon) {
    if (icon == Icons.science_outlined || icon == Icons.water_outlined) {
      return PremiumIconRole.lab;
    }
    if (icon == Icons.fact_check_outlined ||
        icon == Icons.verified_outlined ||
        icon == Icons.verified_user_outlined ||
        icon == Icons.assignment_turned_in_outlined) {
      return PremiumIconRole.quality;
    }
    if (icon == Icons.inventory_outlined ||
        icon == Icons.inventory_2_outlined ||
        icon == Icons.precision_manufacturing_outlined) {
      return PremiumIconRole.material;
    }
    if (icon == Icons.groups_outlined ||
        icon == Icons.groups_2_outlined ||
        icon == Icons.person_add_alt_1_outlined ||
        icon == Icons.badge_outlined) {
      return PremiumIconRole.people;
    }
    if (icon == Icons.task_alt_rounded ||
        icon == Icons.eco_outlined ||
        icon == Icons.check_circle_outline) {
      return PremiumIconRole.success;
    }
    if (icon == Icons.pending_actions_outlined ||
        icon == Icons.warning_amber_outlined) {
      return PremiumIconRole.warning;
    }
    if (icon == Icons.play_circle_outline ||
        icon == Icons.play_circle ||
        icon == Icons.account_tree_outlined) {
      return PremiumIconRole.active;
    }
    if (icon == Icons.insights_outlined ||
        icon == Icons.query_stats_outlined ||
        icon == Icons.picture_as_pdf_outlined ||
        icon == Icons.analytics_outlined) {
      return PremiumIconRole.analytics;
    }
    return PremiumIconRole.info;
  }
}
