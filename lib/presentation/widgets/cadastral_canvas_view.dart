import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/bluetooth/gnss_device_manager.dart';
import '../../core/nmea/nmea_parser.dart';
import '../../data/models/survey_point_model.dart';
import '../theme/app_theme.dart';

class CadastralCanvasView extends StatefulWidget {
  final List<SurveyPointModel> points;
  final Function(SurveyPointModel)? onSelectPoint;

  const CadastralCanvasView({
    Key? key,
    required this.points,
    this.onSelectPoint,
  }) : super(key: key);

  @override
  State<CadastralCanvasView> createState() => _CadastralCanvasViewState();
}

class _CadastralCanvasViewState extends State<CadastralCanvasView> {
  final GnssDeviceManager _deviceManager = GnssDeviceManager.instance;
  GnssPosition? _roverPosition;

  @override
  void initState() {
    super.initState();
    _roverPosition = _deviceManager.currentPosition;
    _deviceManager.positionStream.listen((pos) {
      if (mounted) setState(() => _roverPosition = pos);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: AppTheme.cardNavy,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.strokeNavy),
        ),
        child: const Center(
          child: Text(
            'Log 2 or more beacons to generate vector boundary polygon.',
            style: TextStyle(color: AppTheme.slateMuted, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.strokeNavy),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: _CadastralMapPainter(
            points: widget.points,
            roverPosition: _roverPosition,
          ),
        ),
      ),
    );
  }
}

class _CadastralMapPainter extends CustomPainter {
  final List<SurveyPointModel> points;
  final GnssPosition? roverPosition;

  _CadastralMapPainter({required this.points, this.roverPosition});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 1. Calculate Bounding Box across all points (and rover if available)
    double minE = points.first.easting;
    double maxE = points.first.easting;
    double minN = points.first.northing;
    double maxN = points.first.northing;

    for (final pt in points) {
      if (pt.easting < minE) minE = pt.easting;
      if (pt.easting > maxE) maxE = pt.easting;
      if (pt.northing < minN) minN = pt.northing;
      if (pt.northing > maxN) maxN = pt.northing;
    }

    if (roverPosition != null) {
      final rE = roverPosition!.minnaUtm.easting;
      final rN = roverPosition!.minnaUtm.northing;
      if (rE < minE) minE = rE;
      if (rE > maxE) maxE = rE;
      if (rN < minN) minN = rN;
      if (rN > maxN) maxN = rN;
    }

    // Add 15% padding
    final rangeE = (maxE - minE) == 0 ? 10.0 : (maxE - minE);
    final rangeN = (maxN - minN) == 0 ? 10.0 : (maxN - minN);

    const padding = 35.0;
    final drawWidth = size.width - (padding * 2);
    final drawHeight = size.height - (padding * 2);

    final scaleX = drawWidth / rangeE;
    final scaleY = drawHeight / rangeN;
    final scale = math.min(scaleX, scaleY);

    final centerX = padding + (drawWidth - (rangeE * scale)) / 2;
    final centerY = padding + (drawHeight - (rangeN * scale)) / 2;

    Offset toCanvas(double easting, double northing) {
      final x = centerX + (easting - minE) * scale;
      // Invert Y axis: North (larger Y) is upward on canvas
      final y = size.height - (centerY + (northing - minN) * scale);
      return Offset(x, y);
    }

    // 2. Draw Subtle Grid Lines
    final gridPaint = Paint()
      ..color = AppTheme.strokeNavy.withOpacity(0.5)
      ..strokeWidth = 0.8;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // 3. Draw Closed Boundary Polygon
    if (points.length >= 2) {
      final path = Path();
      final p0 = toCanvas(points.first.easting, points.first.northing);
      path.moveTo(p0.dx, p0.dy);

      for (int i = 1; i < points.length; i++) {
        final pi = toCanvas(points[i].easting, points[i].northing);
        path.lineTo(pi.dx, pi.dy);
      }
      path.close();

      final polyFill = Paint()
        ..color = AppTheme.crimsonPrimary.withOpacity(0.08)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, polyFill);

      final polyStroke = Paint()
        ..color = AppTheme.crimsonPrimary
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, polyStroke);
    }

    // 4. Draw Beacons and Labels
    final beaconPaint = Paint()
      ..color = AppTheme.pureWhite
      ..style = PaintingStyle.fill;

    final beaconRing = Paint()
      ..color = AppTheme.crimsonAccent
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    for (final pt in points) {
      final pos = toCanvas(pt.easting, pt.northing);
      canvas.drawCircle(pos, 4.0, beaconPaint);
      canvas.drawCircle(pos, 7.0, beaconRing);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: pt.ptName,
          style: const TextStyle(
            color: AppTheme.pureWhite,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx + 9, pos.dy - 6));
    }

    // 5. Draw Live Rover Cursor if available
    if (roverPosition != null) {
      final roverOffset = toCanvas(
        roverPosition!.minnaUtm.easting,
        roverPosition!.minnaUtm.northing,
      );

      final roverPaint = Paint()
        ..color = AppTheme.emeraldSuccess
        ..style = PaintingStyle.fill;
      canvas.drawCircle(roverOffset, 5.0, roverPaint);

      final pulseRing = Paint()
        ..color = AppTheme.emeraldSuccess.withOpacity(0.35)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(roverOffset, 12.0, pulseRing);

      final rtp = TextPainter(
        text: const TextSpan(
          text: 'ROVER (RTK)',
          style: TextStyle(
            color: AppTheme.emeraldSuccess,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      rtp.paint(canvas, Offset(roverOffset.dx + 12, roverOffset.dy - 5));
    }
  }

  @override
  bool shouldRepaint(covariant _CadastralMapPainter oldDelegate) => true;
}
