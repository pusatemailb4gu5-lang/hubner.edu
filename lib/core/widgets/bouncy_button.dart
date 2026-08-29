import 'package:flutter/material.dart';

class BouncyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final bool enableSquash;

  const BouncyButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.88,
    this.duration = const Duration(milliseconds: 130),
    this.enableSquash = true,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
