import 'package:flutter/material.dart';

class AnimatedRainbowBackground extends StatefulWidget {
  final Widget child;
  const AnimatedRainbowBackground({super.key, required this.child});

  @override
  State<AnimatedRainbowBackground> createState() => _AnimatedRainbowBackgroundState();
}

class _AnimatedRainbowBackgroundState extends State<AnimatedRainbowBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        // Subtle breathing animation for the glow sizes
        final blueRadius = 1.1 + (value * 0.15);
        final purpleRadius = 1.1 + ((1.0 - value) * 0.15);

        return Stack(
          children: [
            // 1. Base solid white background (so everything below is purely white)
            Container(color: Colors.white),

            // 2. Top-left soft blue radial gradient (kebiruan di kiri atas, pudar ke arah bawah & tengah)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1.0, -1.0),
                    radius: blueRadius,
                    colors: [
                      const Color(0xFFCBE3FF).withOpacity(0.9), // Soft premium sky blue
                      Colors.white.withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Top-right soft purple radial gradient (keunguan di kanan atas, pudar ke arah bawah & tengah)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.0, -1.0),
                    radius: purpleRadius,
                    colors: [
                      const Color(0xFFF2E0FF).withOpacity(0.9), // Soft premium lavender/purple
                      Colors.white.withOpacity(0.0),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // 4. Content on top
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}
