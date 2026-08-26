import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';

class WheelCanvasPainter extends CustomPainter {
  final List<WheelSegment> segments;

  WheelCanvasPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / segments.length;
    final fontSize = (radius * 0.09).clamp(8.0, 13.0);

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * sweepAngle - (math.pi / 2);
      final slicePaint = Paint()
        ..color = segments[i].color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        slicePaint,
      );

      final borderPaint = Paint()
        ..color = AppColors.glassBorderGold
        ..strokeWidth = (radius * 0.012).clamp(1.0, 1.6)
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      canvas.save();
      final textAngle = startAngle + (sweepAngle / 2);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(radius * 0.52, -textPainter.height / 2),
      );
      canvas.restore();
    }

    final outerRing = Paint()
      ..color = AppColors.primaryGold
      ..strokeWidth = (radius * 0.024).clamp(2.0, 3.5)
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, outerRing);
  }

  @override
  bool shouldRepaint(covariant WheelCanvasPainter oldDelegate) =>
      oldDelegate.segments != segments;
}

class NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = AppColors.goldGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FlexibleWheel extends StatelessWidget {
  final List<WheelSegment> segments;
  final double angle;

  const FlexibleWheel({
    super.key,
    required this.segments,
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = math.min(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final wheelSize = available.clamp(160.0, 280.0);
        final hub = (wheelSize * 0.2).clamp(40.0, 54.0);
        final needleW = (wheelSize * 0.09).clamp(18.0, 26.0);
        final needleH = (wheelSize * 0.11).clamp(22.0, 30.0);

        return SizedBox(
          width: wheelSize,
          height: wheelSize + 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: angle,
                child: CustomPaint(
                  size: Size(wheelSize, wheelSize),
                  painter: WheelCanvasPainter(segments: segments),
                ),
              ),
              Container(
                width: hub,
                height: hub,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                ),
                child: Icon(
                  Icons.casino,
                  color: Colors.black,
                  size: hub * 0.44,
                ),
              ),
              Positioned(
                top: 0,
                child: SizedBox(
                  width: needleW,
                  height: needleH,
                  child: CustomPaint(painter: NeedlePainter()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
