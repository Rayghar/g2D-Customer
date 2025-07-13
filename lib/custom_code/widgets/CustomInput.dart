// File: lib/widgets/custom_input.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart'; // Adjust path if necessary

class CustomInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? initialValue;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final bool readOnly;

  const CustomInput({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.initialValue,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.autovalidateMode,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // The InputDecorationTheme is already defined in your ThemeProvider's lightTheme/darkTheme
    // We can directly use Theme.of(context).inputDecorationTheme
    // Or, for more specific overrides not covered by the global theme, define them here.

    final effectiveInputDecorationTheme =
        Theme.of(context).inputDecorationTheme;

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      decoration: InputDecoration(
        // Use styles from the global theme, but allow overrides or specific additions
        hintText: hintText,
        hintStyle: effectiveInputDecorationTheme.hintStyle ??
            GoogleFonts.inter(color: themeProvider.tertiaryText),
        labelText: labelText,
        labelStyle: effectiveInputDecorationTheme.labelStyle ??
            GoogleFonts.inter(color: themeProvider.secondaryText),
        floatingLabelStyle: GoogleFonts.inter(
            color: themeProvider.gas2doorPrimaryBlue), // Color when focused
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                color: themeProvider.secondaryText.withOpacity(0.7))
            : null,
        suffixIcon: suffixIcon,
        filled: true, // Ensure filled is true to see fillColor
        fillColor: effectiveInputDecorationTheme.fillColor ??
            themeProvider.appSecondaryBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: effectiveInputDecorationTheme.border ??
            OutlineInputBorder(
              borderRadius:
                  themeProvider.cardBorderRadius, // Using theme's border radius
              borderSide: BorderSide(
                  color: themeProvider.tertiaryText.withOpacity(0.5)),
            ),
        enabledBorder: effectiveInputDecorationTheme.enabledBorder ??
            OutlineInputBorder(
              borderRadius: themeProvider.cardBorderRadius,
              borderSide: BorderSide(
                  color: themeProvider.tertiaryText.withOpacity(0.5)),
            ),
        focusedBorder: effectiveInputDecorationTheme.focusedBorder ??
            OutlineInputBorder(
              borderRadius: themeProvider.cardBorderRadius,
              borderSide: BorderSide(
                  color: themeProvider.gas2doorPrimaryBlue, width: 2.0),
            ),
        errorBorder: effectiveInputDecorationTheme.errorBorder ??
            OutlineInputBorder(
              borderRadius: themeProvider.cardBorderRadius,
              borderSide:
                  BorderSide(color: themeProvider.errorColor, width: 1.5),
            ),
        focusedErrorBorder: effectiveInputDecorationTheme.focusedErrorBorder ??
            OutlineInputBorder(
              borderRadius: themeProvider.cardBorderRadius,
              borderSide:
                  BorderSide(color: themeProvider.errorColor, width: 2.0),
            ),
        disabledBorder: OutlineInputBorder(
          // Style for disabled state
          borderRadius: themeProvider.cardBorderRadius,
          borderSide:
              BorderSide(color: themeProvider.tertiaryText.withOpacity(0.3)),
        ),
      ),
      style: GoogleFonts.inter(
        // Style for the actual input text
        color: themeProvider.primaryText,
        fontSize: 15,
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onSaved: onSaved,
      onChanged: onChanged,
      textInputAction: textInputAction,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted,
      maxLines: maxLines,
      minLines: minLines,
      enabled: enabled,
      autovalidateMode: autovalidateMode ?? AutovalidateMode.onUserInteraction,
      readOnly: readOnly,
    );
  }
}
