# 🛺 TriGo — Digital Tricycle Ride Booking Platform

Digital platform to streamline municipality-bounded tricycle ride booking for locals and tourists. Catering to tricycles and motorcabs with jurisdiction limits, role switching (Passenger ↔ Driver), real-time GPS fleet tracking, and a central administration portal.

---

## 🏗️ Monorepo Architecture

```
trigo/
├── apps/
│   ├── trigo/                    # Native Flutter Mobile App (Android / iOS for Passengers & Drivers)
│   ├── trigo-admin/              # Vue 3 + TypeScript + Tailwind CSS v4 Admin Web App
│   ├── trigo-landing/            # Vanilla HTML/CSS/JS public landing page (bundled with Vite)
│   └── trigo-backend/            # Node.js + Express + TypeScript REST API
├── docs/                         # Planner & Implementer skill guides
├── package.json                  # Root Monorepo configuration
├── .gitignore                    # Version control exclusions
└── README.md                     # Getting started instructions
```

---

## 📋 Prerequisites

Before running the project for the first time, ensure you have the following installed on your machine:

1. **[Node.js](https://nodejs.org/)** (v18.0.0 or higher) and `npm` (v9.0.0 or higher)
2. **[Flutter SDK](https://docs.flutter.dev/get-started/install)** (v3.19.0 or higher)
3. **[PostgreSQL](https://www.postgresql.org/)** (Required - v14+ or Docker container)
4. **[VS Code](https://code.visualstudio.com/)** (Recommended IDE) with **Flutter** and **Vue - Volar** extensions installed.

---

## 🗄️ Local Database Setup (PostgreSQL)

TriGo requires a running PostgreSQL database:

### 1. Start PostgreSQL Service

**Via Docker Container (Recommended)**:
```bash
docker run --name trigo-postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=trigo_db -p 5432:5432 -d postgres:16-alpine
```

**Via Local PostgreSQL Installation**:
- Create database `trigo_db` in your PostgreSQL instance:
  ```sql
  CREATE DATABASE trigo_db;
  ```

### 2. Configure Environment Variables
Ensure `apps/trigo-backend/.env` contains your PostgreSQL connection string:
```env
DATABASE_URL=postgres://postgres:postgres@localhost:5432/trigo_db
```

### 3. Run Schema Migrations
Execute table creation scripts:
```bash
npm run db:migrate
```

### 4. Seed Database
Populate database with initial municipality fare matrices, admin, driver, and passenger test accounts:
```bash
npm run db:seed
```

---

## ⚡ First-Time Setup & Quick Start

Follow these steps to run all 3 applications for the first time:

### Step 1: Install Monorepo Dependencies

Open a terminal at the root of the project directory (`trigo/`) and run:

```bash
npm install
```

### Step 2: Fetch Flutter Dependencies

Navigate to the Flutter app directory and fetch Dart packages:

```bash
cd apps/trigo
flutter pub get
cd ../..
```

---

## 🚀 Running the Applications

### Option A: Running via NPM Scripts (Terminal)

1. **Start Backend Service (Port 4000)**:
   ```bash
   npm run dev:backend
   ```
   *Health Check: Open [http://localhost:4000/health](http://localhost:4000/health)*

2. **Start Admin Web Portal (Port 3000)**:
   ```bash
   npm run dev:admin
   ```
   *Dashboard: Open [http://localhost:3000](http://localhost:3000) (Default login: `admin@trigo.ph` / `admin123`)*

3. **Start Public Landing Page (Port 3001)**:
   ```bash
   npm run dev:landing
   ```
   *Marketing page with live coverage statistics, a feature overview and the APK download buttons: open [http://localhost:3001](http://localhost:3001)*

4. **Start Flutter Mobile App (Device / Emulator)**:
   ```bash
   npm run dev:flutter
   ```

---

## 🧪 Testing & Code Quality Verification

### 1. Run Backend Unit Tests
```bash
npm run test:backend
```
*(Runs 75/75 Vitest unit tests covering Auth, Rides, Municipalities, Drivers, Tracking, Payments, Notifications, and Uploads.)*

### 2. Run Admin Web Production Build
```bash
npm run build:admin
```

### 3. Run Landing Page Production Build
```bash
npm run build:landing
```
*(Outputs a static site to `apps/trigo-landing/dist/` — deployable to any static host.)*

### 4. Run Flutter Static Analysis
```bash
cd apps/trigo
flutter analyze
```

### 5. Run Security Audit
```bash
npm audit
```

---

## 🌐 Landing Page

The public landing page lives in `apps/trigo-landing` (plain HTML/CSS/JS — no UI framework — bundled by Vite).

- **Live statistics** are read from the two public backend endpoints, `GET /health` and `GET /api/municipalities`, and fall back to the seeded municipal fare matrix (`apps/trigo-backend/src/shared/database/seed.ts`) whenever the backend is offline.
- **Download APK** buttons (header, hero, driver band and footer) all point at `VITE_APK_URL`. While that value is empty they render disabled with a short "how to publish" notice in the hero, so the site never ships a dead link.
- **Screenshots** are uploaded to the repo-root `screens/updated/` folder and referenced as `/screens/updated/<file>` (see `screens/updated/README.md` for the expected filenames). `apps/trigo-landing/vite.config.js` serves that folder in development and copies it into the build, so uploading a file is all that is needed; until then the page shows a placeholder inside each phone frame.

Configure it by copying `apps/trigo-landing/.env.example` to `.env`:

| Variable | Purpose |
|----------|---------|
| `VITE_API_BASE_URL` | Backend REST base; its origin is used for the `/health` probe |
| `VITE_APK_URL` | Public APK download URL (empty = not published) |
| `VITE_APK_SIZE` | Optional display-only size, e.g. `68 MB` |
| `VITE_APP_VERSION` | Version shown on the page |
| `VITE_APP_RELEASE_LABEL` | Optional release text (`demo`, `beta`, …) |

---

## 🏷️ Release Labels & Versioning

Both the mobile app and the landing page read the same release identity from environment variables:

| Variable | Applies to | Meaning |
|----------|-----------|---------|
| `APP_RELEASE_VERSION` / `VITE_APP_VERSION` | Mobile app / landing page | Version string, e.g. `1.0.0`. Keep in step with `apps/trigo/pubspec.yaml`. |
| `APP_RELEASE_LABEL` / `VITE_APP_RELEASE_LABEL` | Mobile app / landing page | Optional free text such as `demo`, `beta` or `rc`. |

Resolution rule (identical on both sides):

- label **absent or blank** ⇒ production ⇒ display `1.0.0`
- label **present** ⇒ pre-release ⇒ display `1.0.0-demo`

In the mobile app the value appears on the splash screen under the TriGo wordmark and in **Settings → About**, styled as a badge whenever a label is set. The landing page mirrors it next to the download button and in the footer.

---

## 🔑 Default Seed Test Accounts

| Role | Email | Password | Details |
|------|-------|----------|---------|
| **Admin** | `admin@trigo.ph` | `admin123` | Full access to Admin Web Portal |
| **Driver** | `driver@trigo.ph` | `driver123` | Approved driver with Kawasaki Barako (123-ABC) |
| **Passenger** | `customer@trigo.ph` | `customer123` | Registered customer account |
