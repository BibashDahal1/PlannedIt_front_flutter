import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/sketch_colors.dart';

class SketchIcon extends StatelessWidget {
  final String asset;
  final double size;
  const SketchIcon(this.asset, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    // Subscribes to theme changes so a `const SketchIcon(...)` still
    // rebuilds when the theme toggles.
    Theme.of(context);

    return ColorFiltered(
      colorFilter: ColorFilter.mode(SketchColors.ink, BlendMode.srcIn),
      child: Image.asset(
        'assets/images/sketch/$asset.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Maps a backend category name to one of the extracted hand-drawn
/// icons. Every category the API currently returns has a real match;
/// `more_dots` covers "Other" and anything unrecognized.
String? sketchAssetForCategory(String categoryName) {
  switch (categoryName) {
    case 'Futsal':
      return 'soccer';
    case 'Basketball':
      return 'basketball';
    case 'Hiking':
      return 'hiking';
    case 'Board Games':
      return 'board_games';
    case 'Study Group':
      return 'study_group';
    case 'Volunteering':
      return 'volunteering';
    case 'Other':
      return 'more_dots';
    default:
      return null;
  }
}

/// One shared widget for every place a category's icon needs to be
/// shown -- Home cards, Map markers/chips, the Post form, Activity
/// Detail, Dashboard -- so they all render identically and a mapping
/// fix only has to happen once.
class CategoryIcon extends StatelessWidget {
  final String categoryName;
  final double size;
  const CategoryIcon(this.categoryName, {super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // rebuild on theme toggle even when const
    final asset = sketchAssetForCategory(categoryName);
    return asset != null
        ? SketchIcon(asset, size: size)
        : SketchCircleGlyph(size: size);
  }
}

/// A small hand-drawn 2x2 grid, standing in for "All" / "everything" --
/// distinct from the three-dot "more" glyph so the two don't read as
/// the same affordance.
class SketchAllGlyph extends StatelessWidget {
  final double size;
  const SketchAllGlyph({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // rebuild on theme toggle even when const
    return CustomPaint(
      size: Size(size, size),
      painter: _AllGlyphPainter(color: SketchColors.ink),
    );
  }
}

class _AllGlyphPainter extends CustomPainter {
  final Color color;
  _AllGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final cell = size.width * 0.34;
    final gap = size.width * 0.14;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        final jx = (rnd.nextDouble() * 2 - 1) * 1.0;
        final jy = (rnd.nextDouble() * 2 - 1) * 1.0;
        final left = col * (cell + gap) + jx;
        final top = row * (cell + gap) + jy;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, cell, cell),
            const Radius.circular(3),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AllGlyphPainter old) => old.color != color;
}

/// A plain hand-drawn circle outline -- last-resort fallback for a
/// category with no icon mapping.
class SketchCircleGlyph extends StatelessWidget {
  final double size;
  const SketchCircleGlyph({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // rebuild on theme toggle even when const
    return CustomPaint(
      size: Size(size, size),
      painter: _CirclePainter(color: SketchColors.ink),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final Color color;
  _CirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(size.width.toInt());
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final path = Path();
    for (var i = 0; i <= 36; i++) {
      final angle = (i / 36) * 2 * math.pi;
      final jitter = (rnd.nextDouble() * 2 - 1) * 1.2;
      final point = center + Offset.fromDirection(angle, radius + jitter);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CirclePainter old) => old.color != color;
}

/// Shared size tiers -- tune these instead of hunting down every call
/// site. Anything under ~20 reads as noisy rather than hand-drawn,
/// since the crosshatch shading needs enough pixels to resolve.
class SketchIconSize {
  SketchIconSize._();
  static const double inline = 30; // next to body text in a row
  static const double chip = 30; // compact chips/badges
  static const double nav = 30; // bottom nav bar
  static const double tile = 36; // category tiles, markers
  static const double card = 40; // card icon boxes, header icons
}
