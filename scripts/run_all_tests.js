/**
 * NaijaSurveyor Pro - Master Test Suite Runner
 * Runs Phase 1 (Geodetic Transforms), Phase 2 (NMEA & NTRIP), and Phase 3 (Stakeout Geometry)
 */

const { execSync } = require('child_process');
const path = require('path');

const scripts = [
  { name: 'Phase 1: Coordinate Transformations & Geodetic Engine', file: 'verify_transformations.js' },
  { name: 'Phase 2: NMEA-0183 Parser & NTRIP Caster Stream Client', file: 'verify_phase2_nmea_ntrip.js' },
  { name: 'Phase 3: Cadastral Stakeout & Pillar Tracing Geometry', file: 'verify_phase3_stakeout.js' },
];

console.log('================================================================');
console.log('NAIJASURVEYOR PRO (MVP) - FULL INTEGRATION TEST HARNESS');
console.log('================================================================\n');

let allPassed = true;

for (const s of scripts) {
  const filePath = path.join(__dirname, s.file);
  console.log(`>>> EXECUTING: ${s.name} (${s.file})`);
  try {
    const output = execSync(`node "${filePath}"`, { encoding: 'utf8' });
    console.log(output);
  } catch (err) {
    console.error(`ERROR in ${s.name}:`, err.stdout || err.message);
    allPassed = false;
  }
}

console.log('================================================================');
if (allPassed) {
  console.log('SUMMARY: ALL INTEGRATION TEST SUITES COMPLETED WITH 100% PASS RATE!');
  console.log('NaijaSurveyor Pro is ready for field deployment & pilot trials.');
} else {
  console.log('SUMMARY: SOME SUITES FAILED!');
  process.exit(1);
}
