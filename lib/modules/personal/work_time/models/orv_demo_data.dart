import 'package:flutter/foundation.dart';

/// Demo podaci za ORV mrežu (dnevna evidencija) — kasnije Firestore: events + schedules + daily_summary.
@immutable
class OrvDemoEmployee {
  const OrvDemoEmployee({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.rowHasDataError = false,
  });

  final String id;
  final String lastName;
  final String firstName;
  final bool rowHasDataError;
}

@immutable
class OrvClockEvent {
  const OrvClockEvent({
    required this.day,
    required this.timeLabel,
    required this.type,
    this.device = '1',
  });

  final int day;
  final String timeLabel;
  /// 'K' ulaz, 'G' izlaz, …
  final String type;
  final String device;
}

@immutable
class OrvDayLane {
  const OrvDayLane({
    required this.day,
    required this.dayLabel,
    required this.isWeekend,
    required this.zrv,
    required this.zrvStartLabel,
    required this.zrvEndLabel,
    this.absence = '',
    this.hasRowError = false,
    this.scheduleFromHour = 0.0,
    this.scheduleToHour = 0.0,
    this.workFromHour = 0.0,
    this.workToHour = 0.0,
  });

  final int day;
  final String dayLabel;
  final bool isWeekend;
  final String zrv;
  final String zrvStartLabel;
  final String zrvEndLabel;
  final String absence;
  final bool hasRowError;
  /// Plan (ZRV) 0..24.
  final double scheduleFromHour;
  final double scheduleToHour;
  /// Ostvareni rad 0..24.
  final double workFromHour;
  final double workToHour;

  /// Stvarni početak prije planirane smjene (rani dolazak otkučan).
  bool get hasEarlyClockIn {
    if (scheduleToHour <= scheduleFromHour) {
      return false;
    }
    if (workToHour <= workFromHour) {
      return false;
    }
    return workFromHour < scheduleFromHour;
  }
}

class OrvDemoData {
  OrvDemoData._();

  static const List<OrvDemoEmployee> employees = <OrvDemoEmployee>[
    OrvDemoEmployee(
      id: 'RAD_1',
      lastName: 'Ivić',
      firstName: 'Ana',
    ),
    OrvDemoEmployee(
      id: 'RAD_2',
      lastName: 'Jurić',
      firstName: 'Marko',
    ),
    OrvDemoEmployee(
      id: 'RAD_3',
      lastName: 'Klarić',
      firstName: 'Ivan',
      rowHasDataError: true,
    ),
  ];

  static List<OrvClockEvent> eventsFor({required int year, required int month}) {
    // Primjer: odabrani dan 24. — problem (neispravno)
    return const <OrvClockEvent>[
      OrvClockEvent(day: 1, timeLabel: '13:35', type: 'K', device: '1'),
      OrvClockEvent(day: 1, timeLabel: '22:00', type: 'G', device: '1'),
    ];
  }

  /// Dijelovi mjeseca za scroll (u produkciji: svi dani 1..lastDay).
  static List<OrvDayLane> daysFor(
    int year,
    int month,
  ) {
    const names = <String>['sri', 'čet', 'pet', 'sub', 'ned', 'pon', 'uto'];
    final last = DateTime(year, month + 1, 0).day;
    final out = <OrvDayLane>[];
    for (var d = 1; d <= last; d++) {
      if (d == 24) {
        final dt = DateTime(year, month, 24);
        final wd = names[dt.weekday - 1];
        out.add(
          OrvDayLane(
            day: 24,
            dayLabel: '24 $wd',
            isWeekend: false,
            zrv: 'II-14',
            zrvStartLabel: '14:00',
            zrvEndLabel: '22:00',
            absence: '—',
            hasRowError: true,
            scheduleFromHour: 14,
            scheduleToHour: 22,
            workFromHour: 0,
            workToHour: 0,
          ),
        );
        continue;
      }
      final dt = DateTime(year, month, d);
      final wd = names[dt.weekday - 1];
      final wend = dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
      // Primjer: smjena II-14 14:00–22:00, crvena traka poklapa
      if (d == 1) {
        out.add(
          OrvDayLane(
            day: d,
            dayLabel: '${d.toString().padLeft(2, '0')} $wd',
            isWeekend: wend,
            zrv: 'II-14',
            zrvStartLabel: '14:00',
            zrvEndLabel: '22:00',
            scheduleFromHour: 14,
            scheduleToHour: 22,
            // Rani otkučaj (npr. 13:30) — za demonstraciju upozorenja u pravilima
            workFromHour: 13.5,
            workToHour: 22,
            hasRowError: false,
          ),
        );
      } else {
        out.add(
          OrvDayLane(
            day: d,
            dayLabel: '${d.toString().padLeft(2, '0')} $wd',
            isWeekend: wend,
            zrv: d % 2 == 0 ? 'I-6' : 'II-14',
            zrvStartLabel: d % 2 == 0 ? '06:00' : '14:00',
            zrvEndLabel: d % 2 == 0 ? '14:00' : '22:00',
            scheduleFromHour: d % 2 == 0 ? 6 : 14,
            scheduleToHour: d % 2 == 0 ? 14 : 22,
            workFromHour: d % 2 == 0 ? 6.25 : 14,
            workToHour: d % 2 == 0 ? 14 : 22,
            hasRowError: false,
            absence: wend ? '—' : '',
          ),
        );
      }
    }
    return out;
  }
}

enum OrvListFilter { all, marked, invalid }
