import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:production_app/modules/personal/work_time/models/orv_demo_data.dart';

/// Grupa: jedan horizontalni [offset] za zaglavlje sati i sve trake dana.
class _OrvHorizontalScrollGroup {
  _OrvHorizontalScrollGroup(this._count) {
    for (var i = 0; i < _count; i++) {
      final c = ScrollController();
      c.addListener(() => _onScroll(c));
      _controllers.add(c);
    }
  }

  final int _count;
  final List<ScrollController> _controllers = <ScrollController>[];
  bool _syncing = false;

  ScrollController operator [](int i) => _controllers[i];

  void _onScroll(ScrollController source) {
    if (_syncing) {
      return;
    }
    if (!source.hasClients) {
      return;
    }
    _syncing = true;
    final t = source.offset;
    for (final c in _controllers) {
      if (!identical(c, source) && c.hasClients) {
        final maxO = c.position.maxScrollExtent;
        c.jumpTo(t.clamp(0.0, maxO));
      }
    }
    _syncing = false;
  }

  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
  }
}

/// Mjesečna mreža: lijevo tablične kolone (kao u klasičnom ORV), desno 0–24 s
/// **sivom** trakom = plan (ZRV) i **crvenom** = stvaran rad; vertikalno skrolanje zajedno.
class OrvWorkTimeTimeline extends StatefulWidget {
  const OrvWorkTimeTimeline({
    super.key,
    required this.lanes,
  });

  final List<OrvDayLane> lanes;

  static const double _rowH = 38;
  static const double _wDan = 48;
  static const double _wZrv = 56;
  static const double _wZrvStart = 52;
  static const double _wZrvEnd = 52;
  static const double _wAbs = 64;
  static const double _leftPad = 6;
  static double get _leftTotal =>
      _leftPad * 2 + _wDan + _wZrv + _wZrvStart + _wZrvEnd + _wAbs;
  static const double _hourW = 24;
  static double get _timelineW => 24 * _hourW;

  @override
  State<OrvWorkTimeTimeline> createState() => _OrvWorkTimeTimelineState();
}

class _OrvWorkTimeTimelineState extends State<OrvWorkTimeTimeline> {
  _OrvHorizontalScrollGroup? _group;

  @override
  void initState() {
    super.initState();
    _initGroup();
  }

  @override
  void didUpdateWidget(OrvWorkTimeTimeline old) {
    super.didUpdateWidget(old);
    if (old.lanes.length != widget.lanes.length) {
      setState(_initGroup);
    }
  }

  void _initGroup() {
    _group?.dispose();
    _group = _OrvHorizontalScrollGroup(1 + widget.lanes.length);
  }

