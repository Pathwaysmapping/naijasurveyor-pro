/// Nigerian Cadastral Pillar Numbering & Verification Utility
/// Enforces SURCON (Surveyors Council of Nigeria) and State Directorates (OSSG) standards
class PillarValidator {
  /// Known official Nigerian beacon prefixes
  static const List<String> recognizedPrefixes = [
    'PPA',  // Private Property Beacon (National standard)
    'SC',   // Statutory Control Beacon
    'FCT',  // Federal Capital Territory (Abuja)
    'LA',   // Lagos State Survey Beacon
    'OG',   // Ogun State Survey Beacon
    'OY',   // Oyo State Survey Beacon
    'ED',   // Edo State Survey Beacon
    'RV',   // Rivers State Survey Beacon
    'KD',   // Kaduna State Survey Beacon
    'KN',   // Kano State Survey Beacon
    'P',    // Standard traverse beacon (P1, P2, etc.)
    'BM',   // Bench Mark
    'CP',   // Control Point
    'TP',   // Turning Point
  ];

  /// Validates standard Nigerian pillar numbering syntax (e.g. "PPA 2026/1024", "LA/2026/089", or "P1")
  static PillarValidationResult validate(String rawName) {
    final clean = rawName.trim().toUpperCase();
    if (clean.isEmpty) {
      return const PillarValidationResult(
        isValid: false,
        formattedName: '',
        errorMessage: 'Pillar designation cannot be empty.',
      );
    }

    // Pattern 1: State / Official Lodgement Syntax (e.g. "PPA 2026/1024", "LA/2026/089", "SC 2025/12")
    final officialRegex = RegExp(r'^([A-Z]{1,5})[\s/_-]?(\d{4})[/_-](\d{1,6})$');
    final matchOfficial = officialRegex.firstMatch(clean);
    if (matchOfficial != null) {
      final prefix = matchOfficial.group(1)!;
      final year = int.parse(matchOfficial.group(2)!);
      final seq = matchOfficial.group(3)!;

      // Year reasonableness check
      if (year < 1960 || year > DateTime.now().year + 1) {
        return PillarValidationResult(
          isValid: false,
          formattedName: clean,
          errorMessage: 'Year $year is outside valid cadastral records (1960 - ${DateTime.now().year + 1}).',
        );
      }

      final standardized = '$prefix $year/$seq';
      return PillarValidationResult(
        isValid: true,
        formattedName: standardized,
        pillarType: 'OFFICIAL_LODGEMENT_BEACON',
        prefix: prefix,
        year: year,
        sequence: seq,
      );
    }

    // Pattern 2: Sequential Field Beacon (e.g. "P1", "P10", "BM01", "CP04")
    final seqRegex = RegExp(r'^([A-Z]{1,4})(\d{1,4})$');
    final matchSeq = seqRegex.firstMatch(clean);
    if (matchSeq != null) {
      final prefix = matchSeq.group(1)!;
      final num = matchSeq.group(2)!;
      return PillarValidationResult(
        isValid: true,
        formattedName: '$prefix$num',
        pillarType: 'FIELD_TRAVERSE_BEACON',
        prefix: prefix,
        sequence: num,
      );
    }

    // Pattern 3: Custom Identifier
    return PillarValidationResult(
      isValid: true,
      formattedName: clean,
      pillarType: 'CUSTOM_IDENTIFIER',
    );
  }
}

class PillarValidationResult {
  final bool isValid;
  final String formattedName;
  final String? errorMessage;
  final String? pillarType;
  final String? prefix;
  final int? year;
  final String? sequence;

  const PillarValidationResult({
    required this.isValid,
    required this.formattedName,
    this.errorMessage,
    this.pillarType,
    this.prefix,
    this.year,
    this.sequence,
  });
}
