// File: lib/widgets/button.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final double height;
  final double borderRadius;
  final double elevation;
  final TextStyle? textStyle;
  final Widget? icon;
  final EdgeInsetsGeometry? padding;
  final BorderSide?
      border; // <<< CHANGED: Changed from borderColor to BorderSide for more flexibility

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.textColor,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.elevation = 2.0,
    this.textStyle,
    this.icon,
    this.padding,
    this.border, // <<< CHANGED: Use BorderSide
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final buttonColor = color ?? themeProvider.gas2doorPrimaryBlue;
    final effectiveTextColor = textColor ?? themeProvider.infoColorOnDarkBgs;

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: border ??
                BorderSide.none, // <<< MODIFIED: Apply BorderSide or none
          ),
          elevation: elevation,
          shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                style: textStyle ??
                    GoogleFonts.inter(
                      color: effectiveTextColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
