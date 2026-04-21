import 'dart:async';
import 'package:flutter/material.dart';

enum ToastType { success, error, info }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    bool removed = false;
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: () {
          if (!removed) {
            removed = true;
            entry.remove();
          }
        },
      ),
    );

    overlay.insert(entry);
    Timer(duration, () {
      if (!removed && entry.mounted) {
        removed = true;
        entry.remove();
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    // Auto dismiss delay handling is done in AppToast.show but we could add a secondary timer here
    // for the reverse animation.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case ToastType.success: return Icons.check_circle_rounded;
      case ToastType.error: return Icons.error_rounded;
      case ToastType.info: return Icons.info_rounded;
    }
  }

  Color _getColor() {
    switch (widget.type) {
      case ToastType.success: return const Color(0xFF4CAF50);
      case ToastType.error: return const Color(0xFFE53935);
      case ToastType.info: return const Color(0xFF2196F3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 50,
      right: 25,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 340,
              constraints: const BoxConstraints(minHeight: 64),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF1A1A1A).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Accent indicator bar
                    Container(
                      width: 5,
                      color: _getColor(),
                    ),
                    const SizedBox(width: 14),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getColor().withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getIcon(), color: _getColor(), size: 18),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.type == ToastType.success ? 'Success' : (widget.type == ToastType.error ? 'Error' : 'Info'),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.message,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, 
                          size: 16, 
                          color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.3)),
                      onPressed: () {
                         _controller.reverse().then((_) => widget.onDismiss());
                      },
                      splashRadius: 18,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
