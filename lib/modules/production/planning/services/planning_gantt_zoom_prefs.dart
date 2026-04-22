import 'package:shared_preferences/shared_preferences.dart';

/// Unaprijed zadane ljestvice vremena na Gantt grafikonu (isti horizont, drugačija širina piksela).
enum PlanningGanttZoomPreset {
  hour,
  shift,
  day,
  week;

  String get storageValue => name;

  double get widthMultiplier => switch (this) {
        PlanningGanttZoomPreset.hour => 1.75,
        PlanningGanttZoomPreset.shift => 1.32,
        PlanningGanttZoomPreset.day => 1.0,
        PlanningGanttZoomPreset.week => 0.62,
      };

  static PlanningGanttZoomPreset? fromStorage(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return switch (raw) {
      'hour' => PlanningGanttZoomPreset.hour,
      'shift' => PlanningGanttZoomPreset.shift,
      'day' => PlanningGanttZoomPreset.day,
      'week' => PlanningGanttZoomPreset.week,
      _ => null,
    };
  }
}

/// Pohrana zadnjeg Gantt zooma po pogonu (korisnik / uređaj).
class PlanningGanttZoomPrefs {
  PlanningGanttZoomPrefs._();

  static String _seg(String s) {
    if (s.isEmpty) return 'x';
    return s.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static String _key(String companyId, String plantKey) =>
      'planning_gantt_zoom_v1_${_seg(companyId)}_${_seg(plantKey)}';

  static Future<PlanningGanttZoomPreset?> read(String companyId, String plantKey) async {
    if (companyId.isEmpty && plantKey.isEmpty) return null;
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key(companyId, plantKey));
    return PlanningGanttZoomPreset.fromStorage(v);
  }

  static Future<void> write(
    String companyId,
    String plantKey,
    PlanningGanttZoomPreset preset,
  ) async {
    if (companyId.isEmpty && plantKey.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(companyId, plantKey), preset.storageValue);
  }
}
