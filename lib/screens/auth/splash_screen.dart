// File: lib/screens/auth/splash_screen.dart
// ADVISORY: This version includes the requested layout refinements.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../providers/theme_provider.dart';
import './customer_login_screen.dart';
import '../customer/customer_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _navigateBasedOnAuth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateBasedOnAuth() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    // TODO: Replace this with your actual authentication logic from a service
    const String? userRole = null; // Example: 'customer', 'admin', or null

    if (userRole == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } else if (userRole == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver_dashboard');
    } else if (userRole == 'customer') {
      Navigator.pushReplacementNamed(
          context, CustomerDashboardScreen.routeName);
    } else {
      Navigator.pushReplacementNamed(context, CustomerLoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeProvider.loginScreenGradientStart,
              themeProvider.loginScreenGradientEnd,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/images/gas2door_logo.png',
                    // MODIFIED: Logo height increased for more impact
                    height: 120,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.local_gas_station_rounded,
                      size: 120,
                      color: themeProvider.textOnDarkGradient,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Gas2Door',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.textOnDarkGradient,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
