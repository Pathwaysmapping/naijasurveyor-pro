import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/stakeout/stakeout_engine.dart';
import '../theme/app_theme.dart';

class StakeoutBullseye extends StatelessWidget {
  final StakeoutCalculation calculation;
  final double size;

  const StakeoutBullseye({
    Key? key,
    required this.calculation,
    this.size = 280,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.cardNavy,
          shape: BoxShape.circle,
          border: Border.all(
            color: calculation.isTargetReached
                ? AppTheme.emeraldSuccess
                : (calculation.isNearBullseye ? AppTheme.amberWarning : AppTheme.strokeNavy),
            width: calculation.isTargetReached ? 3.0 : 1.5,
          ),
          boxShadow: [
            if (calculation.isTargetReached)
              BoxShadow(
                color: AppTheme.emeraldSuccess.withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: 4,
              ),
          ],
        ),
        child: CustomPaint(
          size: Size(size, size),
          painter: _BullseyePainter(calculation: calculation),
        ),
      ),
    );
  }
}

class _BullseyePainter extends CustomPainter {
  final StakeoutCalculation calculation;

  _BullseyePainter({required this.calculation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppTheme.strokeNavy;

    final crosshairPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = AppTheme.strokeNavy.withOpacity(0.8);

    // 1. Draw Crosshairs (North-South & East-West axes)
    canvas.drawLine(Offset(center.dx, 15), Offset(center.dx, size.height - 15), crosshairPaint);
    canvas.drawLine(Offset(15, center.dy), Offset(size.width - 15, center.dy), crosshairPaint);

    // 2. Draw Cardinal Labels (N, E, S, W)
    _drawCardinalText(canvas, 'N', Offset(center.dx, 8), isNorth: true);
    _drawCardinalText(canvas, 'S', Offset(center.dx, size.height - 14));
    _drawCardinalText(canvas, 'E', Offset(size.width - 10, center.dy));
    _drawCardinalText(canvas, 'W', Offset(10, center.dy));

    // 3. Draw Concentric Range Rings
    // Inner 2cm Stake Target Ring
    final toleranceRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = calculation.isTargetReached ? AppTheme.emeraldSuccess : AppTheme.crimsonPrimary;

    canvas.drawCircle(center, radius * 0.15, toleranceRingPaint);
    canvas.drawCircle(center, radius * 0.40, ringPaint);
    canvas.drawCircle(center, radius * 0.70, ringPaint);

    // 4. Draw Center Target Marker (Pillar Base)
    final targetPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = calculation.isTargetReached ? AppTheme.emeraldSuccess : AppTheme.crimsonAccent;
    canvas.drawCircle(center, 4.0, targetPaint);

    // 5. Draw Rover Position or Direction Vector Pointer
    final dE = calculation.deltaEasting;
    final dN = calculation.deltaNorthing;
    final dist = calculation.distance;

    if (calculation.isTargetReached) {
      // Draw Concentric Target Lock Animation
      final lockPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = AppTheme.emeraldSuccess.withOpacity(0.25);
      canvas.drawCircle(center, radius * 0.15, lockPaint);
    } else {
      // Determine rover offset on canvas relative to target center
      // Max visual radius represents either 2 meters (close) or 10 meters (far)
      final scaleDist = dist < 2.0 ? 2.0 : (dist < 10.0 ? 10.0 : dist);
      final pixelPerMeter = (radius * 0.85) / scaleDist;

      // In screen coords: East is +X, North is -Y
      // Rover position relative to target: Rover is at (-dE, -dN) from target
      final roverOffset = Offset(
        center.dx - (dE * pixelPerMeter).clamp(-radius * 0.85, radius * 0.85),
        center.dy + (dN * pixelPerMeter).clamp(-radius * 0.85, radius * 0.85),
      );

      // Draw vector line from rover to target
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = AppTheme.crimsonPrimary;
      canvas.drawLine(roverOffset, center, linePaint);

      // Draw Rover Cursor
      final roverPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = AppTheme.pureWhite;
      canvas.drawCircle(roverOffset, 6.0, roverPaint);

      final roverRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = AppTheme.crimsonPrimary;
      canvas.drawCircle(roverOffset, 9.0, roverRing);

      // Draw Bearing Pointer Arrow on outer perimeter
      final azimuthRad = calculation.azimuthDegrees * (math.pi / 180.0);
      final arrowX = center.dx + (radius - 12) * math.sin(azimuthRad);
      final arrowY = center.dy - (radius - 12) * math.cos(azimuthRad);

      final arrowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = AppTheme.crimsonAccent;
      canvas.drawCircle(Offset(arrowX, arrowY), 4.0, arrowPaint);
    }
  }

  void _drawCardinalText(Canvas canvas, String text, Offset pos, {bool isNorth = false}) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isNorth ? AppTheme.crimsonAccent : AppTheme.slateMuted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BullseyePainter oldDelegate) {
    return oldDelegate.calculation.distance != calculation.distance ||
        oldDelegate.calculation.azimuthDegrees != calculation.azimuthDegrees;
  }
}
