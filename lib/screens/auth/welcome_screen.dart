import 'package:flutter/material.dart';
import '../../widgets/button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to PrimeJet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Customer Login',
              color: const Color(0xFF324681),
              onPressed: () => Navigator.pushNamed(context, '/customer_login'),
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Driver Login',
              color: const Color(0xFF324681),
              onPressed: () => Navigator.pushNamed(context, '/driver_login'),
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Admin Login',
              color: const Color(0xFF324681),
              onPressed: () => Navigator.pushNamed(context, '/admin_login'),
            ),
          ],
        ),
      ),
    );
  }
}
