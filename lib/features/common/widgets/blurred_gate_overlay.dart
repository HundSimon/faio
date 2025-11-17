import 'dart:ui';

import 'package:flutter/material.dart';

class BlurredGateOverlay extends StatelessWidget {
  const BlurredGateOverlay({
    super.key,
    required this.child,
    required this.label,
    this.borderRadius,
  });

  final Widget child;
  final String label;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: child,
          ),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  '$label 内容',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击确认以查看',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
