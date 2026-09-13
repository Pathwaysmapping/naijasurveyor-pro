# NaijaSurveyor Pro (MVP)
*High-Precision Geodetic & Cadastral Field Verification for Nigerian Land Surveyors*

Developed according to the **NaijaSurveyor Development Blueprint** for **Pathways Mapping & Geospatial Solutions**.

---

## 1. Overview & Architecture
**NaijaSurveyor Pro** eliminates the field-to-office bottleneck for Nigerian surveyors by providing:
1. **Coordinate System Mastery**: High-precision conversions between **Minna Datum (Clarke 1880)** and **WGS84** across all three Nigerian UTM sectors (**Zone 31N, Zone 32N, Zone 33N**).
2. **100% Offline Resilience**: Complete operational capability without internet or cellular connectivity using local relational SQLite storage.
3. **Standardized Local Outputs**: One-click generation of Nigerian Institution of Surveyors (NIS) standard CSV files and AutoCAD R12 DXF boundary vector files.

---

## 2. Directory Structure

```
PATHWAYS APP/
├── pubspec.yaml                     # Dependencies (sqflite, uuid, path_provider, etc.)
├── README.md                        # Project documentation & operational guidelines
├── NaijaSurveyor_Development_Blueprint.md  # Original system specification
├── lib/
│   ├── main.dart                    # App bootstrap & theme initialization
│   ├── core/
│   │   ├── constants/
│   │   │   └── geodetic_constants.dart # Clarke 1880, WGS84, National 3-parameter shifts
│   │   └── utils/
│   │       ├── coordinate_converter.dart # Bursa-Wolf & Transverse Mercator engine
│   │       └── zone_detector.dart        # Longitude-based UTM zone detection
│   ├── data/
│   │   ├── database/
│   │   │   └── app_database.dart       # SQLite schema, indices & cascade FKs
│   │   ├── models/
│   │   │   ├── client_model.dart       # Client record model
│   │   │   ├── job_model.dart          # Survey project container model
│   │   │   └── survey_point_model.dart # Beacons, coordinates & point types
│   │   └── repositories/
│   │       └── survey_repository.dart  # Offline CRUD & beacon numbering logic
│   ├── presentation/
│   │   ├── theme/
│   │   │   └── app_theme.dart          # Deep Midnight Navy & Signature Crimson
│   │   ├── screens/
│   │   │   ├── home_screen.dart        # Active jobs overview & tools
│   │   │   ├── new_job_screen.dart     # New job container creation & zone selection
│   │   │   ├── job_detail_screen.dart  # Beacon point list, stats & export
│   │   │   ├── add_point_screen.dart   # Manual beacon entry & real-time validator
│   │   │   └── coordinate_converter_screen.dart # Interactive field converter tool
│   │   └── widgets/
│   │       ├── point_card.dart         # Point card component
│   │       └── zone_badge.dart         # Zone indicator badge
│   └── services/
│       └── export_service.dart         # NIS CSV & AutoCAD DXF generator
└── scripts/
    └── verify_transformations.js       # Standalone mathematical verification suite
```

---

## 3. Nigerian Coordinate System Engine

### Geodetic Parameters
- **Ellipsoid: Clarke 1880 (RGS)**
  - Semi-major axis ($a$): `6,378,249.145 m`
  - Inverse flattening ($1/f$): `293.465`
  - $e^2$: `0.006803511283`
- **WGS84 Ellipsoid (GPS)**
  - Semi-major axis ($a$): `6,378,137.0 m`
  - Inverse flattening ($1/f$): `298.257223563`
- **National 3-Parameter Datum Shift (Minna $\rightarrow$ WGS84)**
  - $\Delta X = -92.0\text{ m} \pm 3\text{ m}$
  - $\Delta Y = -93.0\text{ m} \pm 6\text{ m}$
  - $\Delta Z = +122.0\text{ m} \pm 5\text{ m}$
  - *(Override capability supported for state-specific shifts, e.g. Lagos State GIS calibration).*

### UTM Zones in Nigeria
| Zone | Central Meridian | Longitude Coverage | Regional Coverage |
| :--- | :--- | :--- | :--- |
| **Zone 31N** | $3^\circ\text{ E}$ | $0^\circ\text{ E} - 6^\circ\text{ E}$ | Lagos, Ogun, Oyo, Osun, Ondo, Ekiti, Kwara (West) |
| **Zone 32N** | $9^\circ\text{ E}$ | $6^\circ\text{ E} - 12^\circ\text{ E}$ | Abuja FCT, Edo, Delta, Rivers, Kano, Kaduna, Niger, Plateau, Enugu, Imo |
| **Zone 33N** | $15^\circ\text{ E}$ | $12^\circ\text{ E} - 18^\circ\text{ E}$ | Borno, Adamawa, Taraba, Yobe, Calabar / Cross River (East) |

---

## 4. Running the Geodetic Verification Suite
To verify the coordinate transformation mathematics and loop closure accuracy across all three Nigerian zones:

```bash
node scripts/verify_transformations.js
```

