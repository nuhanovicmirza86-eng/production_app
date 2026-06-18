import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../finance_system_bottom_inset.dart';

/// Premium rubna chat kugla — tamnozelena, lako dodirljiva, blago iza ruba ekrana.
class FinanceAssistantEdgeHandle extends StatefulWidget {
  const FinanceAssistantEdgeHandle({
    super.key,
    required this.onPressed,
    this.scrollCompact = false,
  });

  final Future<void> Function() onPressed;

  /// Pri skrolanju blago smanjuje opacity, ne i dodirnu zonu ni veličinu.
  final bool scrollCompact;

  static const touchSize = 56.0;
  static const bubbleSize = 42.0;
  static const edgePeek = 7.0;
  static const iconSize = 23.0;
  static const starSize = 10.0;
  static const brandColor = Color(0xFF164344);
  static const starColor = Color(0xFF3DCF8C);
  static const defaultTopRatio = 0.65;
  static const scrollOpacity = 0.9;

  static const _prefSide = 'finance_assistant_edge_side_v1';
  static const _prefTopRatio = 'finance_assistant_edge_top_ratio_v1';

  @override
  State<FinanceAssistantEdgeHandle> createState() =>
      _FinanceAssistantEdgeHandleState();
}

class _FinanceAssistantEdgeHandleState extends State<FinanceAssistantEdgeHandle> {
  bool _loaded = false;
  bool _onRight = true;
  double _topRatio = FinanceAssistantEdgeHandle.defaultTopRatio;
  bool _dragging = false;
  double? _dragTop;
  double? _dragStartTop;
  DateTime? _suppressTapUntil;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final side = prefs.getString(FinanceAssistantEdgeHandle._prefSide);
    final ratio = prefs.getDouble(FinanceAssistantEdgeHandle._prefTopRatio);
    if (!mounted) return;
    setState(() {
      _onRight = side != 'left';
      if (ratio != null && ratio.isFinite) {
        _topRatio = ratio.clamp(0.12, 0.88);
      }
      _loaded = true;
    });
  }

  Future<void> _savePosition({bool? onRight, double? topRatio}) async {
    final prefs = await SharedPreferences.getInstance();
    if (onRight != null) {
      await prefs.setString(
        FinanceAssistantEdgeHandle._prefSide,
        onRight ? 'right' : 'left',
      );
    }
    if (topRatio != null) {
      await prefs.setDouble(FinanceAssistantEdgeHandle._prefTopRatio, topRatio);
    }
  }

  double _bottomLift(BuildContext context) {
    return FinanceSystemBottomInset.edgeHandleBottom(context);
  }

  _HandleMetrics _metrics(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topSafe = mq.viewPadding.top + 8;
    final bottomLift = _bottomLift(context);
    final maxTopSpan = (mq.size.height -
            bottomLift -
            FinanceAssistantEdgeHandle.touchSize -
            topSafe)
        .clamp(0.0, double.infinity);
    final top = _dragging && _dragTop != null
        ? _dragTop!.clamp(topSafe, topSafe + maxTopSpan)
        : topSafe + _topRatio * maxTopSpan;
    return _HandleMetrics(
      top: top,
      topSafe: topSafe,
      maxTopSpan: maxTopSpan,
    );
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final m = _metrics(context);
    setState(() {
      _dragging = true;
      _dragStartTop = m.top;
      _dragTop = m.top;
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_dragging || _dragStartTop == null) return;
    final m = _metrics(context);
    setState(() {
      _dragTop = (_dragStartTop! + details.offsetFromOrigin.dy)
          .clamp(m.topSafe, m.topSafe + m.maxTopSpan);
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_dragging) return;
    final mq = MediaQuery.of(context);
    final onRight = details.globalPosition.dx >= mq.size.width / 2;
    final m = _metrics(context);
    final top = (_dragTop ?? m.top).clamp(m.topSafe, m.topSafe + m.maxTopSpan);
    final ratio =
        m.maxTopSpan > 0 ? (top - m.topSafe) / m.maxTopSpan : _topRatio;
    setState(() {
      _dragging = false;
      _dragTop = null;
      _dragStartTop = null;
      _onRight = onRight;
      _topRatio = ratio;
      _suppressTapUntil = DateTime.now().add(const Duration(milliseconds: 250));
    });
    unawaited(_savePosition(onRight: onRight, topRatio: ratio));
  }

  Future<void> _handleTap() async {
    if (_dragging) return;
    if (_suppressTapUntil != null &&
        DateTime.now().isBefore(_suppressTapUntil!)) {
      return;
    }
    await widget.onPressed();
  }

  Widget _buildBubble({required double opacity}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: opacity,
      child: Container(
        width: FinanceAssistantEdgeHandle.bubbleSize,
        height: FinanceAssistantEdgeHandle.bubbleSize,
        decoration: BoxDecoration(
          color: FinanceAssistantEdgeHandle.brandColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: FinanceAssistantEdgeHandle.iconSize,
              color: Colors.white,
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.auto_awesome,
                size: FinanceAssistantEdgeHandle.starSize,
                color: FinanceAssistantEdgeHandle.starColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final m = _metrics(context);
    final scrollDimmed = widget.scrollCompact && !_dragging;
    final bubbleOpacity =
        scrollDimmed ? FinanceAssistantEdgeHandle.scrollOpacity : 1.0;
    final edgeOffset = FinanceAssistantEdgeHandle.edgePeek;

    return Positioned(
      top: m.top,
      left: _onRight ? null : -edgeOffset,
      right: _onRight ? -edgeOffset : null,
      child: SizedBox(
        width: FinanceAssistantEdgeHandle.touchSize,
        height: FinanceAssistantEdgeHandle.touchSize,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: _onLongPressEnd,
          child: Align(
            alignment: _onRight
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: _buildBubble(opacity: bubbleOpacity),
          ),
        ),
      ),
    );
  }
}

class _HandleMetrics {
  const _HandleMetrics({
    required this.top,
    required this.topSafe,
    required this.maxTopSpan,
  });

  final double top;
  final double topSafe;
  final double maxTopSpan;
}
