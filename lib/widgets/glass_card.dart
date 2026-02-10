// lib/widgets/glass_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A glassmorphic card widget with backdrop blur and translucent background
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool hasBorder;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double blurAmount;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24,
    this.hasBorder = true,
    this.backgroundColor,
    this.onTap,
    this.blurAmount = 10,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null
                ? (backgroundColor ?? AppTheme.glassBackground)
                : null,
            borderRadius: BorderRadius.circular(borderRadius),
            border: hasBorder
                ? Border.all(color: AppTheme.glassBorder, width: 1)
                : null,
          ),
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// A feature card with gradient background, like the main wallet card in the reference
class FeatureCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const FeatureCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 28,
    this.gradientColors,
    this.onTap,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final defaultGradientColors = [
      const Color(0xFF2D1B69),
      const Color(0xFF1E3A5F),
      const Color(0xFF0F2847),
    ];

    final decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors ?? defaultGradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow:
          shadows ??
          [
            BoxShadow(
              color: (gradientColors?.first ?? defaultGradientColors.first)
                  .withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
    );

    final card = Container(
      decoration: decoration,
      padding: padding ?? const EdgeInsets.all(24),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// A bento-style grid item with icon and label
class BentoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? iconColor;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;
  final bool isLarge;

  const BentoItem({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.iconColor,
    this.gradientColors,
    this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasGradient = gradientColors != null && gradientColors!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: hasGradient
              ? LinearGradient(
                  colors: gradientColors!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: hasGradient ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasGradient ? Colors.transparent : AppTheme.surfaceBorder,
            width: 1,
          ),
        ),
        padding: EdgeInsets.all(isLarge ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: hasGradient
                    ? Colors.white.withValues(alpha: 0.2)
                    : (iconColor ?? AppTheme.primaryPurple).withValues(
                        alpha: 0.15,
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: hasGradient
                    ? Colors.white
                    : (iconColor ?? AppTheme.primaryPurple),
                size: isLarge ? 28 : 22,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                color: hasGradient ? Colors.white : AppTheme.textPrimary,
                fontSize: isLarge ? 16 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  color: hasGradient
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
