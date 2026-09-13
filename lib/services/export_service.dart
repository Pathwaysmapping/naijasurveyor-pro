import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/models/job_model.dart';
import '../data/models/survey_point_model.dart';

class ExportService {
  /// Generates a standardized Nigerian Institution of Surveyors (NIS) CSV format
  static String generateNisCsv({
    required JobModel job,
    required List<SurveyPointModel> points,
  }) {
    final buffer = StringBuffer();

    // Standard Header Line for Nigerian Cadastral Data
    buffer.writeln('# NAIJASURVEYOR PRO - CADASTRAL POINT EXPORT');
    buffer.writeln('# Job Number: ${job.jobNum}');
    buffer.writeln('# Coordinate Reference System: ${job.datum} (UTM Zone ${job.zone}N)');
    buffer.writeln('# Total Points: ${points.length}');
    buffer.writeln('# Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# -------------------------------------------------------------');
    buffer.writeln('POINT_ID,EASTING,NORTHING,HEIGHT,TYPE,TIMESTAMP');

    for (final pt in points) {
      buffer.writeln(
        '${pt.ptName},'
        '${pt.easting.toStringAsFixed(3)},'
        '${pt.northing.toStringAsFixed(3)},'
        '${pt.height.toStringAsFixed(3)},'
        '${pt.ptType.name},'
        '${pt.createdAt}',
      );
    }

    return buffer.toString();
  }

  /// Generates an AutoCAD R12 DXF ASCII text file with layers, point nodes, and text labels
  static String generateCadDxf({
    required JobModel job,
    required List<SurveyPointModel> points,
  }) {
    final buffer = StringBuffer();

    // DXF Header
    buffer.writeln('0\nSECTION\n2\nHEADER\n0\nENDSEC');

    // DXF Tables (Layers Definition)
    buffer.writeln('0\nSECTION\n2\nTABLES');
    buffer.writeln('0\nTABLE\n2\nLAYER\n70\n2');
    // Layer 1: BEACONS (Color: Red - 1)
    buffer.writeln('0\nLAYER\n2\nBEACONS\n70\n0\n62\n1\n6\nCONTINUOUS');
    // Layer 2: BEACON_LABELS (Color: Yellow - 2)
    buffer.writeln('0\nLAYER\n2\nBEACON_LABELS\n70\n0\n62\n2\n6\nCONTINUOUS');
    buffer.writeln('0\nENDTAB\n0\nENDSEC');

    // DXF Entities
    buffer.writeln('0\nSECTION\n2\nENTITIES');

    for (final pt in points) {
      // 1. POINT Node Entity
      buffer.writeln('0\nPOINT');
      buffer.writeln('8\nBEACONS'); // Layer name
      buffer.writeln('10\n${pt.easting.toStringAsFixed(4)}');  // X
      buffer.writeln('20\n${pt.northing.toStringAsFixed(4)}'); // Y
      buffer.writeln('30\n${pt.height.toStringAsFixed(4)}');   // Z

      // 2. TEXT Entity for the Beacon Name
      buffer.writeln('0\nTEXT');
      buffer.writeln('8\nBEACON_LABELS');
      // Offset text slightly (0.75m northeast) so it doesn't obscure the point center
      buffer.writeln('10\n${(pt.easting + 0.75).toStringAsFixed(4)}');
      buffer.writeln('20\n${(pt.northing + 0.75).toStringAsFixed(4)}');
      buffer.writeln('30\n${pt.height.toStringAsFixed(4)}');
      buffer.writeln('40\n1.2'); // Text Height: 1.2 meters
      buffer.writeln('1\n${pt.ptName}'); // Text content
    }

    // Connect boundary lines if there are 2 or more beacons
    if (points.length >= 2) {
      for (int i = 0; i < points.length; i++) {
        final p1 = points[i];
        final p2 = points[(i + 1) % points.length]; // Closed loop back to first beacon

        buffer.writeln('0\nLINE');
        buffer.writeln('8\nBOUNDARY_LINES');
        buffer.writeln('10\n${p1.easting.toStringAsFixed(4)}');
        buffer.writeln('20\n${p1.northing.toStringAsFixed(4)}');
        buffer.writeln('30\n${p1.height.toStringAsFixed(4)}');
        buffer.writeln('11\n${p2.easting.toStringAsFixed(4)}');
        buffer.writeln('21\n${p2.northing.toStringAsFixed(4)}');
        buffer.writeln('31\n${p2.height.toStringAsFixed(4)}');
      }
    }

    buffer.writeln('0\nENDSEC');
    buffer.writeln('0\nEOF');

    return buffer.toString();
  }

  /// Exports and saves CSV to device storage
  static Future<File> saveCsvToFile({
    required JobModel job,
    required List<SurveyPointModel> points,
  }) async {
    final csvContent = generateNisCsv(job: job, points: points);
    final directory = await getApplicationDocumentsDirectory();
    final sanitizedJobNum = job.jobNum.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}/NaijaSurveyor_${sanitizedJobNum}_NIS.csv');
    return await file.writeAsString(csvContent);
  }

  /// Exports and saves DXF to device storage
  static Future<File> saveDxfToFile({
    required JobModel job,
    required List<SurveyPointModel> points,
  }) async {
    final dxfContent = generateCadDxf(job: job, points: points);
    final directory = await getApplicationDocumentsDirectory();
    final sanitizedJobNum = job.jobNum.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${directory.path}/NaijaSurveyor_${sanitizedJobNum}.dxf');
    return await file.writeAsString(dxfContent);
  }
}
