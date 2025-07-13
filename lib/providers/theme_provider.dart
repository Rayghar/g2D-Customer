// File: lib/providers/theme_provider.dart
// (Adjust path if your project structure is different)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // For TextTheme
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  String? _darkMapStyleJson;
  String? _lightMapStyleJson;

  String? get darkMapStyle => _darkMapStyleJson;
  String? get lightMapStyle => _lightMapStyleJson;

  bool _isHybridApp = false; // Default to false
  bool get isHybridApp => _isHybridApp;

  Future<void> loadMapStyles() async {
    // Example:
    // _darkMapStyleJson = await rootBundle.loadString('assets/map_styles/dark_style.json');
    // _lightMapStyleJson = await rootBundle.loadString('assets/map_styles/light_style.json');
    // notifyListeners();
  }

  ThemeProvider() {
    // loadMapStyles();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  // --- ADDED HELPER METHOD ---
  bool isDark(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
  }
  // --- END ADDED HELPER METHOD ---

  // --- COLOR DEFINITIONS ---

  // Neutrals
  Color get _appPrimaryBackgroundLight => const Color(0xFFFDFDFD);
  Color get _appPrimaryBackgroundDark => const Color(0xFF121212);
  Color get appPrimaryBackground =>
      _isDarkMode ? _appPrimaryBackgroundDark : _appPrimaryBackgroundLight;

  Color get _appSecondaryBackgroundLight => const Color(0xFFF0F2F5);
  Color get _appSecondaryBackgroundDark => const Color(0xFF1E1E1E);
  Color get appSecondaryBackground =>
      _isDarkMode ? _appSecondaryBackgroundDark : _appSecondaryBackgroundLight;

  Color get _cardBackgroundLight => Colors.white;
  Color get _cardBackgroundDark => const Color(0xFF242A31);
  Color get cardBackground =>
      _isDarkMode ? _cardBackgroundDark : _cardBackgroundLight;

  Color get _primaryTextLight => const Color(0xFF1A1B1F);
  Color get _primaryTextDark => const Color(0xFFE0E0E0);
  Color get primaryText => _isDarkMode ? _primaryTextDark : _primaryTextLight;

  Color get _secondaryTextLight => const Color(0xFF57636C);
  Color get _secondaryTextDark => const Color(0xFFA0AAB9);
  Color get secondaryText =>
      _isDarkMode ? _secondaryTextDark : _secondaryTextLight;

  Color get _tertiaryTextLight => const Color(0xFF7D8B99);
  Color get _tertiaryTextDark => const Color(0xFF6E7A8A);
  Color get tertiaryText =>
      _isDarkMode ? _tertiaryTextDark : _tertiaryTextLight;

  // Brand Colors
  Color get gas2doorPrimaryBlue => const Color(0xFF2A4A7D);
  Color get gas2doorTeal => const Color(0xFF2DB0A0);
  Color get gas2doorPurple => const Color(0xFF8A79B4);

  Color get gas2doorPrimaryBlueLightVer =>
      _isDarkMode ? const Color(0xFF5E7AA0) : const Color(0xFF6C8CBD);
  Color get gas2doorPrimaryBlueDarkVer => const Color(0xFF1E3355);

  Color get gas2doorTealLightVer =>
      _isDarkMode ? const Color(0xFF5BCDBB) : const Color(0xFF66C7BB);
  Color get gas2doorTealDarkVer => const Color(0xFF208073);

  Color get gas2doorPurpleLightVer =>
      _isDarkMode ? const Color(0xFFB0A3D4) : const Color(0xFFA99BC9);
  Color get gas2doorPurpleDarkVer => const Color(0xFF6A5C91);

  // Semantic Colors
  Color get _successColorLight => Colors.green[700]!;
  Color get _successColorDark => const Color(0xFF30A46C);
  Color get successColor =>
      _isDarkMode ? _successColorDark : _successColorLight;

  Color get _errorColorLight => Colors.red[600]!;
  Color get _errorColorDark => const Color(0xFFE5484D);
  Color get errorColor => _isDarkMode ? _errorColorDark : _errorColorLight;

  Color get _warningColorLight => const Color(0xFFFFA000);
  Color get _warningColorDark => const Color(0xFFFFC107);
  Color get warningColor =>
      _isDarkMode ? _warningColorDark : _warningColorLight;

  // Info Colors
  Color get infoColorOnDarkBgs => Colors.white;
  Color get infoColorOnLightBgs => gas2doorPrimaryBlueDarkVer;

  // UI Specific Derived Colors
  Color get _cardShadowColorGlobalLight => Colors.grey.withOpacity(0.35);
  Color get _cardShadowColorGlobalDark => Colors.black.withOpacity(0.5);
  Color get cardShadowColorGlobal =>
      _isDarkMode ? _cardShadowColorGlobalDark : _cardShadowColorGlobalLight;

  Color get _gasLevelProgressBgLight => Colors.grey[300]!;
  Color get _gasLevelProgressBgDark => Colors.grey[700]!.withOpacity(0.5);
  Color get gasLevelProgressBg =>
      _isDarkMode ? _gasLevelProgressBgDark : _gasLevelProgressBgLight;

  Color get _deliveryAddressBgColorLight => Colors.grey[100]!;
  Color get _deliveryAddressBgColorDark => _cardBackgroundDark.withOpacity(0.7);
  Color get deliveryAddressBgColor =>
      _isDarkMode ? _deliveryAddressBgColorDark : _deliveryAddressBgColorLight;

  Color get _recentOrdersSectionBgColorLight => Colors.grey[50]!;
  Color get _recentOrdersSectionBgColorDark =>
      _appSecondaryBackgroundDark.withOpacity(0.6);
  Color get recentOrdersSectionBgColor => _isDarkMode
      ? _recentOrdersSectionBgColorDark
      : _recentOrdersSectionBgColorLight;

  Color get activeOrderStatusLine => gas2doorTeal.withOpacity(0.6);
  Color get inactiveOrderStatusLine =>
      (_isDarkMode ? Colors.grey[700]! : Colors.grey[300]!).withOpacity(0.4);

  // --- ADDED SHIMMER COLORS ---
  Color get _shimmerBaseColorLight => Colors.grey[300]!;
  Color get _shimmerBaseColorDark => Colors.grey[700]!;
  Color get shimmerBaseColor =>
      _isDarkMode ? _shimmerBaseColorDark : _shimmerBaseColorLight;

  Color get _shimmerHighlightColorLight => Colors.grey[100]!;
  Color get _shimmerHighlightColorDark => Colors.grey[600]!;
  Color get shimmerHighlightColor =>
      _isDarkMode ? _shimmerHighlightColorDark : _shimmerHighlightColorLight;
  // --- END ADDED SHIMMER COLORS ---

  double get cardBorderRadiusValue => 15.0;
  BorderRadius get cardBorderRadius =>
      BorderRadius.circular(cardBorderRadiusValue);

  // --- THEME DATA GETTERS ---
  ThemeMode get currentThemeMode =>
      _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: gas2doorPrimaryBlue,
      scaffoldBackgroundColor: _appPrimaryBackgroundLight,
      cardColor: _cardBackgroundLight,
      hintColor: _secondaryTextLight,
      dividerColor: Colors.grey[300],
      colorScheme: ColorScheme.light(
        primary: gas2doorPrimaryBlue,
        secondary: gas2doorTeal,
        surface: _cardBackgroundLight,
        background: _appPrimaryBackgroundLight,
        error: _errorColorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _primaryTextLight,
        onBackground: _primaryTextLight,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _cardBackgroundLight,
        elevation: 2.0,
        shadowColor: _cardShadowColorGlobalLight,
        iconTheme: IconThemeData(color: _secondaryTextLight),
        actionsIconTheme: IconThemeData(color: _secondaryTextLight),
        titleTextStyle: GoogleFonts.inter(
          color: gas2doorPrimaryBlue,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
            color: _primaryTextLight, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.inter(
            color: _primaryTextLight, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.inter(
            color: _primaryTextLight, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(
            color: _primaryTextLight, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(
            color: _primaryTextLight, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(
            color: _primaryTextLight, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: _primaryTextLight),
        bodyMedium: GoogleFonts.inter(color: _secondaryTextLight),
        labelLarge:
            GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        bodySmall: GoogleFonts.inter(color: _tertiaryTextLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: gas2doorPrimaryBlue,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardBorderRadiusValue)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: gas2doorPrimaryBlue,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      )),
      cardTheme: CardTheme(
        elevation: 3.0,
        shadowColor: _cardShadowColorGlobalLight,
        shape: RoundedRectangleBorder(borderRadius: cardBorderRadius),
        color: _cardBackgroundLight,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _cardBackgroundLight,
        selectedItemColor: gas2doorPrimaryBlue,
        unselectedItemColor: _secondaryTextLight,
        elevation: 8.0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: gas2doorPrimaryBlueLightVer,
      scaffoldBackgroundColor: _appPrimaryBackgroundDark,
      cardColor: _cardBackgroundDark,
      hintColor: _secondaryTextDark,
      dividerColor: Colors.grey[700],
      colorScheme: ColorScheme.dark(
        primary: gas2doorPrimaryBlueLightVer,
        secondary: gas2doorTealLightVer,
        surface: _cardBackgroundDark,
        background: _appPrimaryBackgroundDark,
        error: _errorColorDark,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: _primaryTextDark,
        onBackground: _primaryTextDark,
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _cardBackgroundDark,
        elevation: 2.0,
        shadowColor: _cardShadowColorGlobalDark,
        iconTheme: IconThemeData(color: _secondaryTextDark),
        actionsIconTheme: IconThemeData(color: _secondaryTextDark),
        titleTextStyle: GoogleFonts.inter(
          color: gas2doorPrimaryBlueLightVer,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(
            color: _primaryTextDark, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.inter(
            color: _primaryTextDark, fontWeight: FontWeight.bold),
        displaySmall: GoogleFonts.inter(
            color: _primaryTextDark, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(
            color: _primaryTextDark, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(
            color: _primaryTextDark, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(
            color: _primaryTextDark, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: _primaryTextDark),
        bodyMedium: GoogleFonts.inter(color: _secondaryTextDark),
        labelLarge:
            GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        bodySmall: GoogleFonts.inter(color: _tertiaryTextDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: gas2doorPrimaryBlueLightVer,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardBorderRadiusValue)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: gas2doorPrimaryBlueLightVer,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      )),
      cardTheme: CardTheme(
        elevation: 3.0,
        shadowColor: _cardShadowColorGlobalDark,
        shape: RoundedRectangleBorder(borderRadius: cardBorderRadius),
        color: _cardBackgroundDark,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _cardBackgroundDark,
        selectedItemColor: gas2doorPrimaryBlueLightVer,
        unselectedItemColor: _secondaryTextDark,
        elevation: 8.0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
    );
  }
}
