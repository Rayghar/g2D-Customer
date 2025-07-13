// File: lib/widgets/card.dart

import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double? elevation;
  final double? borderRadius;
  final Color? shadowColor;
  final EdgeInsetsGeometry? margin;
  final BorderSide? border; // <<< ADDED: Define the border parameter

  const CustomCard({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.borderRadius,
    this.shadowColor,
    this.margin,
    this.border, // <<< ADDED: Make it available in the constructor
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double effectiveBorderRadius = borderRadius ?? 12.0;

    Widget cardContent = Material(
      color: Colors.transparent,
      elevation: elevation ?? 2.0, // Adjusted default elevation slightly
      shadowColor: shadowColor ??
          theme.shadowColor.withOpacity(0.2), // Softer default shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        // Apply the border here if it's provided
        side: border ??
            BorderSide.none, // <<< MODIFIED: Use border or BorderSide.none
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        // The BoxDecoration here is mainly for background color if 'border' is handled by Material's shape.
        // If a border needs to be drawn *inside* the Material shadow (e.g. for an outline separate from elevation shadow),
        // then the BoxDecoration's border property could be used, but Material's shape.side is preferred for outlining the shape itself.
        decoration: BoxDecoration(
          color: color ?? theme.cardColor,
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
        ),
        child: child,
      ),
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
