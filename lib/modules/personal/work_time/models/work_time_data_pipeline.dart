/// Arhitektura toka podataka: **slojevi 1–3** — platno-relevantan ishod
/// nikad izravno iz sirovih događaja.
///
/// ```
/// LAN / gateway
///   ↓
/// work_time_events          (1) sirovo
///   ↓  Cloud Function obrada
/// work_time_daily_summary   (2) dnevni agregat
///   ↓
/// work_time_monthly_summary (3) mjesec za platu
///   ↓
/// payroll_exports           isporuka van (metapodaci + fajl)
/// ```
///
/// Ako treba IATF / korekcija / re-run, sirovina (1) ostaje; mjenjaju se (2) i/ili (3).
///
/// Puna norma: `maintenance_app/docs/architecture/archive/2026-04-24_TIME_AND_ATTENDANCE_PAYROLL_MODULE.md` §14.
enum WorkTimeCalculationLayer {
  /// `work_time_events`
  events,

  /// `work_time_daily_summary`
  dailySummary,

  /// `work_time_monthly_summary` (+ izvoz, ne agregat)
  monthlySummary,
}
