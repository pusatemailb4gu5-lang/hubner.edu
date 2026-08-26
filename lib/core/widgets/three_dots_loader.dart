import 'package:flutter/material.dart';

class ThreeDotsLoader extends StatelessWidget {
  final double size;
  final double bounceHeight;
  final List<Color>? colors;

  const ThreeDotsLoader({
    super.key,
    this.size = 20.0,
    this.bounceHeight = 0.0,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = (colors != null && colors!.isNotEmpty)
        ? colors!.first
        : const Color(0xFF7C3AED); // Ungu Hubner Core

    final double diameter = (size <= 10.0) ? 20.0 : size;

    return Center(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CircularProgressIndicator(
          strokeWidth: diameter > 24 ? 2.8 : 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      ),
    );
  }
}
