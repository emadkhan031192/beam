import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Beam's icon set: 1.5px stroke, round caps and joins, drawn on a 24×24 grid.
enum BeamIconKind {
  power,
  bolt,
  strobe,
  sos,
  screen,
  gear,
  timer,
  shake,
  bell,
  handTap,
  info,
  external,
  sun,
  close,
  check,
  warning,
  chevronRight,
}

class BeamIcon extends StatelessWidget {
  const BeamIcon(this.kind,
      {super.key, this.size = 24, this.color = const Color(0xFFF2F0EA)});

  final BeamIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BeamIconPainter(kind, color),
    );
  }
}

class _BeamIconPainter extends CustomPainter {
  _BeamIconPainter(this.kind, this.color);

  final BeamIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s, s);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    switch (kind) {
      case BeamIconKind.power:
        // Arc with a gap at top + vertical line.
        path.addArc(const Rect.fromLTWH(6, 7, 12, 12), -0.35 * 3.14159,
            2 * 3.14159 - 0.7 * 3.14159);
        canvas.drawPath(path, p);
        canvas.drawLine(const Offset(12, 4), const Offset(12, 11), p);
      case BeamIconKind.bolt:
        path
          ..moveTo(13, 3)
          ..lineTo(7, 13.5)
          ..lineTo(11, 13.5)
          ..lineTo(10.5, 21)
          ..lineTo(17, 10.5)
          ..lineTo(12.5, 10.5)
          ..close();
        canvas.drawPath(path, p);
      case BeamIconKind.strobe:
        // Zig-zag pulse line.
        path
          ..moveTo(3, 12)
          ..lineTo(7, 12)
          ..lineTo(9.5, 5)
          ..lineTo(14.5, 19)
          ..lineTo(17, 12)
          ..lineTo(21, 12);
        canvas.drawPath(path, p);
      case BeamIconKind.sos:
        // ··· −−− ···  as dots and dashes.
        final dot = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(5.5 + i * 2.6, 8), 1.1, dot);
        }
        canvas.drawLine(const Offset(4.5, 13), const Offset(11.5, 13), p);
        canvas.drawLine(const Offset(12.5, 13), const Offset(19.5, 13), p);
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(5.5 + i * 2.6, 18), 1.1, dot);
        }
      case BeamIconKind.screen:
        final r = RRect.fromLTRBR(4, 6, 20, 17, const Radius.circular(2.5));
        canvas.drawRRect(r, p);
        canvas.drawLine(const Offset(9, 20.5), const Offset(15, 20.5), p);
      case BeamIconKind.gear:
        canvas.drawCircle(const Offset(12, 12), 3.2, p);
        for (var i = 0; i < 8; i++) {
          final a = i * 3.14159 / 4;
          final x1 = 12 + 5.2 * _cos(a), y1 = 12 + 5.2 * _sin(a);
          final x2 = 12 + 7.6 * _cos(a), y2 = 12 + 7.6 * _sin(a);
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);
        }
      case BeamIconKind.timer:
        canvas.drawCircle(const Offset(12, 13), 7, p);
        canvas.drawLine(const Offset(12, 13), const Offset(12, 8.5), p);
        canvas.drawLine(const Offset(12, 13), const Offset(15.5, 14.5), p);
        canvas.drawLine(const Offset(9, 3.5), const Offset(15, 3.5), p);
        canvas.drawLine(const Offset(12, 3.5), const Offset(12, 6), p);
      case BeamIconKind.shake:
        // Phone outline + motion arcs.
        final r = RRect.fromLTRBR(9, 5, 15.5, 19, const Radius.circular(2));
        canvas.drawRRect(r, p);
        canvas.drawLine(const Offset(4.5, 8), const Offset(6.5, 10.5), p);
        canvas.drawLine(const Offset(4.5, 16), const Offset(6.5, 13.5), p);
        canvas.drawLine(const Offset(19.5, 8), const Offset(17.5, 10.5), p);
        canvas.drawLine(const Offset(19.5, 16), const Offset(17.5, 13.5), p);
      case BeamIconKind.bell:
        path
          ..moveTo(6, 16)
          ..lineTo(6, 10.5)
          ..addArc(const Rect.fromLTWH(6, 5, 12, 11), 3.14159, 3.14159)
          ..lineTo(18, 16)
          ..moveTo(4.5, 16)
          ..lineTo(19.5, 16);
        canvas.drawPath(path, p);
        canvas.drawCircle(const Offset(12, 19), 1.2, p);
      case BeamIconKind.handTap:
        // Simplified hand: rounded rect palm + tap arcs.
        final r = RRect.fromLTRBR(7, 10, 15, 19, const Radius.circular(2.5));
        canvas.drawRRect(r, p);
        canvas.drawLine(const Offset(9.5, 10), const Offset(9.5, 7.5), p);
        canvas.drawLine(const Offset(12, 10), const Offset(12, 6), p);
        canvas.drawLine(const Offset(14.5, 10), const Offset(14.5, 7.5), p);
      case BeamIconKind.info:
        canvas.drawCircle(const Offset(12, 12), 7.5, p);
        final dot = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(12, 8.2), 1.1, dot);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 16), p);
      case BeamIconKind.external:
        path
          ..moveTo(10, 5)
          ..lineTo(19, 5)
          ..lineTo(19, 14);
        canvas.drawPath(path, p);
        canvas.drawLine(const Offset(19, 5), const Offset(11, 13), p);
        final r = RRect.fromLTRBR(5, 9, 14, 19, const Radius.circular(2));
        canvas.drawRRect(r, p);
      case BeamIconKind.sun:
        canvas.drawCircle(const Offset(12, 12), 4, p);
        for (var i = 0; i < 8; i++) {
          final a = i * 3.14159 / 4;
          canvas.drawLine(
            Offset(12 + 6 * _cos(a), 12 + 6 * _sin(a)),
            Offset(12 + 8 * _cos(a), 12 + 8 * _sin(a)),
            p,
          );
        }
      case BeamIconKind.close:
        canvas.drawLine(const Offset(6, 6), const Offset(18, 18), p);
        canvas.drawLine(const Offset(18, 6), const Offset(6, 18), p);
      case BeamIconKind.check:
        path
          ..moveTo(5, 12.5)
          ..lineTo(10.5, 18)
          ..lineTo(19, 7);
        canvas.drawPath(path, p);
      case BeamIconKind.warning:
        path
          ..moveTo(12, 4)
          ..lineTo(21, 19.5)
          ..lineTo(3, 19.5)
          ..close();
        canvas.drawPath(path, p);
        canvas.drawLine(const Offset(12, 9.5), const Offset(12, 14), p);
        final dot = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(const Offset(12, 16.8), 1.0, dot);
      case BeamIconKind.chevronRight:
        path
          ..moveTo(9.5, 6)
          ..lineTo(15.5, 12)
          ..lineTo(9.5, 18);
        canvas.drawPath(path, p);
    }
  }

  double _cos(double a) => math.cos(a);
  double _sin(double a) => math.sin(a);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
