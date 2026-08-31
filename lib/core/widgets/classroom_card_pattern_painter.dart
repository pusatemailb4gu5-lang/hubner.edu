import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_colors.dart';

/// Original 5 Classroom Card Patterns with subtle, gentle living animation.
class ClassroomCardPatternPainter extends CustomPainter {
  final int patternIndex;
  final Color accentColor;
  final bool isDark;
  final double progress;

  const ClassroomCardPatternPainter({
    required this.patternIndex,
    required this.accentColor,
    this.isDark = false,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final bool dark = isDark || AppColors.isDarkMode;
    final double phase = progress * 2 * math.pi;

    // Original harmonious colors
    final Color primaryPatternColor = dark
        ? Colors.black.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.08);
    final Color secondaryPatternColor = dark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.30);
    final Color strokePatternColor = dark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);
    final Color ringPatternColor = dark
        ? Colors.black.withValues(alpha: 0.16)
        : accentColor.withValues(alpha: 0.07);
    final Color dotPatternColor = dark
        ? Colors.black.withValues(alpha: 0.22)
        : accentColor.withValues(alpha: 0.10);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Subtle breathing offsets (3-5px)
    final double w1 = math.sin(phase) * 5.0;
    final double w2 = math.cos(phase * 0.9) * 4.0;
    final double w3 = math.sin(phase + 1.2) * 4.5;
    final double w4 = math.cos(phase + 0.6) * 3.5;

    switch (patternIndex % 5) {
      // -------------------------------------------------------------
      // Pattern 0: Original Organic Cubic Wave Layers + Gentle Undulation
      // -------------------------------------------------------------
      case 0:
        final paint = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final path = Path();
        path.moveTo(size.width * 0.45 + w1, 0);
        path.cubicTo(
          size.width * 0.65 + w2,
          size.height * 0.35 + w1,
          size.width * 0.35 - w2,
          size.height * 0.75 + w3,
          size.width * 0.85 + w4,
          size.height,
        );
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
        path.close();
        canvas.drawPath(path, paint);

        final paintSecondary = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathSecondary = Path();
        pathSecondary.moveTo(size.width * 0.60 + w3, 0);
        pathSecondary.cubicTo(
          size.width * 0.80 - w1,
          size.height * 0.40 + w2,
          size.width * 0.50 + w4,
          size.height * 0.80 - w1,
          size.width,
          size.height * 0.70 + w2,
        );
        pathSecondary.lineTo(size.width, 0);
        pathSecondary.close();
        canvas.drawPath(pathSecondary, paintSecondary);
        break;

      // -------------------------------------------------------------
      // Pattern 1: Original Concentric Rings + Gentle Floating & Wave
      // -------------------------------------------------------------
      case 1:
        final paintRing = Paint()
          ..color = ringPatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14;
        final center = Offset(
          size.width * 0.85 + math.cos(phase) * 3.5,
          size.height * 0.30 + math.sin(phase) * 3.5,
        );
        final double pulse = math.sin(phase) * 1.5;
        canvas.drawCircle(center, 30 + pulse, paintRing);
        canvas.drawCircle(center, 55 + pulse, paintRing);

        final paintWave = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRing = Path();
        pathRing.moveTo(size.width * 0.55 + w1, 0);
        pathRing.quadraticBezierTo(
          size.width * 0.80 + w2,
          size.height * 0.50 + w3,
          size.width,
          size.height + w1,
        );
        pathRing.lineTo(size.width, 0);
        pathRing.close();
        canvas.drawPath(pathRing, paintWave);
        break;

      // -------------------------------------------------------------
      // Pattern 2: Original Floating Bubbles + Gentle Bobbing Motion
      // -------------------------------------------------------------
      case 2:
        final paintBubble1 = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final double b1Y = size.height * 0.20 + math.sin(phase) * 5.0;
        final double b1X = size.width * 0.80 + math.cos(phase * 0.8) * 3.0;
        canvas.drawCircle(
          Offset(b1X, b1Y),
          45 + math.sin(phase) * 1.2,
          paintBubble1,
        );

        final paintBubble2 = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final double b2Y = size.height * 0.75 + math.cos(phase + 1.0) * 4.5;
        final double b2X = size.width * 0.90 + math.sin(phase * 0.7) * 3.0;
        canvas.drawCircle(
          Offset(b2X, b2Y),
          35 + math.cos(phase) * 1.0,
          paintBubble2,
        );
        break;

      // -------------------------------------------------------------
      // Pattern 3: Original Dot Grid Matrix + Soft Subtle Drift
      // -------------------------------------------------------------
      case 3:
        final paintDot = Paint()
          ..color = dotPatternColor
          ..style = PaintingStyle.fill;
        for (double x = size.width * 0.5; x < size.width; x += 18) {
          for (double y = 10; y < size.height; y += 18) {
            final double dotOffset = math.sin(phase + (x + y) * 0.04) * 1.2;
            canvas.drawCircle(Offset(x + dotOffset, y + dotOffset), 3, paintDot);
          }
        }
        break;

      // -------------------------------------------------------------
      // Pattern 4: Original Diagonal Ray & Stroke + Gentle Sway
      // -------------------------------------------------------------
      case 4:
      default:
        final paintRay = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRay = Path();
        pathRay.moveTo(size.width * 0.50 + w1, 0);
        pathRay.quadraticBezierTo(
          size.width * 0.70 + w2,
          size.height * 0.50 + w3,
          size.width * 0.80 + w4,
          size.height,
        );
        pathRay.lineTo(size.width, size.height);
        pathRay.lineTo(size.width, 0);
        pathRay.close();
        canvas.drawPath(pathRay, paintRay);

        final paintStroke = Paint()
          ..color = strokePatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
        final pathStroke = Path();
        pathStroke.moveTo(size.width * 0.65 + w2, 0);
        pathStroke.quadraticBezierTo(
          size.width * 0.80 - w1,
          size.height * 0.40 + w3,
          size.width * 0.85 + w4,
          size.height,
        );
        canvas.drawPath(pathStroke, paintStroke);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ClassroomCardPatternPainter oldDelegate) {
    return oldDelegate.patternIndex != patternIndex ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.progress != progress;
  }
}

/// A self-animated widget that renders ClassroomCardPatternPainter
/// smoothly without requiring caller to manage an AnimationController.
class AnimatedClassroomPattern extends StatefulWidget {
  final int patternIndex;
  final Color accentColor;
  final bool isDark;
  final Duration duration;

  const AnimatedClassroomPattern({
    super.key,
    required this.patternIndex,
    required this.accentColor,
    this.isDark = false,
    this.duration = const Duration(seconds: 12),
  });

  @override
  State<AnimatedClassroomPattern> createState() => _AnimatedClassroomPatternState();
}

class _AnimatedClassroomPatternState extends State<AnimatedClassroomPattern>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: ClassroomCardPatternPainter(
              patternIndex: widget.patternIndex,
              accentColor: widget.accentColor,
              isDark: widget.isDark,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}
