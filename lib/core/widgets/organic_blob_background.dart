import 'package:flutter/material.dart';

/// Reusable Organic Fluid Liquid Blob Background.
/// Displays a smooth full-height gradient with beautifully distributed,
/// floating organic liquid blobs/clouds spanning 100% from top to bottom.
class OrganicBlobBackground extends StatelessWidget {
  final bool isDark;
  final int variant;
  final Widget? child;

  const OrganicBlobBackground({
    super.key,
    required this.isDark,
    this.variant = 0,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _OrganicBlobPainter(isDark: isDark, variant: variant),
        child: child,
      ),
    );
  }
}

class _OrganicBlobPainter extends CustomPainter {
  final bool isDark;
  final int variant;

  const _OrganicBlobPainter({required this.isDark, required this.variant});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // 1. Base Full-Height Sky / Midnight Gradient (100% continuous from y=0 to y=h)
    final Rect rect = Offset.zero & size;
    final Paint bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                const Color(0xFF1E293B),
                const Color(0xFF0F172A),
                const Color(0xFF090D16),
              ]
            : [
                const Color(0xFFA5C9FF),
                const Color(0xFF90BAFC),
                const Color(0xFF7BA6EE),
              ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Translucent Organic Blob Paints
    final Color c1 = isDark
        ? const Color(0xFF334155).withValues(alpha: 0.50)
        : const Color(0xFF6B9FF2).withValues(alpha: 0.40);
    final Color c2 = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.60)
        : const Color(0xFF5D94EE).withValues(alpha: 0.35);
    final Color c3 = isDark
        ? const Color(0xFF475569).withValues(alpha: 0.40)
        : const Color(0xFF88B6FF).withValues(alpha: 0.45);

    final Paint paint1 = Paint()..color = c1;
    final Paint paint2 = Paint()..color = c2;
    final Paint paint3 = Paint()..color = c3;

    // 3. Floating Organic Closed Blobs Distributed Evenly Across 100% of the Canvas
    
    // Blob 1: Top-Left Floating Cloud (y: 0% - 22%)
    final Path b1 = Path();
    b1.moveTo(0, 0);
    b1.cubicTo(w * 0.42, 0, w * 0.48, h * 0.14, w * 0.22, h * 0.20);
    b1.cubicTo(w * 0.08, h * 0.23, 0, h * 0.18, 0, 0);
    b1.close();
    canvas.drawPath(b1, paint1);

    // Blob 2: Top-Right Floating Droplet (y: 0% - 25%)
    final Path b2 = Path();
    b2.moveTo(w * 0.50, 0);
    b2.cubicTo(w * 0.48, h * 0.10, w * 0.85, h * 0.18, w * 0.78, h * 0.26);
    b2.cubicTo(w * 0.72, h * 0.32, w * 0.92, h * 0.28, w, h * 0.20);
    b2.lineTo(w, 0);
    b2.close();
    canvas.drawPath(b2, paint3);

    // Blob 3: Upper-Center Organic Bubble (y: 16% - 38%)
    final Path b3 = Path();
    b3.moveTo(w * 0.28, h * 0.22);
    b3.cubicTo(w * 0.55, h * 0.16, w * 0.75, h * 0.24, w * 0.65, h * 0.34);
    b3.cubicTo(w * 0.52, h * 0.42, w * 0.20, h * 0.36, w * 0.28, h * 0.22);
    b3.close();
    canvas.drawPath(b3, paint2);

    // Blob 4: Mid-Left Swelling Fluid Cloud (y: 35% - 56%)
    final Path b4 = Path();
    b4.moveTo(0, h * 0.38);
    b4.cubicTo(w * 0.38, h * 0.34, w * 0.42, h * 0.52, w * 0.22, h * 0.56);
    b4.cubicTo(w * 0.08, h * 0.58, 0, h * 0.52, 0, h * 0.38);
    b4.close();
    canvas.drawPath(b4, paint1);

    // Blob 5: Mid-Right Lateral Fluid Curve (y: 44% - 66%)
    final Path b5 = Path();
    b5.moveTo(w, h * 0.44);
    b5.cubicTo(w * 0.62, h * 0.46, w * 0.58, h * 0.62, w * 0.78, h * 0.66);
    b5.cubicTo(w * 0.90, h * 0.68, w, h * 0.62, w, h * 0.44);
    b5.close();
    canvas.drawPath(b5, paint2);

    // Blob 6: Lower-Left Fluid Cloud (y: 62% - 84%)
    final Path b6 = Path();
    b6.moveTo(0, h * 0.64);
    b6.cubicTo(w * 0.40, h * 0.60, w * 0.46, h * 0.78, w * 0.25, h * 0.84);
    b6.cubicTo(w * 0.10, h * 0.87, 0, h * 0.82, 0, h * 0.64);
    b6.close();
    canvas.drawPath(b6, paint3);

    // Blob 7: Lower-Right Floating Lagoon (y: 68% - 90%)
    final Path b7 = Path();
    b7.moveTo(w, h * 0.68);
    b7.cubicTo(w * 0.60, h * 0.70, w * 0.55, h * 0.88, w * 0.75, h * 0.92);
    b7.cubicTo(w * 0.88, h * 0.94, w, h * 0.88, w, h * 0.68);
    b7.close();
    canvas.drawPath(b7, paint1);

    // Blob 8: Bottom-Center Floating Puddle (y: 82% - 100%)
    final Path b8 = Path();
    b8.moveTo(w * 0.15, h);
    b8.cubicTo(w * 0.25, h * 0.84, w * 0.75, h * 0.82, w * 0.88, h);
    b8.close();
    canvas.drawPath(b8, paint2);
  }

  @override
  bool shouldRepaint(covariant _OrganicBlobPainter oldDelegate) => true;
}
