import 'package:flutter/material.dart';

/// Operativni status prisutnosti — kanonski kod u bazi, bosanski prikaz u UI-u.
abstract final class WorkforceAttendanceLabels {
  static const present = 'present';
  static const absent = 'absent';
  static const late = 'late';
  static const leaveOperational = 'leave_operational';
  static const unknown = 'unknown';

  static String label(String code) {
    switch (code.trim()) {
      case present:
        return 'Prisutan';
      case absent:
        return 'Odsutan';
      case late:
        return 'Kašnjenje';
      case leaveOperational:
        return 'Odsustvo (operativno)';
      case unknown:
        return 'Nepoznato';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static List<DropdownMenuItem<String>> dropdownItems() {
    return const [
      present,
      absent,
      late,
      leaveOperational,
      unknown,
    ]
        .map(
          (code) => DropdownMenuItem(
            value: code,
            child: Text(label(code)),
          ),
        )
        .toList();
  }

  static List<PopupMenuEntry<String>> popupEntries() {
    return const [
      present,
      absent,
      late,
      leaveOperational,
    ]
        .map(
          (code) => PopupMenuItem<String>(
            value: code,
            child: Text(label(code)),
          ),
        )
        .toList();
  }
}
