/**
 * NaijaSurveyor Pro - Lodgement & Site Recon Verification Suite
 */

function validatePillar(rawName) {
  const clean = rawName.trim().toUpperCase();
  if (!clean) return { isValid: false, error: 'Pillar designation cannot be empty' };

  // Official state lodgement: e.g. PPA 2026/1024, LA/2026/089, SC 2025/12
  const officialRegex = /^([A-Z]{1,5})[\s/_-]?(\d{4})[/_-](\d{1,6})$/;
  const matchOfficial = clean.match(officialRegex);
  if (matchOfficial) {
    const prefix = matchOfficial[1];
    const year = parseInt(matchOfficial[2], 10);
    const seq = matchOfficial[3];

    const currentYear = new Date().getFullYear();
    if (year < 1960 || year > currentYear + 1) {
      return { isValid: false, error: `Year ${year} outside valid range` };
    }

    return {
      isValid: true,
      formattedName: `${prefix} ${year}/${seq}`,
      pillarType: 'OFFICIAL_LODGEMENT_BEACON',
      prefix,
      year,
      sequence: seq,
    };
  }

  // Field traverse beacon: e.g. P1, P24, BM01
  const seqRegex = /^([A-Z]{1,4})(\d{1,4})$/;
  const matchSeq = clean.match(seqRegex);
  if (matchSeq) {
    return {
      isValid: true,
      formattedName: `${matchSeq[1]}${matchSeq[2]}`,
      pillarType: 'FIELD_TRAVERSE_BEACON',
    };
  }

  return { isValid: true, formattedName: clean, pillarType: 'CUSTOM_IDENTIFIER' };
}

console.log('================================================================');
console.log('NAIJASURVEYOR PRO - LODGEMENT & PILLAR VALIDATION TESTS');
console.log('================================================================\n');

let passed = true;

const testPillars = [
  { input: 'ppa 2026/1024', expected: 'PPA 2026/1024', type: 'OFFICIAL_LODGEMENT_BEACON' },
  { input: 'la/2026/089', expected: 'LA 2026/089', type: 'OFFICIAL_LODGEMENT_BEACON' },
  { input: 'sc 2025-14', expected: 'SC 2025/14', type: 'OFFICIAL_LODGEMENT_BEACON' },
  { input: 'fct_2026/55', expected: 'FCT 2026/55', type: 'OFFICIAL_LODGEMENT_BEACON' },
  { input: 'p12', expected: 'P12', type: 'FIELD_TRAVERSE_BEACON' },
  { input: 'bm03', expected: 'BM03', type: 'FIELD_TRAVERSE_BEACON' },
  { input: 'ppa 1940/10', expectedValid: false }, // Year too old
];

for (const tp of testPillars) {
  const res = validatePillar(tp.input);
  if (tp.expectedValid === false) {
    if (!res.isValid) {
      console.log(`  PASS: Correctly rejected invalid: "${tp.input}" (${res.error})`);
    } else {
      console.error(`  FAIL: Should have rejected: "${tp.input}"`);
      passed = false;
    }
  } else {
    if (res.isValid && res.formattedName === tp.expected && res.pillarType === tp.type) {
      console.log(`  PASS: "${tp.input}" -> "${res.formattedName}" [${res.pillarType}]`);
    } else {
      console.error(`  FAIL: "${tp.input}" -> got "${res.formattedName}", expected "${tp.expected}"`);
      passed = false;
    }
  }
}

console.log('================================================================');
if (passed) {
  console.log('ALL LODGEMENT & PILLAR SYNTAX TESTS PASSED SUCCESSFULLY!');
} else {
  console.log('SOME TESTS FAILED!');
  process.exit(1);
}
