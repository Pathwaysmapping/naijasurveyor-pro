# Development Blueprint: NaijaSurveyor Pro (MVP)
*Tailored for Nigerian Land Surveyors & Boundary Verification*

---

## 1. Core Objectives & Scope
The goal of **NaijaSurveyor Pro** is to solve the distinct field-to-office bottleneck for Nigerian surveyors. It provides local coordinate transformations, offline mapping, and bluetooth RTK connectivity on a standard mobile device.

### High-Impact Focus Areas
*   **Coordinate System Mastery:** Elimination of projection conversion errors between **Minna Datum (UTM Zones 31N, 32N, 33N)** and **WGS84**.
*   **Offline Operational Resilience:** 100% core capability without cellular network coverage.
*   **Standardized Local Outputs:** One-click generation of standard CSV/DXF file structures expected by NIS (Nigerian Institution of Surveyors) and state GIS offices.

---

## 2. Technical Stack Strategy (Cross-Platform Mobile)
To maximize market reach across field-crews using standard Android tablets or phones, while keeping iOS open for office supervisors:

*   **Frontend Framework:** **Flutter** (Dart) or **React Native** (TypeScript). Flutter is preferred for rendering heavy geometric vector features (DXF overlays) and fluid custom animations during stakeout.
*   **Local Database:** **SQLite** or **Hive** for fast, offline relational storage of client records, job metadata, and raw coordinate points.
*   **Bluetooth Communication:** `flutter_reactive_ble` or equivalent package to handle low-latency serial NMEA stream parsing from external GNSS hardware.
*   **Spatial Geometry Engine:** `turf_dart` or `Proj4` for running matrix coordinate transformations completely on the device client.

---

## 3. Core Database Schema & Entities

```
+------------------+         +------------------+         +------------------+
|     Clients      |         |       Jobs       |         |   SurveyPoints   |
+------------------+         +------------------+         +------------------+
| id (UUID) [PK]   |1      * | id (UUID) [PK]   |1      * | id (UUID) [PK]   |
| name (VARCHAR)   +-------->| client_id [FK]   +-------->| job_id [FK]      |
| phone (VARCHAR)  |         | job_num (VARCHAR)|         | pt_name (VARCHAR)|
| created_at       |         | zone (INT:31/32) |         | easting (DOUBLE) |
+------------------+         | datum (ENUM)     |         | northing (DOUBLE)|
                             | created_at       |         | height (DOUBLE)  |
                             +------------------+         | pt_type (ENUM)   |
                                                          | photo_path       |
                                                          +------------------+
```

### Data Dictionary Spec

#### 1. Clients
*   `id`: Unique identifier (Primary Key)
*   `name`: Full Client/Company Name
*   `phone`: Direct primary contact number
*   `created_at`: Datetime string of original entry

#### 2. Jobs
*   `id`: Unique identifier (Primary Key)
*   `client_id`: Links back to Clients Table (Foreign Key)
*   `job_num`: Assignment sequence (e.g., `SURV/2026/089`)
*   `zone`: Coordinate sector definition (`31`, `32`, or `33`)
*   `datum`: Structural anchor point (`MINNA_UTM` or `WGS84_GEOGRAPHIC`)
*   `created_at`: Verification lifecycle tracking timestamp

#### 3. SurveyPoints
*   `id`: Unique identifier (Primary Key)
*   `job_id`: Links back to specific Parent Project Structure (Foreign Key)
*   `pt_name`: Beacon index designation (e.g., `P1`, `P2`, `P3`, or `BM01`)
*   `easting`: Transverse Mercator horizontal axis grid mapping (X coordinate)
*   `northing`: Transverse Mercator vertical axis grid mapping (Y coordinate)
*   `height`: Ellipsoidal or orthometric elevation coordinate calculation (Z coordinate)
*   `pt_type`: Informative semantic context tag (`BEACON`, `TRAVERSE_STATION`, `OFFSET`, `NATURAL_FEATURE`)
*   `photo_path`: Local path reference linking captured field imagery directly to coordinate coordinates

---

## 4. Phase-by-Phase MVP Development Timeline

### Phase 1: Coordinate System Core & Data Collection (Weeks 1–4)
*   Implement localized **Proj4** transformation formulas directly into the runtime context.
*   Build UI modules for manual entry of coordinates (Easting/Northing in Minna UTM) and automatic visual validation.
*   Implement data storage layers (SQLite) for managing Client and Job schemas offline.

### Phase 2: NMEA Bluetooth & NTRIP Stream client (Weeks 5–8)
*   Develop Bluetooth Serial interface to discover and connect to external GNSS receivers (e.g., South, Emlid Reach, Trimble).
*   Build a lightweight background worker parsing NMEA `$GNGGA` and `$GNRMC` strings.
*   Integrate an NTRIP client module enabling users to type in Caster credentials (IP, Port, Mountpoint) to stream RTK corrections directly over mobile network sockets.

### Phase 3: Offline Mapping & Cadastral Stakeout UI (Weeks 9–12)
*   Implement a vector mapping layer using offline **MBTiles** or cached OpenStreetMap arrays.
*   Develop the **Stakeout Compass Dashboard**: a clear visual interface providing real-time instructions to find historical survey marks (e.g., *"Go South 2.14m, East 0.40m"*).
*   Add multi-media attachment hooks linking site photos directly with structural point coordinates.

### Phase 4: Local Exporters, Quality Assurance & Pilot Launch (Weeks 13–16)
*   Exporters for specialized **CSV format** matching office data workflows, alongside structured **DXF vectors** layout configurations.
*   Rigorous integration smoke testing under heavy coordinate transformations.
*   Deploy localized beta packages to pilot testers in **Lagos, Ibadan, and Abuja** for operational validation.

---

## 5. Localized Nigerian Edge-Cases
To ensure field validation, developers must account for the following environmental realities:

*   **The Minna Datum Shift:** The **Minna Datum (1965)** is based on the Clarke 1880 Ellipsoid and uses the **National Paragraph Parameters** for conversions to WGS84. However, local state variations exist (e.g., specific correction sets used within Lagos State GIS vs. Federal Surveys). Your transformation matrix must allow for custom regional 3-parameter ($\Delta X, \Delta Y, \Delta Z$) or 7-parameter coordinate shifts.
*   **The Three UTM Zones:** Nigeria is sliced cleanly into three UTM zones: **Zone 31N** (West: e.g., Lagos, Ibadan), **Zone 32N** (Central: e.g., Abuja, Kaduna, Port Harcourt), and **Zone 33N** (East: e.g., Maiduguri, Calabar). The application must auto-detect the default UTM Zone based on rough coarse device location or force manual verification when starting a new job container.
*   **Corrosive Battery Overhead:** Parsing real-time Bluetooth NMEA streams combined with high-accuracy GPS usage causes significant thermal and battery drag on mobile units. Mobile architectures must use low-power background polling structures when the screen state enters sleep cycles.