### Benchmark Results
- **Lagos (Zone 31N)**: Forward Easting = `542012.491 m`, Northing = `721069.661 m`. Loop closure residual: $\Delta < 10^{-8\circ}$ (sub-millimeter).
- **Abuja FCT (Zone 32N)**: Forward Easting = `324075.870 m`, Northing = `1003578.147 m`. Loop closure residual: $\Delta < 10^{-8\circ}$ (sub-millimeter).
- **Maiduguri (Zone 33N)**: Forward Easting = `298521.104 m`, Northing = `1308667.425 m`. Loop closure residual: $\Delta < 10^{-8\circ}$ (sub-millimeter).

---

## 5. Offline SQLite Database Schema

```sql
CREATE TABLE clients (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE jobs (
    id TEXT PRIMARY KEY,
    client_id TEXT NOT NULL,
    job_num TEXT NOT NULL UNIQUE,
    zone INTEGER NOT NULL CHECK(zone IN (31, 32, 33)),
    datum TEXT NOT NULL CHECK(datum IN ('MINNA_UTM', 'WGS84_GEOGRAPHIC')),
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
);

CREATE TABLE survey_points (
    id TEXT PRIMARY KEY,
    job_id TEXT NOT NULL,
    pt_name TEXT NOT NULL,
    easting REAL NOT NULL,
    northing REAL NOT NULL,
    height REAL NOT NULL,
    pt_type TEXT NOT NULL CHECK(pt_type IN ('BEACON', 'TRAVERSE_STATION', 'OFFSET', 'NATURAL_FEATURE')),
    photo_path TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE
);
```

---

## 6. Export Standards

### Nigerian Institution of Surveyors (NIS) CSV Output
```csv
# NAIJASURVEYOR PRO - CADASTRAL POINT EXPORT
# Job Number: SURV/2026/089
# Coordinate Reference System: MINNA_UTM (UTM Zone 32N)
# Total Points: 4
# Generated: 2026-09-13T11:25:00Z
POINT_ID,EASTING,NORTHING,HEIGHT,TYPE,TIMESTAMP
P1,324075.870,1003578.147,485.120,BEACON,2026-09-13T11:25:10Z
P2,324120.340,1003602.890,485.450,BEACON,2026-09-13T11:25:35Z
```

### AutoCAD R12 ASCII DXF
Includes structured layers:
- `BEACONS`: High-precision point coordinate nodes.
- `BEACON_LABELS`: Text entities with 1.2m drawing scale height offset 0.75m from the beacon center.
- `BOUNDARY_LINES`: Closed polygon lines connecting beacons for perimeter verification in AutoCAD and Civil 3D.

---

## 7. Phase 2: NMEA Bluetooth & NTRIP Stream Client

### High-Precision GNSS Hardware & RTK Protocol Support
- **NMEA-0183 Engine**: High-throughput `$GNGGA`, `$GNRMC`, `$GNGST` sentence parser with XOR checksum integrity validation.
- **RTK Fix Quality Indicators**:
  - `4`: **RTK FIXED** (Centimeter/millimeter survey grade)
  - `5`: **RTK FLOAT** (Decimeter ambiguity unresolved)
  - `1`: **SINGLE / 3D AUTONOMOUS** (Standard GPS)
- **NTRIP 1.0/2.0 Client**:
  - Direct TCP/IP socket connection to CORS Casters (e.g., OSGOF CORS, Lagos State GIS CORS, or private base stations).
  - Handles HTTP GET handshake and Basic Authentication.
  - Receives and pipelines RTCM 3.x differential correction packets to external GNSS rover receivers over Bluetooth Serial.
  - Sends automatic NMEA GGA feedback to Casters for VRS (Virtual Reference Station) positioning.
- **Built-in GNSS Simulator**:
  - Enables full in-office software verification and field rehearsal without physical GNSS hardware.
  - Simulates a rover walking an active survey perimeter in Abuja or Lagos with RTK Fixed status.

### Running Phase 2 Verification Suite
```bash
node scripts/verify_phase2_nmea_ntrip.js
```

---

## 8. Phase 3: Offline Mapping & Cadastral Stakeout UI

### Pillar Tracing & Bullseye Compass Navigation
- **Stakeout Geometry Engine**:
  - Real-time computation of 2D distance to target ($\sqrt{\Delta E^2 + \Delta N^2}$).
  - 4-quadrant Azimuth/Grid bearing calculation ($0^\circ - 360^\circ$ clockwise from North).
  - Clear field guidance instructions: `"GO NORTH 4.00m | GO EAST 3.00m"`.
  - Elevation Cut/Fill monitoring ($\Delta Z$).
  - **$2\text{ cm}$ Survey Stakeout Tolerance Lock**: When the rover gets within $2\text{ cm}$ of the target pillar, the bullseye locks with a vibrant emerald confirmation ring.
- **Audio-Visual Proximity Feedback**:
  - Dynamic proximity pulse frequency scaling ($100\text{ ms}$ on-target pulse to $1500\text{ ms}$ approach tone) for hands-free navigation through heavy bush.
- **Vector Cadastral Map Canvas**:
  - Offline vector renderer drawing survey beacons and closed boundary polygons scaled to screen dimensions.
  - Live cursor tracking showing the rover’s exact location relative to property parcel lines.
- **Verification Point Logging**:
  - Instant logging of verified recovered monuments with residual distance recording.

### Running Phase 3 Verification Suite
```bash
node scripts/verify_phase3_stakeout.js
```


