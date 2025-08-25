// File: lib/widgets/curve_painter.dart
import 'package:flutter/material.dart';

class CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.blue.shade300.withOpacity(0.5),
          Colors.red.shade300.withOpacity(0.5),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.3, 0.7],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    var path = Path();

    path.moveTo(size.width * 0.3, 0);
    path.quadraticBezierTo(size.width * 0.1, size.height * 0.3,
        size.width * 0.3, size.height * 0.5);
    path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.8, size.width * 0.7, size.height);

    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
