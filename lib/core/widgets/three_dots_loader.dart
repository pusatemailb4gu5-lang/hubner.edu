import 'package:flutter/material.dart';

class ThreeDotsLoader extends StatefulWidget {
  final double size;
  final double bounceHeight;
  final List<Color>? colors;

  const ThreeDotsLoader({
    super.key,
    this.size = 8.0,
    this.bounceHeight = 6.0,
    this.colors,
  });

  @override
  State<ThreeDotsLoader> createState() => _ThreeDotsLoaderState();
}

class _ThreeDotsLoaderState extends State<ThreeDotsLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const List<Color> _defaultColors = [
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColors = widget.colors ?? _defaultColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final Color color = dotColors[index % dotColors.length];
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double delay = index * 0.22;
            final double progress = (_controller.value - delay) % 1.0;
            final double bounce = (progress < 0.5)
                ? -widget.bounceHeight * (1 - ((progress - 0.25).abs() / 0.25))
                : 0.0;

            return Transform.translate(
              offset: Offset(0, bounce.clamp(-widget.bounceHeight, 0.0)),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: widget.size * 0.35),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

