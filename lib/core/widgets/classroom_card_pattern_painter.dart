import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_colors.dart';

/// Beautiful geometric patterns used across Classroom Cards, Splash Screen,
/// Onboarding, and Reports pages.
class ClassroomCardPatternPainter extends CustomPainter {
  final int patternIndex;
  final Color accentColor;
  final bool isDark;

  const ClassroomCardPatternPainter({
    required this.patternIndex,
    required this.accentColor,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool dark = isDark || AppColors.isDarkMode;
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

    switch (patternIndex % 5) {
      case 0:
        // Pattern 1: Wave & Smooth Ribbon (Curved waves flowing down right side)
        final paint = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final path = Path();
        path.moveTo(size.width * 0.35, 0);
        path.cubicTo(
          size.width * 0.65,
          size.height * 0.35,
          size.width * 0.30,
          size.height * 0.70,
          size.width * 0.85,
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
        pathSecondary.moveTo(size.width * 0.55, 0);
        pathSecondary.cubicTo(
          size.width * 0.80,
          size.height * 0.40,
          size.width * 0.45,
          size.height * 0.80,
          size.width,
          size.height * 0.70,
        );
        pathSecondary.lineTo(size.width, 0);
        pathSecondary.close();
        canvas.drawPath(pathSecondary, paintSecondary);

        // Concentric ambient ring in background
        final paintSubtleRing = Paint()
          ..color = strokePatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.25), 48, paintSubtleRing);
        break;

      case 1:
        // Pattern 2: Concentric Swirls & Rings (Arcs centered top-right)
        final paintRing = Paint()
          ..color = ringPatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14;
        final center = Offset(size.width * 0.85, size.height * 0.3);
        canvas.drawCircle(center, 30, paintRing);
        canvas.drawCircle(center, 55, paintRing);

        final paintWave = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRing = Path();
        pathRing.moveTo(size.width * 0.55, 0);
        pathRing.quadraticBezierTo(
          size.width * 0.8,
          size.height * 0.5,
          size.width,
          size.height,
        );
        pathRing.lineTo(size.width, 0);
        pathRing.close();
        canvas.drawPath(pathRing, paintWave);
        break;

      case 2:
        // Pattern 3: Floating Soft Circles / Bubbles
        final paintBubble1 = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(size.width * 0.8, size.height * 0.2),
          45,
          paintBubble1,
        );

        final paintBubble2 = Paint()
          ..color = secondaryPatternColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(size.width * 0.9, size.height * 0.75),
          35,
          paintBubble2,
        );

        final paintBubble3 = Paint()
          ..color = strokePatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(
          Offset(size.width * 0.3, size.height * 0.8),
          28,
          paintBubble3,
        );
        break;

      case 3:
        // Pattern 4: Modern Geometric Mesh / Node Grid
        final paintDot = Paint()
          ..color = dotPatternColor
          ..style = PaintingStyle.fill;
        for (double x = size.width * 0.2; x < size.width; x += 22) {
          for (double y = 10; y < size.height; y += 22) {
            canvas.drawCircle(Offset(x, y), 2.5, paintDot);
          }
        }
        break;

      case 4:
      default:
        // Pattern 5: Organic Diagonal Rays / Leaf Curves
        final paintRay = Paint()
          ..color = primaryPatternColor
          ..style = PaintingStyle.fill;
        final pathRay = Path();
        pathRay.moveTo(size.width * 0.5, 0);
        pathRay.quadraticBezierTo(
          size.width * 0.7,
          size.height * 0.5,
          size.width * 0.8,
          size.height,
        );
        pathRay.lineTo(size.width, size.height);
        pathRay.close();
        canvas.drawPath(pathRay, paintRay);

        final paintStroke = Paint()
          ..color = strokePatternColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round;
        final pathStroke = Path();
        pathStroke.moveTo(size.width * 0.65, 0);
        pathStroke.quadraticBezierTo(
          size.width * 0.8,
          size.height * 0.4,
          size.width * 0.85,
          size.height,
        );
        canvas.drawPath(pathStroke, paintStroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ClassroomCardPatternPainter oldDelegate) {
    return oldDelegate.patternIndex != patternIndex ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
