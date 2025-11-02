// In lib/widgets/input.dart (Updated)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class CustomInput extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final String? prefixText;
  final String? suffixText;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final List<TextInputFormatter>? inputFormatters;
  // --- ADDED: textCapitalization parameter ---
  final TextCapitalization textCapitalization;
  // --- END ADDED ---
  final FocusNode? focusNode; // <<< --- ADDED THIS LINE --- <<<

  const CustomInput({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.onSaved,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.prefixText,
    this.suffixText,
    this.fillColor,
    this.contentPadding,
    this.inputFormatters,
    this.textCapitalization =
        TextCapitalization.none, // <<< ADDED TO CONSTRUCTOR with default
    this.focusNode, // <<< --- ADDED THIS LINE TO CONSTRUCTOR --- <<<
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return TextFormField(
      controller: controller,
      focusNode: focusNode, // <<< --- PASS focusNode TO TextFormField --- <<<
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      onSaved: onSaved,
      maxLines: maxLines,
      minLines: minLines,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      textCapitalization:
          textCapitalization, // <<< PASS textCapitalization to TextFormField
      style: GoogleFonts.inter(color: themeProvider.primaryText, fontSize: 15),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle:
            GoogleFonts.inter(color: themeProvider.secondaryText, fontSize: 14),
        hintText: hintText,
        hintStyle:
            GoogleFonts.inter(color: themeProvider.tertiaryText, fontSize: 15),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                color: themeProvider.secondaryText.withOpacity(0.7), size: 20)
            : (prefixText != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 15.0),
                    child: Text(prefixText!,
                        style: GoogleFonts.inter(
                            color: themeProvider.secondaryText, fontSize: 15)))
                : null),
        suffixIcon: suffixIcon ??
            (suffixText != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 15.0),
                    child: Text(suffixText!,
                        style: GoogleFonts.inter(
                            color: themeProvider.secondaryText, fontSize: 15)))
                : null),
        filled: fillColor != null ||
            (fillColor == null && themeProvider.isDarkMode),
        fillColor: fillColor ??
            (themeProvider.isDarkMode
                ? themeProvider.cardBackground.withOpacity(0.5)
                : themeProvider.appSecondaryBackground.withOpacity(0.5)),
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        border: OutlineInputBorder(
          borderRadius: themeProvider.cardBorderRadius,
          borderSide: BorderSide(
              color: themeProvider.tertiaryText.withOpacity(0.3), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: themeProvider.cardBorderRadius,
          borderSide: BorderSide(
              color: themeProvider.tertiaryText.withOpacity(0.5), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: themeProvider.cardBorderRadius,
          borderSide:
              BorderSide(color: themeProvider.gas2doorPrimaryBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: themeProvider.cardBorderRadius,
          borderSide: BorderSide(color: themeProvider.errorColor, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: themeProvider.cardBorderRadius,
          borderSide: BorderSide(color: themeProvider.errorColor, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: themeProvider.cardBorderRadius,
          borderSide: BorderSide(
              color: themeProvider.tertiaryText.withOpacity(0.2), width: 1.0),
        ),
        errorStyle:
            GoogleFonts.inter(color: themeProvider.errorColor, fontSize: 12),
      ),
    );
  }
}
