import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hubner/core/theme/app_typography.dart';

class InAppChatOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show({
    required BuildContext context,
    required String title,
    required String message,
    required String avatar,
    required VoidCallback onReply,
    required bool isDark,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any existing overlay
    dismiss();

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _InAppChatNotificationWidget(
        title: title,
        message: message,
        avatar: avatar,
        onReply: () {
          dismiss();
          onReply();
        },
        onDismiss: dismiss,
        isDark: isDark,
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;
  }
}

class _InAppChatNotificationWidget extends StatefulWidget {
  final String title;
  final String message;
  final String avatar;
  final VoidCallback onReply;
  final VoidCallback onDismiss;
  final bool isDark;

  const _InAppChatNotificationWidget({
    required this.title,
    required this.message,
    required this.avatar,
    required this.onReply,
    required this.onDismiss,
    required this.isDark,
  });

  @override
  State<_InAppChatNotificationWidget> createState() => _InAppChatNotificationWidgetState();
}

class _InAppChatNotificationWidgetState extends State<_InAppChatNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topMargin = MediaQuery.of(context).size.height * 0.15;
    final isDark = widget.isDark;

    return Positioned(
      top: topMargin,
      left: AppTypography.screenHorizontalMargin,
      right: AppTypography.screenHorizontalMargin,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: GestureDetector(
            onTap: widget.onReply,
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF18181B).withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar / Channel Icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                          ),
                          child: ClipOval(
                            child: widget.avatar.isNotEmpty
                                ? Image.asset(
                                    widget.avatar,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: Color(0xFF7C3AED),
                                      size: 20,
                                    ),
                                  )
                                : const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: Color(0xFF7C3AED),
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Last Message
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.cardTitle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.timestamp(
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // "Balas" Button
                        GestureDetector(
                          onTap: widget.onReply,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Balas',
                              style: AppTypography.buttonLabel(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Dismiss "X" Button
                        GestureDetector(
                          onTap: _handleDismiss,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? const Color(0xFF27272A)
                                  : const Color(0xFFF1F5F9),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
