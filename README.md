# 🛺 TriGo — Digital Tricycle Ride Booking Platform

Digital platform to streamline municipality-bounded tricycle ride booking for locals and tourists. Catering to tricycles and motorcabs with jurisdiction limits, role switching (Passenger ↔ Driver), real-time GPS fleet tracking, and a central administration portal.

---

## 🏗️ Monorepo Architecture

```
trigo/
├── apps/
│   ├── trigo/                    # Native Flutter Mobile App (Android / iOS for Passengers & Drivers)
│   ├── trigo-admin/              # Vue 3 + TypeScript + Tailwind CSS v4 Admin Web App
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

3. **Start Flutter Mobile App (Device / Emulator)**:
   ```bash
   npm run dev:flutter
   ```

---

## 🧪 Testing & Code Quality Verification

### 1. Run Backend Unit Tests
```bash
npm run test:backend
```
*(Runs 13/13 Vitest unit tests covering Auth, Rides, Municipalities, Drivers, Tracking, Payments, and Notifications).*

### 2. Run Admin Web Production Build
```bash
npm run build:admin
```

### 3. Run Flutter Static Analysis
```bash
cd apps/trigo
flutter analyze
```

### 4. Run Security Audit
```bash
npm audit
```

---

## 🔑 Default Seed Test Accounts

| Role | Email | Password | Details |
|------|-------|----------|---------|
| **Admin** | `admin@trigo.ph` | `admin123` | Full access to Admin Web Portal |
| **Driver** | `driver@trigo.ph` | `driver123` | Approved driver with Kawasaki Barako (123-ABC) |
| **Passenger** | `customer@trigo.ph` | `customer123` | Registered customer account |
