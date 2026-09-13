/**
 * NaijaSurveyor Pro - Phase 3 Verification Suite
 * Cadastral Stakeout Geometry & Pillar Tracing Navigation Logic
 */

function calculateStakeout(currentE, currentN, currentH, targetE, targetN, targetH, tolerance = 0.02) {
  const dE = targetE - currentE;
  const dN = targetN - currentN;
  const dH = targetH - currentH;

  const distance = Math.sqrt(dE * dE + dN * dN);

  let angleRad = Math.atan2(dE, dN);
  let azimuthDeg = angleRad * (180.0 / Math.PI);
  if (azimuthDeg < 0) azimuthDeg += 360.0;

  const isTargetReached = distance <= tolerance;
  const isNearBullseye = distance <= 0.50;

  const nText = dN >= 0 ? `GO NORTH ${Math.abs(dN).toFixed(3)} m` : `GO SOUTH ${Math.abs(dN).toFixed(3)} m`;
  const eText = dE >= 0 ? `GO EAST ${Math.abs(dE).toFixed(3)} m` : `GO WEST ${Math.abs(dE).toFixed(3)} m`;
  const directionInstructions = isTargetReached ? 'ON TARGET (WITHIN 2CM TOLERANCE)' : `${nText} | ${eText}`;

  let audioBeepIntervalMs = 3000;
  if (distance <= 0.02) audioBeepIntervalMs = 100;
  else if (distance <= 0.20) audioBeepIntervalMs = 200;
  else if (distance <= 0.50) audioBeepIntervalMs = 400;
  else if (distance <= 1.50) audioBeepIntervalMs = 800;
  else if (distance <= 5.00) audioBeepIntervalMs = 1500;

  return {
    distance,
    deltaEasting: dE,
    deltaNorthing: dN,
    deltaHeight: dH,
    azimuthDeg,
    isTargetReached,
    isNearBullseye,
    directionInstructions,
    audioBeepIntervalMs,
  };
}

console.log('================================================================');
console.log('NAIJASURVEYOR PRO - PHASE 3: STAKEOUT & PILLAR TRACING TESTS');
console.log('================================================================\n');

let allPassed = true;

// Test Case 1: Target to the North-East (Quadrant 1)
console.log('TEST 1: Target North-East (e.g. Rover approaching Beacon P1)');
const target1 = { e: 324100.0, n: 1003600.0, h: 485.0 };
const rover1 = { e: 324097.0, n: 1003596.0, h: 485.0 }; // 3m East, 4m North -> dist = 5.0m, bearing = ~36.87°

const res1 = calculateStakeout(rover1.e, rover1.n, rover1.h, target1.e, target1.n, target1.h);
console.log(`  Distance to Target: ${res1.distance.toFixed(3)} m (Expected: 5.000 m)`);
console.log(`  Azimuth Bearing:    ${res1.azimuthDeg.toFixed(2)}° (Expected: ~36.87°)`);
console.log(`  Instructions:       "${res1.directionInstructions}"`);
console.log(`  Beep Interval:      ${res1.audioBeepIntervalMs} ms`);

if (Math.abs(res1.distance - 5.0) < 0.001 && Math.abs(res1.azimuthDeg - 36.87) < 0.05 && res1.directionInstructions.includes('GO NORTH') && res1.directionInstructions.includes('GO EAST')) {
  console.log('  PASS: Quadrant 1 calculation verified.\n');
} else {
  console.error('  FAIL: Quadrant 1 calculation error');
  allPassed = false;
}

// Test Case 2: Target to the South-West (Quadrant 3)
console.log('TEST 2: Target South-West (e.g. Rover passed beyond target)');
const rover2 = { e: 324102.0, n: 1003602.0, h: 485.0 }; // Target is 2m West, 2m South -> dist = 2.828m, bearing = 225.0°
const res2 = calculateStakeout(rover2.e, rover2.n, rover2.h, target1.e, target1.n, target1.h);
console.log(`  Distance to Target: ${res2.distance.toFixed(3)} m`);
console.log(`  Azimuth Bearing:    ${res2.azimuthDeg.toFixed(2)}° (Expected: 225.00°)`);
console.log(`  Instructions:       "${res2.directionInstructions}"`);

if (Math.abs(res2.azimuthDeg - 225.0) < 0.01 && res2.directionInstructions.includes('GO SOUTH') && res2.directionInstructions.includes('GO WEST')) {
  console.log('  PASS: Quadrant 3 calculation verified.\n');
} else {
  console.error('  FAIL: Quadrant 3 calculation error');
  allPassed = false;
}

// Test Case 3: On-Target 2cm Survey Cadastral Tolerance Lock
console.log('TEST 3: Sub-Centimeter Stakeout Tolerance Lock (<= 2cm / 0.02m)');
const rover3 = { e: 324099.990, n: 1003599.992, h: 485.0 }; // Dist = sqrt(0.01^2 + 0.008^2) = 0.0128m < 2cm
const res3 = calculateStakeout(rover3.e, rover3.n, rover3.h, target1.e, target1.n, target1.h);
console.log(`  Residual Offset:    ${(res3.distance * 1000).toFixed(1)} mm`);
console.log(`  Target Lock Status: ${res3.isTargetReached ? 'LOCKED ON TARGET' : 'NOT REACHED'}`);
console.log(`  Audio Beep Pulse:   ${res3.audioBeepIntervalMs} ms (Continuous 10Hz tone)`);

if (res3.isTargetReached && res3.audioBeepIntervalMs === 100) {
  console.log('  PASS: 2cm Cadastral tolerance trigger verified successfully.\n');
} else {
  console.error('  FAIL: Stakeout tolerance detection failed');
  allPassed = false;
}

console.log('================================================================');
if (allPassed) {
  console.log('ALL PHASE 3 (STAKEOUT & PILLAR TRACING) TESTS PASSED SUCCESSFULLY!');
} else {
  console.log('SOME TESTS FAILED!');
  process.exit(1);
}
