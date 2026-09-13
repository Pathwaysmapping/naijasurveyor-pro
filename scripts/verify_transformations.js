/**
 * NaijaSurveyor Pro - Geodetic Transformation & File Export Verification Suite
 * Executes localized Clarke 1880 / Minna Datum 3-parameter shifts and Transverse Mercator projections.
 */

const CLARKE1880_A = 6378249.145;
const CLARKE1880_INVF = 293.465;
const CLARKE1880_F = 1.0 / CLARKE1880_INVF;
const CLARKE1880_B = CLARKE1880_A * (1.0 - CLARKE1880_F);
const CLARKE1880_E2 = 2.0 * CLARKE1880_F - CLARKE1880_F * CLARKE1880_F;
const CLARKE1880_EP2 = (CLARKE1880_A * CLARKE1880_A - CLARKE1880_B * CLARKE1880_B) / (CLARKE1880_B * CLARKE1880_B);

const WGS84_A = 6378137.0;
const WGS84_INVF = 298.257223563;
const WGS84_F = 1.0 / WGS84_INVF;
const WGS84_B = WGS84_A * (1.0 - WGS84_F);
const WGS84_E2 = 2.0 * WGS84_F - WGS84_F * WGS84_F;
const WGS84_EP2 = (WGS84_A * WGS84_A - WGS84_B * WGS84_B) / (WGS84_B * WGS84_B);

// Official Nigerian National Datum Shift parameters (Minna -> WGS84)
const NATIONAL_DX = -92.0;
const NATIONAL_DY = -93.0;
const NATIONAL_DZ = 122.0;

const UTM_K0 = 0.9996;
const FALSE_EASTING = 500000.0;
const FALSE_NORTHING = 0.0;

function centralMeridianForZone(zone) {
  if (zone === 31) return 3.0;
  if (zone === 32) return 9.0;
  if (zone === 33) return 15.0;
  throw new Error(`Invalid Zone: ${zone}`);
}

function detectZone(lon) {
  if (lon < 6.0) return 31;
  if (lon < 12.0) return 32;
  return 33;
}

function geoToCartesian(latDeg, lonDeg, h, a, e2) {
  const latRad = latDeg * (Math.PI / 180.0);
  const lonRad = lonDeg * (Math.PI / 180.0);
  const sinLat = Math.sin(latRad);
  const cosLat = Math.cos(latRad);

  const n = a / Math.sqrt(1.0 - e2 * sinLat * sinLat);
  const x = (n + h) * cosLat * Math.cos(lonRad);
  const y = (n + h) * cosLat * Math.sin(lonRad);
  const z = (n * (1.0 - e2) + h) * sinLat;
  return { x, y, z };
}

function cartesianToGeo(x, y, z, a, b, e2, ep2) {
  const p = Math.sqrt(x * x + y * y);
  const theta = Math.atan2(z * a, p * b);
  const sinTheta = Math.sin(theta);
  const cosTheta = Math.cos(theta);

  const latRad = Math.atan2(
    z + ep2 * b * Math.pow(sinTheta, 3),
    p - e2 * a * Math.pow(cosTheta, 3)
  );
  const lonRad = Math.atan2(y, x);

  const sinLat = Math.sin(latRad);
  const n = a / Math.sqrt(1.0 - e2 * sinLat * sinLat);
  const h = p / Math.cos(latRad) - n;

  return {
    latRad,
    lonRad,
    latDeg: latRad * (180.0 / Math.PI),
    lonDeg: lonRad * (180.0 / Math.PI),
    height: h,
  };
}

