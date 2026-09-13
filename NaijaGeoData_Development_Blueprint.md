# Blueprint: NaijaGeoData Manager (Mobile & Cloud Framework)
## Comprehensive Development Blueprint for Nigerian Land Surveyors

### 1. Executive Summary & Core Value Proposition
The **NaijaGeoData Manager** is a localized, offline-first mobile application and cloud repository designed explicitly for Nigerian Registered Surveyors (SURSCON members). It solves the historical fragmentation of coordinate logs, eliminates data loss from physical field books, simplifies boundary pillar tracing, and streamlines the official **lodgement process** with State Survey Directorates (e.g., Office of the State Surveyor-General - OSSG).

Unlike generic GIS software, this application natively interprets Nigerian Coordinate Systems (Minna Datum & WGS84 UTM Zones), integrates with external high-precision GNSS rovers, and functions as a secure digital registry for a surveyor's entire career portfolio.

---

### 2. High-Impact Feature Breakdown

#### Module A: The Digital Coordinate Register (Lodgement Prep)
*   **Structured Ledger:** Store points by Client, Job ID, State, and Local Government Area (LGA).
*   **Automatic Attribute Tagging:** Every logged point captures Coordinate Type (Beacon, Control, Traverse, Detail), Method (RTK Fixed, Static, Total Station, Handheld), Precision/DOP, and Timestamp.
*   **Validation Engine:** Enforces standard Nigerian pillar numbering formats (e.g., "PPA 2026/1024" or custom state-specific syntaxes) and blocks duplicate entries within the user's registry.

#### Module B: Dual-Datum Coordinate Converter
*   **Real-time Transformation:** Seamlessly converts inputs and captured points between **WGS84 (Geodetic decimal degrees)** and **Minna Datum (UTM Grid Metric projections for Zones 31N, 32N, and 33N)**.
*   **Custom Grid Shifts:** Supports custom 3-parameter Molodensky or 7-parameter Bursa-Wolf shift inputs ($\Delta X, \Delta Y, \Delta Z$) to account for local state town planning variances.

#### Module C: Smart Pillar Tracing & Stakeout Navigation
*   **Dynamic Guidance Screen:** A high-refresh-rate bullseye graphics interface showing distance-to-target, bearing, and delta offsets (e.g., "Move North: 0.15m, Move East: 0.04m").
*   **Audio-Visual Proximity Cues:** Beeps faster as the surveyor approaches the historical coordinate location, allowing hands-free navigation through heavy bush.
*   **Beacon History Logging:** Trace who originally planted a verified control monument or boundary beacon by pulling shared metadata from the secure cloud registry.

#### Module D: Field Notes, Audio, & Visual Geotagging
*   **Site Recon Logs:** Attach clear descriptions of terrain condition, monument structural integrity (e.g., intact, disturbed, destroyed), and witness marks.
*   **Media Binding:** Take site photos and 30-second voice memos that are permanently bound into the point database entry for easy recall by office CAD technicians.

---

### 3. Localization Strategy (Nigeria Field Realities)

#### Coordinate Reference Systems (CRS) Reference
*   **Zone 31N:** Core Western States (Lagos, Ogun, Oyo, Osun, Ondo, Ekiti, parts of Kwara).
*   **Zone 32N:** Central Corridor (Abuja FCT, Edo, Delta, Rivers, Kaduna, Kano, Enugu, Anambra, Kogi, Niger).
*   **Zone 33N:** Eastern Belt (Calabar/Cross River, Akwa Ibom, Taraba, Borno, Adamawa, Yobe).

#### Offline Architecture & Data Resilience
*   **Vector Tile Caching:** Native support for local storage of map tiles via `.mbtiles` format. Surveyors can pre-download full state basemaps while connected to office Wi-Fi.
*   **Local-First Database Synchronization:** Field operators execute edits, log coordinates, and sketch layout plans locally. The app automatically enqueues data packets for sync when a stable MTN, Airtel, or Glo data connection is recovered.

---

### 4. Technical Architecture & Database Schema

#### Mobile Tech Stack Choice
*   **Framework:** **Flutter** (Dart) or **React Native** (TypeScript) to leverage high-performance hardware-accelerated rendering for map graphics and low-level Bluetooth API access.
*   **Local Database:** **SQLite** via `ispc_sqlite` or `WatermelonDB` for rich relational queries, transactional integrity, and spatial indexing compatibility.
*   **Mapping UI:** Mapbox SDK or MapLibre Native for smooth offline vector rendering.

#### SQLite Relational Schema
```sql
-- Jobs Repository Table
CREATE TABLE jobs (
    id TEXT PRIMARY KEY,
    job_name TEXT NOT NULL,
    client_name TEXT,
    state TEXT NOT NULL,
    lga TEXT NOT NULL,
    utm_zone INTEGER CHECK(utm_zone IN (31, 32, 33)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Coordinates & Monuments Master Table
CREATE TABLE coordinates (
    id TEXT PRIMARY KEY,
    job_id TEXT NOT NULL,
    pillar_number TEXT NOT NULL UNIQUE,
    point_type TEXT CHECK(point_type IN ('BEACON', 'CONTROL', 'TRAVERSE', 'DETAIL')),
    wgs84_lat REAL,
    wgs84_lon REAL,
    minna_north REAL,
    minna_east REAL,
    ortho_height REAL,
    fix_quality TEXT CHECK(fix_quality IN ('RTK_FIX', 'RTK_FLOAT', 'SINGLE', 'MANUAL')),
    p_dop REAL,
    monument_status TEXT CHECK(monument_status IN ('INTACT', 'DISTURBED', 'DESTROYED', 'MISSING')),
    FOREIGN KEY(job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

-- Field Media Attaches
CREATE TABLE field_media (
    id TEXT PRIMARY KEY,
    coordinate_id TEXT NOT NULL,
    file_path TEXT NOT NULL,
    media_type TEXT CHECK(media_type IN ('IMAGE', 'AUDIO')),
    captured_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(coordinate_id) REFERENCES coordinates(id) ON DELETE CASCADE
);
```

---

### 5. Implementation Roadmap (16-Week Phase Strategy)

```
Weeks 01-04: Foundation & Offline Local Storage Engine Setup
Weeks 05-08: Coordinate Computations & Coordinate Transformation Core Testing
Weeks 09-12: Bluetooth GNSS / NTRIP Engine Implementation & Map Visualizations
Weeks 13-16: Cloud Sync Pipeline, Lodgement Export Formats, & Beta Deployment
```

*   **Phase 1: Foundation & Local Database (Weeks 1-4)**
    *   Build relational schema and design local encryption layers.
    *   Implement state/LGA boundary configurations.
*   **Phase 2: Math & Geodesy (Weeks 5-8)**
    *   Program the 3-parameter Molodensky equations directly into the native runtime.
    *   Conduct validation testing using historical survey records sourced from state registries.
*   **Phase 3: Hardware Integrations & Tracking UI (Weeks 9-12)**
    *   Develop the NMEA Bluetooth stream listener to capture external receiver strings.
    *   Build the responsive canvas compass UI for monument location recovery.
*   **Phase 4: Export Framework & Field Trials (Weeks 13-16)**
    *   Incorporate automated generation of standard CSV, text files, and layered DXF line scripts.
    *   Execute field trials in known low-connectivity sectors around suburban layouts.
