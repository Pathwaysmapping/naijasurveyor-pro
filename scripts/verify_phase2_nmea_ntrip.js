/**
 * NaijaSurveyor Pro - Phase 2 Verification Suite
 * NMEA-0183 Parser & NTRIP Caster Communication Verification
 */

const { Buffer } = require('buffer');

// 1. NMEA Checksum Validation Function
function validateNmeaChecksum(sentence) {
  const clean = sentence.trim();
  if (!clean.startsWith('$') && !clean.startsWith('!')) return false;

  const starIndex = clean.lastIndexOf('*');
  if (starIndex === -1 || starIndex + 3 > clean.length) return false;

  const data = clean.substring(1, starIndex);
  const expectedHex = clean.substring(starIndex + 1, starIndex + 3);
  const expectedChecksum = parseInt(expectedHex, 16);

  let computed = 0;
  for (let i = 0; i < data.length; i++) {
    computed ^= data.charCodeAt(i);
  }

  return computed === expectedChecksum;
}

// 2. Parse Coordinate from DDMM.MMMMM to Decimal Degrees
function parseNmeaCoord(raw, degreeDigits, isNegative) {
  if (raw.length <= degreeDigits) return 0.0;
  const deg = parseFloat(raw.substring(0, degreeDigits));
  const min = parseFloat(raw.substring(degreeDigits));
  const decDeg = deg + (min / 60.0);
  return isNegative ? -decDeg : decDeg;
}

// 3. Parse $GNGGA sentence
function parseGga(sentence) {
  const clean = sentence.trim();
  if (!clean.includes('GGA')) return null;
  if (clean.includes('*') && !validateNmeaChecksum(clean)) {
    throw new Error('NMEA Checksum Validation Failed');
  }

  const body = clean.includes('*') ? clean.substring(0, clean.indexOf('*')) : clean;
  const tokens = body.split(',');
  if (tokens.length < 15) return null;

  const timeStr = tokens[1];
  const latStr = tokens[2];
  const latHem = tokens[3];
  const lonStr = tokens[4];
  const lonHem = tokens[5];
  const fixQuality = parseInt(tokens[6], 10);
  const satellites = parseInt(tokens[7], 10);
  const hdop = parseFloat(tokens[8]);
  const altitude = parseFloat(tokens[9]);
  const geoidalSep = parseFloat(tokens[11]);
  const diffAge = tokens[13] ? parseFloat(tokens[13]) : null;

  const latDeg = parseNmeaCoord(latStr, 2, latHem === 'S');
  const lonDeg = parseNmeaCoord(lonStr, 3, lonHem === 'W');

  return {
    time: timeStr,
    latitude: latDeg,
    longitude: lonDeg,
    fixQuality,
    satellites,
    hdop,
    altitude,
    geoidalSep,
    diffAge,
    isRtkFixed: fixQuality === 4,
  };
}

// 4. Format GGA Feedback for NTRIP Caster
function formatGgaFeedback(latitude, longitude, altitude = 0.0) {
  const absLat = Math.abs(latitude);
  const latDeg = Math.floor(absLat);
  const latMin = (absLat - latDeg) * 60.0;
  const latStr = String(latDeg).padStart(2, '0') + latMin.toFixed(5).padStart(8, '0');
  const latHem = latitude >= 0 ? 'N' : 'S';

  const absLon = Math.abs(longitude);
  const lonDeg = Math.floor(absLon);
  const lonMin = (absLon - lonDeg) * 60.0;
  const lonStr = String(lonDeg).padStart(3, '0') + lonMin.toFixed(5).padStart(8, '0');
  const lonHem = longitude >= 0 ? 'E' : 'W';

  const timeStr = '120530.00';
  const raw = `GPGGA,${timeStr},${latStr},${latHem},${lonStr},${lonHem},1,08,1.0,${altitude.toFixed(1)},M,0.0,M,,`;

  let checksum = 0;
  for (let i = 0; i < raw.length; i++) {
    checksum ^= raw.charCodeAt(i);
  }
  const hex = checksum.toString(16).toUpperCase().padStart(2, '0');
  return `$${raw}*${hex}\r\n`;
}

