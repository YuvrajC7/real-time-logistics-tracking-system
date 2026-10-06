# RTLTS: Real-Time Logistics Tracking System

A full-stack, enterprise-grade logistics control tower built with Next.js 14, Supabase, and TypeScript.

## Features
- **Real-time Map Telemetry** via MapLibre and Supabase WebSockets.
- **Role-Based Access** (Admin, Dispatcher, Driver, Customer) with secure RLS.
- **3D Hero Section** via React Three Fiber.
- **Dark Mode Design System** using Tailwind CSS + custom tokens.
- **Complex DB Schema**: 20 tables, 7 views, PostgreSQL functions & triggers.

## Quick Start

1. Install dependencies:
```bash
npm install
```

2. Generate types (if schema changes):
```bash
npx supabase gen types typescript --project-id <your-project> > lib/supabase/types.ts
```

3. Run development server:
```bash
npm run dev
```

4. Run simulator (in another terminal):
```bash
npx tsx scripts/simulate.ts
```

## Demo Accounts
- **Admin**: admin@rtlts.in / Admin@123
- **Dispatcher**: dispatch@rtlts.in / Dispatch@123
- **Driver**: driver1@rtlts.in / Driver@123
- **Customer**: customer1@rtlts.in / Customer@123
