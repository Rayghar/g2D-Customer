// File: lib/screens/auth/splash_screen.dart
// ADVISORY: This version includes the requested layout refinements.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import '../../providers/theme_provider.dart';
import './customer_login_screen.dart';
import '../customer/customer_dashboard_screen.dart';
import '../../widgets/curve_painter.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _iconsAnimationController;
  late Animation<double> _icon1Animation;
  late Animation<double> _icon2Animation;
  late Animation<double> _icon3Animation;

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

    _iconsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _icon1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconsAnimationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _icon2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconsAnimationController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _icon3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconsAnimationController,
        curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward().then((_) {
      _iconsAnimationController.forward();
    });
    _navigateBasedOnAuth();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _iconsAnimationController.dispose();
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
      body: Stack(
        children: [
          Container(
            color: Colors.grey.shade200,
          ),
          Positioned(
            top: -MediaQuery.of(context).size.height * 0.3,
            left: -MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade300.withOpacity(0.7),
                    Colors.red.shade300.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.3, 0.7],
                ),
              ),
              child: Transform.rotate(
                angle: -0.2,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width * 1.2,
                      MediaQuery.of(context).size.height * 0.8),
                  painter: CurvePainter(),
                ),
              ),
            ),
          ),
          Positioned(
            // ADDED: Replicated graphic on the bottom half
            bottom: -MediaQuery.of(context).size.height * 0.3,
            right: -MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: MediaQuery.of(context).size.width * 1.2,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // MODIFIED: Gradient colors for a blue-ish variant
                  colors: [
                    Colors.blue.shade800.withOpacity(0.5),
                    Colors.blue.shade300.withOpacity(0.5),
                  ],
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  stops: const [0.3, 0.7],
                ),
              ),
              child: Transform.rotate(
                angle: 0.2,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width * 1.2,
                      MediaQuery.of(context).size.height * 0.8),
                  painter: CurvePainter(),
                ),
              ),
            ),
          ),
          // MODIFIED: Animated icons now positioned on the new background
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            top: _icon1Animation.value *
                MediaQuery.of(context).size.height *
                0.15,
            left: _icon1Animation.value *
                MediaQuery.of(context).size.width *
                0.15,
            child: Opacity(
              opacity: _icon1Animation.value,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(Icons.local_gas_station_outlined,
                    size: 30, color: Colors.white),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            top: _icon2Animation.value *
                MediaQuery.of(context).size.height *
                0.4,
            left:
                _icon2Animation.value * MediaQuery.of(context).size.width * 0.4,
            child: Opacity(
              opacity: _icon2Animation.value,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(Icons.local_shipping_outlined,
                    size: 30, color: Colors.white),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            top: _icon3Animation.value *
                MediaQuery.of(context).size.height *
                0.65,
            left:
                _icon3Animation.value * MediaQuery.of(context).size.width * 0.7,
            child: Opacity(
              opacity: _icon3Animation.value,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(Icons.location_on_outlined,
                    size: 30, color: Colors.white),
              ),
            ),
          ),
          Center(
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
                      height: 180, // MODIFIED: Bigger logo
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.local_gas_station_rounded,
                        size: 180, // MODIFIED: Bigger logo
                        color: themeProvider.primaryActionColor,
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
                      fontSize: 30, // MODIFIED: Crisper text
                      fontWeight: FontWeight.w900, // MODIFIED: Crisper text
                      color: Colors.black, // MODIFIED: Crisper text
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const Spacer(),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      themeProvider.primaryActionColor),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
