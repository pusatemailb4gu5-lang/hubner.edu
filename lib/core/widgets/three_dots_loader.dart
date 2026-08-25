import 'package:flutter/material.dart';

/// ThreeDotsLoader is disabled app-wide to prevent loading dots and provide instantaneous rendering.
class ThreeDotsLoader extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