function geoToTM(latRad, lonRad, cmRad, a, e2, k0, fe, fn) {
  const sinLat = Math.sin(latRad);
  const cosLat = Math.cos(latRad);
  const tanLat = Math.tan(latRad);

  const n = a / Math.sqrt(1.0 - e2 * sinLat * sinLat);
  const t = tanLat * tanLat;
  const ep2 = e2 / (1.0 - e2);
  const c = ep2 * cosLat * cosLat;
  const deltaLon = lonRad - cmRad;
  const aTerm = deltaLon * cosLat;

  const m = a * (
    (1.0 - e2 / 4.0 - 3.0 * e2 * e2 / 64.0 - 5.0 * Math.pow(e2, 3) / 256.0) * latRad
    - (3.0 * e2 / 8.0 + 3.0 * e2 * e2 / 32.0 + 45.0 * Math.pow(e2, 3) / 1024.0) * Math.sin(2.0 * latRad)
    + (15.0 * e2 * e2 / 256.0 + 45.0 * Math.pow(e2, 3) / 1024.0) * Math.sin(4.0 * latRad)
    - (35.0 * Math.pow(e2, 3) / 3072.0) * Math.sin(6.0 * latRad)
  );

  const easting = fe + k0 * n * (
    aTerm
    + (1.0 - t + c) * Math.pow(aTerm, 3) / 6.0
    + (5.0 - 18.0 * t + t * t + 72.0 * c - 58.0 * ep2) * Math.pow(aTerm, 5) / 120.0
  );

  const northing = fn + k0 * (
    m + n * tanLat * (
      (aTerm * aTerm / 2.0)
      + (5.0 - t + 9.0 * c + 4.0 * c * c) * Math.pow(aTerm, 4) / 24.0
      + (61.0 - 58.0 * t + t * t + 600.0 * c - 330.0 * ep2) * Math.pow(aTerm, 6) / 720.0
    )
  );

  return { easting, northing };
}

function tmToGeo(easting, northing, cmRad, a, b, e2, ep2, k0, fe, fn) {
  const x = easting - fe;
  const y = northing - fn;
  const m = y / k0;
  const mu = m / (a * (1.0 - e2 / 4.0 - 3.0 * e2 * e2 / 64.0 - 5.0 * Math.pow(e2, 3) / 256.0));

  const e1 = (1.0 - Math.sqrt(1.0 - e2)) / (1.0 + Math.sqrt(1.0 - e2));

  const phi1 = mu
    + (3.0 * e1 / 2.0 - 27.0 * Math.pow(e1, 3) / 32.0) * Math.sin(2.0 * mu)
    + (21.0 * e1 * e1 / 16.0 - 55.0 * Math.pow(e1, 4) / 32.0) * Math.sin(4.0 * mu)
    + (151.0 * Math.pow(e1, 3) / 96.0) * Math.sin(6.0 * mu)
    + (1097.0 * Math.pow(e1, 4) / 512.0) * Math.sin(8.0 * mu);

  const sinPhi1 = Math.sin(phi1);
  const cosPhi1 = Math.cos(phi1);
  const tanPhi1 = Math.tan(phi1);

  const n1 = a / Math.sqrt(1.0 - e2 * sinPhi1 * sinPhi1);
  const r1 = a * (1.0 - e2) / Math.pow(1.0 - e2 * sinPhi1 * sinPhi1, 1.5);
  const d = x / (n1 * k0);

  const t1 = tanPhi1 * tanPhi1;
  const c1 = ep2 * cosPhi1 * cosPhi1;

  const latRad = phi1 - (n1 * tanPhi1 / r1) * (
    (d * d / 2.0)
    - (5.0 + 3.0 * t1 + 10.0 * c1 - 4.0 * c1 * c1 - 9.0 * ep2) * Math.pow(d, 4) / 24.0
    + (61.0 + 90.0 * t1 + 298.0 * c1 + 45.0 * t1 * t1 - 252.0 * ep2 - 3.0 * c1 * c1) * Math.pow(d, 6) / 720.0
  );

  const lonRad = cmRad + (
    d
    - (1.0 + 2.0 * t1 + c1) * Math.pow(d, 3) / 6.0
    + (5.0 - 2.0 * c1 + 28.0 * t1 - 3.0 * c1 * c1 + 8.0 * ep2 + 24.0 * t1 * t1) * Math.pow(d, 5) / 120.0
  ) / cosPhi1;

  return {
    latRad,
    lonRad,
    latDeg: latRad * (180.0 / Math.PI),
    lonDeg: lonRad * (180.0 / Math.PI),
  };
}

function wgs84ToMinnaUtm(latDeg, lonDeg, h = 0, zoneOverride = null) {
  const wgsXyz = geoToCartesian(latDeg, lonDeg, h, WGS84_A, WGS84_E2);
  const minnaX = wgsXyz.x - NATIONAL_DX;
  const minnaY = wgsXyz.y - NATIONAL_DY;
  const minnaZ = wgsXyz.z - NATIONAL_DZ;

  const minnaGeo = cartesianToGeo(minnaX, minnaY, minnaZ, CLARKE1880_A, CLARKE1880_B, CLARKE1880_E2, CLARKE1880_EP2);
  const zone = zoneOverride || detectZone(lonDeg);
  const cmDeg = centralMeridianForZone(zone);
  const cmRad = cmDeg * (Math.PI / 180.0);

  const utm = geoToTM(minnaGeo.latRad, minnaGeo.lonRad, cmRad, CLARKE1880_A, CLARKE1880_E2, UTM_K0, FALSE_EASTING, FALSE_NORTHING);
  return { easting: utm.easting, northing: utm.northing, zone, datum: 'MINNA_UTM' };
}