  @override
  void dispose() {
    _group?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    if (g == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final hours = List<int>.generate(24, (i) => i);
    return Card(
      margin: const EdgeInsets.only(top: 6),
      clipBehavior: Clip.antiAlias,
      child: ScrollConfiguration(
        behavior: const _OrvScrollBehavior(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              controller: g[0],
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _leftHeaderTable(theme),
                  SizedBox(
                    width: OrvWorkTimeTimeline._timelineW,
                    child: Row(
                      children: [
                        for (final h in hours)
                          SizedBox(
                            width: OrvWorkTimeTimeline._hourW,
                            child: Center(
                              child: Text(
                                h.toString().padLeft(2, '0'),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: widget.lanes.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  return _dayRow(
                    context,
                    widget.lanes[i],
                    g[i + 1],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftHeaderTable(ThemeData theme) {
    final t = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      width: OrvWorkTimeTimeline._leftTotal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrvWorkTimeTimeline._leftPad, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: OrvWorkTimeTimeline._wDan,
              child: Text('Dan', maxLines: 2, style: t),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wZrv,
              child: Text('Plan h', maxLines: 2, style: t),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wZrvStart,
              child: Text('Plan\npočetak', maxLines: 2, style: t, softWrap: true),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wZrvEnd,
              child: Text('Plan\nkraj', maxLines: 2, style: t, softWrap: true),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wAbs,
              child: Text('Odsustvo', maxLines: 2, style: t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(
    BuildContext context,
    OrvDayLane l,
    ScrollController hController,
  ) {
    final theme = Theme.of(context);
    final weekendBg = l.isWeekend ? const Color(0xFFE3F2FD) : null;
    final errBg = l.hasRowError ? const Color(0xFFFFEBEE) : null;

    return Material(
      color: errBg ?? weekendBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _leftDataRow(theme, l),
          Expanded(
            child: SingleChildScrollView(
              controller: hController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: OrvWorkTimeTimeline._timelineW,
                height: OrvWorkTimeTimeline._rowH,
                child: OrvShiftTimeband(
                  scheduleFromHour: l.scheduleFromHour,
                  scheduleToHour: l.scheduleToHour,
                  workFromHour: l.workFromHour,
                  workToHour: l.workToHour,
                  hasError: l.hasRowError,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _leftDataRow(ThemeData theme, OrvDayLane l) {
    final t = theme.textTheme.labelSmall;
    return SizedBox(
      width: OrvWorkTimeTimeline._leftTotal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: OrvWorkTimeTimeline._leftPad, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: OrvWorkTimeTimeline._wDan,
              child: Text(l.dayLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: t),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wZrv,
              child: Text(l.zrv, maxLines: 1, overflow: TextOverflow.ellipsis, style: t),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wZrvStart,
              child: Text(l.zrvStartLabel, maxLines: 1, style: t),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wZrvEnd,
              child: Text(l.zrvEndLabel, maxLines: 1, style: t),
            ),
            SizedBox(
              width: OrvWorkTimeTimeline._wAbs,
              child: Text(
                l.absence.isEmpty ? '—' : l.absence,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrvScrollBehavior extends MaterialScrollBehavior {
  const _OrvScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Siva traka = planirana smjena, crvena = stvarni rad. Mreža 24 h.
class OrvShiftTimeband extends StatelessWidget {
  const OrvShiftTimeband({
    super.key,
    required this.scheduleFromHour,
    required this.scheduleToHour,
    required this.workFromHour,
    required this.workToHour,
    required this.hasError,
  });

  final double scheduleFromHour;
  final double scheduleToHour;
  final double workFromHour;
  final double workToHour;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        final hasSched = scheduleToHour > scheduleFromHour;
        final hasWork = workToHour > workFromHour;

        if (hasError && !hasWork && hasSched) {
          return _bandStack(
            context,
            w,
            h,
            hasSched: hasSched,
            hasWork: false,
            sFrom: scheduleFromHour,
            sTo: scheduleToHour,
            wFrom: 0,
            wTo: 0,
            showErrorIcon: true,
          );
        }

        if (hasError && !hasWork && !hasSched) {
          return Center(
            child: Icon(
              Icons.error_outline,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
          );
        }

        if (!hasSched && !hasWork) {
          return const SizedBox.shrink();
        }

        return _bandStack(
          context,
          w,
          h,
          hasSched: hasSched,
          hasWork: hasWork,
          sFrom: scheduleFromHour,
          sTo: scheduleToHour,
          wFrom: workFromHour,
          wTo: workToHour,
          showErrorIcon: hasError && hasWork,
        );
      },
    );
  }

  Widget _bandStack(
    BuildContext context,
    double w,
    double h, {
    required bool hasSched,
    required bool hasWork,
    required double sFrom,
    required double sTo,
    required double wFrom,
    required double wTo,
    required bool showErrorIcon,
  }) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        CustomPaint(
          size: Size(w, h),
          painter: _HourDividersPainter(
            lineColor: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            hourWidth: w / 24,
          ),
        ),
        if (hasSched && sTo > sFrom)
          _barPosition(
            w,
            h,
            sFrom,
            sTo,
            top: 8,
            height: 12,
            color: const Color(0xFFB0BEC5),
            border: const Color(0xFF90A4AE),
          ),
        if (hasWork && wTo > wFrom)
          _barPosition(
            w,
            h,
            wFrom,
            wTo,
            top: 9,
            height: 10,
            color: Colors.red.shade200,
            border: Colors.red.shade600,
          ),
        if (showErrorIcon)
          Positioned(
            right: 2,
            top: 0,
            child: Icon(
              Icons.error_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }

  Widget _barPosition(
    double w,
    double h,
    double fromH,
    double toH, {
    required double top,
    required double height,
    required Color color,
    required Color border,
  }) {
    final left = (fromH / 24.0) * w;
    final barW = ((toH - fromH) / 24.0) * w;
    if (!left.isFinite || !barW.isFinite) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: left.clamp(0, w - 1),
      top: top,
      width: barW.clamp(2, w),
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: border, width: 0.8),
        ),
      ),
    );
  }
}

class _HourDividersPainter extends CustomPainter {
  _HourDividersPainter({
    required this.lineColor,
    required this.hourWidth,
  });

  final Color lineColor;
  final double hourWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 24; i++) {
      final x = i * hourWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant _HourDividersPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || oldDelegate.hourWidth != hourWidth;
  }
}

/// Kompat: stari [OrvTimeRangeBar] u jednoj traci — uklonjen, ostaje [OrvShiftTimeband].
