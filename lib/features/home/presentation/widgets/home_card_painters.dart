import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_colors.dart';

class BlueCardPatternPainter extends CustomPainter {
  final bool isDark;
  const BlueCardPatternPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)).withValues(alpha: isDark ? 0.05 : 0.07)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(size.width * 0.45, 0);
    path1.cubicTo(
      size.width * 0.65,
      size.height * 0.35,
      size.width * 0.35,
      size.height * 0.75,
      size.width * 0.9,
      size.height,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(size.width, 0);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = (isDark ? Colors.white : Colors.white).withValues(alpha: isDark ? 0.04 : 0.35)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(size.width * 0.65, 0);
    path2.cubicTo(
      size.width * 0.85,
      size.height * 0.4,
      size.width * 0.55,
      size.height * 0.8,
      size.width,
      size.height * 0.7,
    );
    path2.lineTo(size.width, 0);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LavenderCardPatternPainter extends CustomPainter {
  final bool isDark;
  const LavenderCardPatternPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? const Color(0xFFC084FC) : const Color(0xFF9333EA)).withValues(alpha: isDark ? 0.04 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    final center = Offset(size.width * 0.85, size.height * 0.5);
    canvas.drawCircle(center, 24, paint);
    canvas.drawCircle(center, 44, paint);

    final paintFill = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.03 : 0.25)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size.width * 0.6, 0);
    path.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.4,
      size.width,
      size.height * 0.9,
    );
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawPath(path, paintFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AmberCardPatternPainter extends CustomPainter {
  final bool isDark;
  const AmberCardPatternPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)).withValues(alpha: isDark ? 0.04 : 0.06)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(size.width * 0.55, 0);
    path1.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.5,
      size.width * 0.85,
      size.height,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(size.width, 0);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paintStroke = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.03 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final path2 = Path();
    path2.moveTo(size.width * 0.68, 0);
    path2.quadraticBezierTo(
      size.width * 0.82,
      size.height * 0.45,
      size.width * 0.88,
      size.height,
    );
    canvas.drawPath(path2, paintStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ClassroomCardPatternPainter extends CustomPainter {
  final int patternIndex;
  final Color accentColor;

  const ClassroomCardPatternPainter({
    required this.patternIndex,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool isDark = AppColors.isDarkMode;
    final Color primaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : accentColor.withValues(alpha: 0.08);
    final Color secondaryPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.30);
    final Color strokePatternColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);
    final Color ringPatternColor = isDark
        ? Colors.black.withValues(alpha: 0.16)
        : accentColor.withValues(alpha: 0.07);

    final int idx = patternIndex % 4;

    if (idx == 0) {
      final path1 = Path();
      path1.moveTo(size.width * 0.45, 0);
      path1.cubicTo(
        size.width * 0.65,
        size.height * 0.35,
        size.width * 0.35,
        size.height * 0.75,
        size.width * 0.9,
        size.height,
      );
      path1.lineTo(size.width, size.height);
      path1.lineTo(size.width, 0);
      path1.close();
      canvas.drawPath(path1, Paint()..color = primaryPatternColor..style = PaintingStyle.fill);

      final path2 = Path();
      path2.moveTo(size.width * 0.65, 0);
      path2.cubicTo(
        size.width * 0.85,
        size.height * 0.4,
        size.width * 0.55,
        size.height * 0.8,
        size.width,
        size.height * 0.7,
      );
      path2.lineTo(size.width, 0);
      path2.close();
      canvas.drawPath(path2, Paint()..color = secondaryPatternColor..style = PaintingStyle.fill);
    } else if (idx == 1) {
      final ringPaint = Paint()
        ..color = ringPatternColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14;

      final center = Offset(size.width * 0.85, size.height * 0.5);
      canvas.drawCircle(center, 30, ringPaint);
      canvas.drawCircle(center, 55, ringPaint);

      final path = Path();
      path.moveTo(size.width * 0.55, 0);
      path.quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.4,
        size.width,
        size.height * 0.85,
      );
      path.lineTo(size.width, 0);
      path.close();
      canvas.drawPath(path, Paint()..color = secondaryPatternColor..style = PaintingStyle.fill);
    } else if (idx == 2) {
      final path1 = Path();
      path1.moveTo(size.width * 0.5, 0);
      path1.quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.5,
        size.width * 0.82,
        size.height,
      );
      path1.lineTo(size.width, size.height);
      path1.lineTo(size.width, 0);
      path1.close();
      canvas.drawPath(path1, Paint()..color = primaryPatternColor..style = PaintingStyle.fill);

      final path2 = Path();
      path2.moveTo(size.width * 0.65, 0);
      path2.quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.45,
        size.width * 0.88,
        size.height,
      );
      canvas.drawPath(path2, Paint()..color = strokePatternColor..style = PaintingStyle.stroke..strokeWidth = 10..strokeCap = StrokeCap.round);
    } else {
      final path1 = Path();
      path1.moveTo(size.width * 0.4, 0);
      path1.cubicTo(
        size.width * 0.6,
        size.height * 0.3,
        size.width * 0.5,
        size.height * 0.7,
        size.width * 0.8,
        size.height,
      );
      path1.lineTo(size.width, size.height);
      path1.lineTo(size.width, 0);
      path1.close();
      canvas.drawPath(path1, Paint()..color = primaryPatternColor..style = PaintingStyle.fill);

      final ringPaint = Paint()
        ..color = ringPatternColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.3), 36, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
