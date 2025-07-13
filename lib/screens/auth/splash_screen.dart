import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/splash';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateBasedOnAuth();
  }

  Future<void> _navigateBasedOnAuth() async {
    await Future.delayed(
        const Duration(seconds: 4)); // Simulate loading/auth check

    if (!mounted) return;

    // Mock authentication check - replace with actual logic
    const String userRole =
        ''; // Could be 'admin', 'customer', or null (not logged in)
    const String userId = ' '; // Mock user ID

    if (userRole == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } else if (userRole == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver_dashboard');
    } else if (userRole == 'customer') {
      Navigator.pushReplacementNamed(context, '/customer_dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/customer_login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/gas2door_logo.png',
              height: 100,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.local_gas_station_rounded,
                size: 100,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Gas2Door by PrimeJet',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
