import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ClipboardCountdownOverlay extends StatelessWidget {
  final int seconds;
  final int totalSeconds;

  const ClipboardCountdownOverlay({
    super.key,
    required this.seconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final progress = seconds / totalSeconds;
    
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Securely clearing clipboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2,
                        backgroundColor: colors.accent.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                      ),
                    ),
                    Text(
                      '$seconds',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
