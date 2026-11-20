import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A stick on the touch screen for a handheld without physical ones: drag the knob, release and
/// it springs back to the middle. Reports x right +, y up +, each -1..1.
class TouchStick extends StatefulWidget {
  const TouchStick({
    super.key,
    required this.onChanged,
    this.size = 128,
    this.horizontalOnly = false,
    this.label,
  });

  final ValueChanged<Offset> onChanged;
  final double size;

  /// Only left and right (the turn stick).
  final bool horizontalOnly;
  final String? label;

  @override
  State<TouchStick> createState() => _TouchStickState();
}

class _TouchStickState extends State<TouchStick> {
  Offset _value = Offset.zero;

  void _move(Offset local) {
    final radius = widget.size / 2;
    var delta = (local - Offset(radius, radius)) / radius;
    if (widget.horizontalOnly) delta = Offset(delta.dx, 0);
    final length = delta.distance;
    if (length > 1) delta = delta / length;
    setState(() => _value = Offset(delta.dx, -delta.dy));
    widget.onChanged(_value);
  }

  void _release() {
    setState(() => _value = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) => _move(details.localPosition),
      onPanUpdate: (details) => _move(details.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _StickPainter(_value, widget.horizontalOnly),
          child: widget.label == null
              ? null
              : Align(
                  alignment: const Alignment(0, 0.92),
                  child: Text(widget.label!, style: Txt.small),
                ),
        ),
      ),
    );
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter(this.value, this.horizontalOnly);

  final Offset value;
  final bool horizontalOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ring = Paint()..color = const Color(0x33FFFFFF);
    if (horizontalOnly) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: size.width, height: radius * 0.7),
          Radius.circular(radius * 0.35),
        ),
        ring,
      );
    } else {
      canvas.drawCircle(center, radius, ring);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Palette.line,
    );
    final knob = radius * 0.36;
    final reach = radius - knob;
    final at = center + Offset(value.dx * reach, -value.dy * reach);
    final active = math.max(value.dx.abs(), value.dy.abs()) > 0.05;
    canvas.drawCircle(at, knob, Paint()..color = active ? Palette.remote : const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(_StickPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.horizontalOnly != horizontalOnly;
}
