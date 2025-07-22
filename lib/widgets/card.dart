// File: lib/widgets/card.dart
// ADVISORY: This version adds the 'surfaceTintColor' property to fix the build error.

import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double? elevation;
  final double? borderRadius;
  final Color? shadowColor;
  final EdgeInsetsGeometry? margin;
  final BorderSide? border;
  // NEW: Added surfaceTintColor to support the new design in HomeScreen
  final Color? surfaceTintColor;

  const CustomCard({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.shadowColor,
    this.margin,
    this.border,
    this.surfaceTintColor, // Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double effectiveBorderRadius = borderRadius ?? 12.0;

    // Using the standard Material Card widget which supports all our desired properties
    Widget cardContent = Card(
      margin: EdgeInsets.zero, // Margin will be handled by the parent Padding
      color: color ?? theme.cardColor,
      elevation: elevation ?? 2.0,
      shadowColor: shadowColor ?? theme.shadowColor.withOpacity(0.2),
      surfaceTintColor: surfaceTintColor, // Applying the new property here
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        side: border ?? BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: cardContent,
      );
    }
    return cardContent;
  }
}
