import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final double borderRadius;
  final double opacity;
  final bool useBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderColor,
    this.borderRadius = 20.0,
    this.opacity = 0.07,
    this.useBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    final shouldBlur = useBlur && !MediaQuery.of(context).disableAnimations;

    if (shouldBlur) {
      cardContent = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: cardContent,
      );
    }

    return RepaintBoundary(
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(opacity),
              Colors.white.withOpacity(opacity * 0.3),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 1.5),
          child: cardContent,
        ),
      ),
    );
  }
}
