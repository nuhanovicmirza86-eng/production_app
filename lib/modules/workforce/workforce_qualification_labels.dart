import 'package:flutter/material.dart';

abstract final class WorkforceQualificationLabels {
  static const machine = 'machine';
  static const process = 'process';
  static const operation = 'operation';

  static String dimensionTypeLabel(String code) {
    switch (code.trim()) {
      case machine:
        return 'Stroj';
      case process:
        return 'Proces';
      case operation:
        return 'Operacija';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static String dimensionTypeToCode(String label) {
    switch (label.trim()) {
      case 'Stroj':
        return machine;
      case 'Proces':
        return process;
      case 'Operacija':
        return operation;
      default:
        return label.trim();
    }
  }

  static List<DropdownMenuItem<String>> dimensionTypeItems() {
    return const [machine, process, operation]
        .map(
          (code) => DropdownMenuItem(
            value: code,
            child: Text(dimensionTypeLabel(code)),
          ),
        )
        .toList();
  }

  static String statusLabel(String code) {
    switch (code.trim()) {
      case 'qualified':
        return 'Kvalificiran';
      case 'in_training':
        return 'U obuci';
      case 'not_qualified':
        return 'Nije kvalificiran';
      case 'expired':
        return 'Isteklo';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static String approvalLabel(String code) {
    switch (code.trim()) {
      case 'approved':
        return 'Odobreno';
      case 'pending_approval':
        return 'Čeka odobrenje';
      case 'rejected':
        return 'Odbijeno';
      default:
        return code.trim().isEmpty ? '—' : code.trim();
    }
  }

  static List<DropdownMenuItem<String>> statusItems() {
    return const [
      'qualified',
      'in_training',
      'not_qualified',
      'expired',
    ]
        .map(
          (code) => DropdownMenuItem(
            value: code,
            child: Text(statusLabel(code)),
          ),
        )
        .toList();
  }

  static List<DropdownMenuItem<String>> approvalItems() {
    return const ['approved', 'pending_approval']
        .map(
          (code) => DropdownMenuItem(
            value: code,
            child: Text(approvalLabel(code)),
          ),
        )
        .toList();
  }
}