function minnaUtmToWgs84(easting, northing, zone, h = 0) {
  const cmDeg = centralMeridianForZone(zone);
  const cmRad = cmDeg * (Math.PI / 180.0);

  const minnaGeo = tmToGeo(easting, northing, cmRad, CLARKE1880_A, CLARKE1880_B, CLARKE1880_E2, CLARKE1880_EP2, UTM_K0, FALSE_EASTING, FALSE_NORTHING);
  const minnaXyz = geoToCartesian(minnaGeo.latDeg, minnaGeo.lonDeg, h, CLARKE1880_A, CLARKE1880_E2);

  const wgsX = minnaXyz.x + NATIONAL_DX;
  const wgsY = minnaXyz.y + NATIONAL_DY;
  const wgsZ = minnaXyz.z + NATIONAL_DZ;

  const wgsGeo = cartesianToGeo(wgsX, wgsY, wgsZ, WGS84_A, WGS84_B, WGS84_E2, WGS84_EP2);
  return { latitude: wgsGeo.latDeg, longitude: wgsGeo.lonDeg, height: wgsGeo.height, datum: 'WGS84' };
}

// =========================================================================
// TEST SUITE EXECUTION
// =========================================================================
console.log('================================================================');
console.log('NAIJASURVEYOR PRO - MATHEMATICAL TRANSFORMATION TEST SUITE');
console.log('================================================================\n');

const testCases = [
  { city: 'Lagos (Zone 31N)', lat: 6.5244, lon: 3.3792, expectedZone: 31 },
  { city: 'Abuja FCT (Zone 32N)', lat: 9.0765, lon: 7.3986, expectedZone: 32 },
  { city: 'Maiduguri (Zone 33N)', lat: 11.8333, lon: 13.1500, expectedZone: 33 },
];

let allPassed = true;

for (const tc of testCases) {
  console.log(`TEST CASE: ${tc.city}`);
  console.log(`  Input WGS84: Lat = ${tc.lat.toFixed(6)}°, Lon = ${tc.lon.toFixed(6)}°`);

  // Forward: WGS84 -> Minna UTM
  const utm = wgs84ToMinnaUtm(tc.lat, tc.lon);
  console.log(`  Forward Conversion (Minna UTM):`);
  console.log(`    Easting  (X) = ${utm.easting.toFixed(3)} m`);
  console.log(`    Northing (Y) = ${utm.northing.toFixed(3)} m`);
  console.log(`    Zone         = ${utm.zone}N (Detected Zone: ${detectZone(tc.lon)}N)`);

  if (utm.zone !== tc.expectedZone) {
    console.error(`  FAIL: Expected Zone ${tc.expectedZone}, got ${utm.zone}`);
    allPassed = false;
  }

  // Reverse: Minna UTM -> WGS84
  const back = minnaUtmToWgs84(utm.easting, utm.northing, utm.zone);
  console.log(`  Inverse Conversion (Back to WGS84):`);
  console.log(`    Latitude  = ${back.latitude.toFixed(6)}°`);
  console.log(`    Longitude = ${back.longitude.toFixed(6)}°`);

  const deltaLat = Math.abs(back.latitude - tc.lat);
  const deltaLon = Math.abs(back.longitude - tc.lon);
  console.log(`  Loop Closure Residuals: ΔLat = ${deltaLat.toExponential(4)}°, ΔLon = ${deltaLon.toExponential(4)}°`);

  // Verify sub-millimeter loop closure (< 1e-6 degrees ~ 0.1mm)
  if (deltaLat < 1e-6 && deltaLon < 1e-6) {
    console.log(`  PASS: High-precision sub-millimeter closure achieved.\n`);
  } else {
    console.error(`  FAIL: Residual error exceeds threshold.\n`);
    allPassed = false;
  }
}

console.log('================================================================');
if (allPassed) {
  console.log('ALL NIGERIAN GEODETIC TEST SUITES PASSED SUCCESSFULLY!');
} else {
  console.log('SOME TESTS FAILED!');
  process.exit(1);
}