// 5. Generate NTRIP Client Handshake Header
function generateNtripRequest(host, port, mountpoint, username, password) {
  const auth = Buffer.from(`${username}:${password}`).toString('base64');
  let req = `GET /${mountpoint} HTTP/1.0\r\n`;
  req += `User-Agent: NTRIP NaijaSurveyor/1.0\r\n`;
  req += `Accept: */*\r\n`;
  req += `Connection: close\r\n`;
  if (username) {
    req += `Authorization: Basic ${auth}\r\n`;
  }
  req += `\r\n`;
  return req;
}

// =========================================================================
// TEST EXECUTION
// =========================================================================
console.log('================================================================');
console.log('NAIJASURVEYOR PRO - PHASE 2: NMEA & NTRIP TEST SUITE');
console.log('================================================================\n');

let passed = true;

// Test 1: High-Precision RTK Fixed $GNGGA sentence parsing
console.log('TEST 1: Parsing Real-World RTK Fixed $GNGGA sentence (South/Emlid Rover)');
// Real RTK GNSS sentence in Abuja: Lat 9°04.59000' N (9.0765°), Lon 7°23.91600' E (7.3986°)
const sampleGga = '$GNGGA,112500.00,0904.59000,N,00723.91600,E,4,22,0.7,485.20,M,-28.4,M,1.2,0042*4D';

const parsed = parseGga(sampleGga);
console.log(`  Input Sentence: ${sampleGga}`);
console.log(`  Parsed Latitude:  ${parsed.latitude.toFixed(6)}° N`);
console.log(`  Parsed Longitude: ${parsed.longitude.toFixed(6)}° E`);
console.log(`  Fix Quality:      ${parsed.fixQuality} (RTK FIXED = ${parsed.isRtkFixed})`);
console.log(`  Satellites:       ${parsed.satellites} sats tracked`);
console.log(`  HDOP:             ${parsed.hdop}`);
console.log(`  Elevation:        ${parsed.altitude} m MSL`);
console.log(`  Correction Age:   ${parsed.diffAge} s`);

if (parsed.isRtkFixed && Math.abs(parsed.latitude - 9.0765) < 1e-4 && Math.abs(parsed.longitude - 7.3986) < 1e-4) {
  console.log('  PASS: GNGGA parsed with high precision and valid checksum.\n');
} else {
  console.error('  FAIL: GNGGA parsing error');
  passed = false;
}

// Test 2: NMEA Checksum Tamper Detection
console.log('TEST 2: Checksum Tampering Rejection');
const corruptedSentence = sampleGga.replace('*4D', '*4E');
try {
  parseGga(corruptedSentence);
  console.error('  FAIL: Corrupted checksum was not rejected!');
  passed = false;
} catch (e) {
  console.log(`  PASS: Successfully caught corrupted checksum: "${e.message}"\n`);
}

// Test 3: Client GGA Feedback Formatter for NTRIP VRS
console.log('TEST 3: Formatting Client NMEA GGA for NTRIP VRS Caster Feedback');
const ggaFeedback = formatGgaFeedback(9.076500, 7.398600, 485.2);
console.log(`  Generated GGA: ${ggaFeedback.trim()}`);
const isValidFeedback = validateNmeaChecksum(ggaFeedback.trim());
console.log(`  Checksum Valid: ${isValidFeedback}`);
if (isValidFeedback) {
  console.log('  PASS: GGA feedback conforms to NMEA-0183 standard.\n');
} else {
  console.error('  FAIL: Invalid GGA feedback checksum');
  passed = false;
}

// Test 4: NTRIP 1.0/2.0 Authorization Header & Request
console.log('TEST 4: NTRIP 1.0/2.0 Caster Handshake Header Construction');
const ntripReq = generateNtripRequest('rtk.osgof.gov.ng', 2101, 'ABUJA_VRS', 'surveyor_emmanuel', 'rtkPass2026');
console.log('  Generated Request:');
console.log(ntripReq.split('\r\n').map(l => '    ' + l).join('\r\n'));

if (ntripReq.includes('GET /ABUJA_VRS HTTP/1.0') && ntripReq.includes('Authorization: Basic')) {
  console.log('  PASS: NTRIP Caster request correctly formatted with Basic Auth.\n');
} else {
  console.error('  FAIL: NTRIP request headers malformed');
  passed = false;
}

console.log('================================================================');
if (passed) {
  console.log('ALL PHASE 2 (NMEA & NTRIP) TESTS PASSED SUCCESSFULLY!');
} else {
  console.log('SOME TESTS FAILED!');
  process.exit(1);
}
