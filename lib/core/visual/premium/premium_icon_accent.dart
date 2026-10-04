import 'package:flutter/material.dart';

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

  static Color of(PremiumIconRole role) {
    switch (role) {
      case PremiumIconRole.info:
        return info;
      case PremiumIconRole.success:
        return success;
      case PremiumIconRole.warning:
        return warning;
      case PremiumIconRole.active:
        return active;
      case PremiumIconRole.quality:
        return quality;
      case PremiumIconRole.lab:
        return lab;
      case PremiumIconRole.material:
        return material;
      case PremiumIconRole.people:
        return people;
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
    return PremiumIconRole.info;
  }
}
