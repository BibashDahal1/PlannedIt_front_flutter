import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sketch_colors.dart';

Path _sketchRoundedRectPath(
  Rect rect,
  double radius,
  math.Random rnd, {
  required double jitter,
  required double step,
}) {
  final base = Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  final points = <Offset>[];
  for (final metric in base.computeMetrics()) {
    var distance = rnd.nextDouble() * step;
    while (distance < metric.length) {
      final tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        final offset = (rnd.nextDouble() * 2 - 1) * jitter;
        points.add(tangent.position + normal * offset);
      }
      distance += step + rnd.nextDouble() * (step * 0.6);
    }
  }
  if (points.length < 3) return base;

  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    final p0 = points[i - 1];
    final p1 = points[i];
    final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
  }
  path.close();
  return path;
}

class _SketchRectPainter extends CustomPainter {
  final double radius;
  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  final int seed;

  _SketchRectPainter({
    required this.radius,
    required this.strokeColor,
    required this.fillColor,
    required this.strokeWidth,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (fillColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(strokeWidth),
          Radius.circular(radius),
        ),
        Paint()..color = fillColor!,
      );
    }
    final rnd = math.Random(seed);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Two jittered passes, slightly offset in weight/alpha, is what
    // reads as "drawn twice by hand" rather than a single clean stroke.
    canvas.drawPath(
      _sketchRoundedRectPath(
        rect.deflate(strokeWidth / 2),
        radius,
        rnd,
        jitter: 1.1,
        step: 9,
      ),
      basePaint
        ..strokeWidth = strokeWidth
        ..color = strokeColor.withValues(alpha: 0.85),
    );
    canvas.drawPath(
      _sketchRoundedRectPath(
        rect.deflate(strokeWidth / 2),
        radius,
        rnd,
        jitter: 1.4,
        step: 11,
      ),
      basePaint
        ..strokeWidth = strokeWidth * 0.7
        ..color = strokeColor.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _SketchRectPainter old) =>
      old.radius != radius ||
      old.strokeColor != strokeColor ||
      old.fillColor != fillColor ||
      old.seed != seed;
}

const Color _themePaper = Color(0x00010203);

class SketchBox extends StatelessWidget {
  final Widget? child;
  final double radius;
  final double strokeWidth;
  final Color? strokeColor; // null -> SketchColors.ink
  final Color? fill; // _themePaper -> SketchColors.paper, null -> none
  final EdgeInsetsGeometry padding;
  final int seed;
  final double? width;
  final double? height;

  const SketchBox({
    super.key,
    this.child,
    this.radius = 14,
    this.strokeWidth = 1.6,
    this.strokeColor,
    this.fill = _themePaper,
    this.padding = EdgeInsets.zero,
    this.seed = 1,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return CustomPaint(
      painter: _SketchRectPainter(
        radius: radius,
        strokeColor: strokeColor ?? SketchColors.ink,
        fillColor: identical(fill, _themePaper) ? SketchColors.paper : fill,
        strokeWidth: strokeWidth,
        seed: seed,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A short hand-drawn underline stroke, used under the logo/section
/// titles instead of a straight Divider.
class SketchUnderline extends StatelessWidget {
  final double width;
  final int seed;
  const SketchUnderline({super.key, required this.width, this.seed = 1});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, 10),
      painter: _SketchUnderlinePainter(seed: seed),
    );
  }
}

class _SketchUnderlinePainter extends CustomPainter {
  final int seed;
  _SketchUnderlinePainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint()
      ..color = SketchColors.ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height * 0.5);
    var x = 0.0;
    while (x < size.width) {
      final nx = (x + 6 + rnd.nextDouble() * 5).clamp(0, size.width);
      final ny = size.height * 0.5 + (rnd.nextDouble() * 2 - 1) * 2;
      path.lineTo(nx.toDouble(), ny);
      x = nx.toDouble();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SketchUnderlinePainter old) => false;
}
