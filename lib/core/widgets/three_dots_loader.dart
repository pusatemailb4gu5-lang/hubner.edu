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

class _ThreeDotsLoaderState extends State<ThreeDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColors = widget.colors ?? const [
      Color(0xFF3B82F6),
      Color(0xFFEF4444),
      Color(0xFFF97316),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final double value = (_controller.value - (index * 0.2)) % 1.0;
            final double offset =
                -widget.bounceHeight * (1.0 - (value - 0.5).abs() * 2.0).clamp(0.0, 1.0);

            return Transform.translate(
              offset: Offset(0, offset),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: widget.size * 0.35),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: dotColors[index % dotColors.length],
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
