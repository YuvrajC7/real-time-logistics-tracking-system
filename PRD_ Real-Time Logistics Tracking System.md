# Product Requirements Document

## Real-Time Logistics Tracking System (RTLTS)

**Course:** Database Management Systems (DBMS) Project · **Stack:** Supabase (PostgreSQL + Auth + Realtime + Storage) · Next.js · TypeScript **Version:** 1.0 · **Status:** Ready for build

---

## 1. Executive Summary

RTLTS is a web platform that lets a logistics company create shipments, assign them to drivers and vehicles, and track them **live on a map** from warehouse to doorstep. Customers see their parcel moving in real time, drivers update status from a mobile-friendly console, dispatchers manage fleets and routes, and admins oversee everything.

**The database is the star of this project.** The grading focus is a rigorous relational design (ER/EER → relational model → 3NF → DDL/DML), enforced in PostgreSQL with constraints, triggers, views, functions and Row Level Security, then exposed through a polished, modern frontend.

### 1.1 Goals

1. A fully normalized (3NF) PostgreSQL schema on Supabase with real business logic inside the database.
2. Role-based authentication and authorization (Admin, Dispatcher, Driver, Customer) enforced by RLS.
3. Real-time tracking: vehicle location and shipment status updates stream live to the UI.
4. A premium, non-generic frontend with a 3D hero, smooth scroll animation and a live map dashboard.
5. Complete documentation mapped one-to-one to the teacher's 11 stages.

### 1.2 Non-Goals

- No payment gateway, no real GPS hardware (location is simulated by a script and by the driver's browser geolocation).
- No native mobile apps (responsive web only).
- No ML route optimization (rule-based assignment only).

---

## 2. Stage 1 — Problem Identification & Requirement Analysis

### 2.1 Problem Statement

Small and mid-size logistics operators track parcels with spreadsheets, calls and scattered messages. Customers can't see where a parcel is, dispatchers can't see fleet state, and delays are noticed only after complaints. Data is duplicated, inconsistent and unauditable.

### 2.2 Users and Personas

| Persona | Needs | Key Actions |
| --- | --- | --- |
| **Admin** | Full oversight, analytics, user management | Manage users, branches, vehicles; view all reports |
| **Dispatcher** | Operate daily deliveries | Create shipments, assign driver and vehicle, plan routes, monitor live map, resolve exceptions |
| **Driver** | Simple task list, quick status updates | View assigned shipments, start trip, update status, upload proof of delivery, share location |
| **Customer** | Visibility and trust | Place/track shipment by tracking ID, see live ETA and timeline, view history |

### 2.3 Functional Requirements

**Authentication and Accounts**

- FR-1: Email/password signup and login via Supabase Auth; email verification; password reset.
- FR-2: Optional Google OAuth for customers.
- FR-3: Role stored in `profiles.role`; every protected route and table enforces it.
- FR-4: Admin can create Dispatcher and Driver accounts; customers self-register.

**Shipment Management**

- FR-5: Create shipment with sender, receiver, origin/destination address, package details (weight, dimensions, category, fragile flag), service type.
- FR-6: Auto-generated unique tracking ID (e.g., `RTL-2026-000123`).
- FR-7: Automatic charge calculation from weight, distance and service type.
- FR-8: Shipment lifecycle: `CREATED → PICKED_UP → IN_TRANSIT → AT_HUB → OUT_FOR_DELIVERY → DELIVERED`, with `FAILED_ATTEMPT`, `RETURNED`, `CANCELLED` exceptions. Invalid transitions are rejected by the database.
- FR-9: Every status change is appended to an immutable event timeline.

**Fleet and Driver Management**

- FR-10: CRUD for vehicles (type, plate, capacity, status) and drivers (license, availability).
- FR-11: Assignment rules: a vehicle cannot exceed capacity; a driver/vehicle cannot be double-booked; expired licenses block assignment.

**Real-Time Tracking**

- FR-12: Drivers push location pings (lat, lng, speed, heading) at a fixed interval.
- FR-13: Dispatcher dashboard shows all active vehicles on a live map.
- FR-14: Customer tracking page shows live marker, route line, ETA and timeline, updating without refresh.

**Hubs and Routing**

- FR-15: Hubs/warehouses with location and capacity; shipments move through hubs.
- FR-16: Routes consist of ordered stops; trips group shipments on a route for a driver/vehicle.

**Delivery and Exceptions**

- FR-17: Proof of delivery (photo + recipient name + OTP) stored in Supabase Storage.
- FR-18: Failed delivery with reason code; rescheduling.
- FR-19: In-app notifications on every status change.

**Reporting**

- FR-20: Dashboards: on-time rate, shipments by status, driver performance, hub throughput, revenue by period.
- FR-21: CSV export of shipment reports.

### 2.4 Non-Functional Requirements

| Area | Requirement |
| --- | --- |
| Performance | Page loads under 2 s on broadband; realtime update latency under 1 s; indexed queries under 100 ms at 10k shipments |
| Security | RLS on every table, no service key in the browser, input validation on client and server, HTTPS only |
| Integrity | All business rules enforced in DB (constraints and triggers), not only in UI |
| Usability | Fully responsive; WCAG AA contrast; keyboard accessible |
| Reliability | Transactions for multi-step operations; idempotent location ingestion |
| Maintainability | Versioned SQL migrations, typed client, consistent naming |

### 2.5 Business Rules (feed into ER design)

1. A customer can place many shipments; a shipment has exactly one sender customer.
2. A shipment has exactly one origin and one destination address.
3. A shipment is delivered by at most one trip at a time but may pass through many trips over its life (hub-to-hub legs).
4. A trip uses exactly one driver and one vehicle.
5. A vehicle's total assigned weight cannot exceed its capacity.
6. A driver holds one valid license; an expired license blocks trip assignment.
7. Every status change creates one tracking event row; events are never updated or deleted.
8. A delivered shipment cannot change status again.

---

## 3. Stage 2 — ER / EER Diagram

### 3.1 Entities and Attributes

| Entity | Key Attributes |
| --- | --- |
| **PROFILE** (supertype) | profile_id (PK, = auth.users.id), full_name, email, phone, role, created_at |
| **CUSTOMER** (subtype) | customer_id (PK/FK), company_name, customer_type |
| **DRIVER** (subtype) | driver_id (PK/FK), license_no, license_expiry, availability, rating |
| **EMPLOYEE** (subtype, dispatcher/admin) | employee_id (PK/FK), hub_id, designation |
| **ADDRESS** | address_id, line1, line2, city, state, postal_code, country, lat, lng |
| **HUB** | hub_id, name, address_id, capacity, status |
| **VEHICLE** | vehicle_id, plate_no, type, capacity_kg, status, home_hub_id |
| **SHIPMENT** | shipment_id, tracking_no, sender_id, receiver_name/phone, origin_addr, dest_addr, service_type, status, charge, created_at, eta |
| **PACKAGE** | package_id, shipment_id, description, weight_kg, length/width/height, category, is_fragile |
| **TRIP** | trip_id, driver_id, vehicle_id, route_id, from_hub, to_hub, status, planned_start, actual_start, actual_end |
| **TRIP_SHIPMENT** (associative M:N) | trip_id, shipment_id, sequence_no, loaded_at, delivered_at |
| **ROUTE** | route_id, name, origin_hub, destination_hub, distance_km |
| **ROUTE_STOP** (weak) | route_id, stop_no (partial key), hub_id, expected_minutes |
| **TRACKING_EVENT** (weak-like log) | event_id, shipment_id, status, hub_id, note, created_by, created_at |
| **LOCATION_PING** | ping_id, vehicle_id, trip_id, lat, lng, speed_kmph, heading, recorded_at |
| **DELIVERY_PROOF** | proof_id, shipment_id, photo_url, recipient_name, otp_verified, signed_at |
| **NOTIFICATION** | notification_id, profile_id, shipment_id, message, is_read, created_at |
| **PAYMENT_INVOICE** | invoice_id, shipment_id, amount, tax, status, issued_at |

### 3.2 Relationships and Cardinalities

- PROFILE **1 : 1** CUSTOMER / DRIVER / EMPLOYEE (disjoint specialization, total on role)
- CUSTOMER **1 : N** SHIPMENT (sends)
- SHIPMENT **1 : N** PACKAGE (contains)
- SHIPMENT **N : 1** ADDRESS (origin) and **N : 1** ADDRESS (destination)
- TRIP **M : N** SHIPMENT via TRIP_SHIPMENT
- DRIVER **1 : N** TRIP; VEHICLE **1 : N** TRIP; ROUTE **1 : N** TRIP
- ROUTE **1 : N** ROUTE_STOP (identifying relationship, weak entity); HUB **1 : N** ROUTE_STOP
- SHIPMENT **1 : N** TRACKING_EVENT; SHIPMENT **1 : 1** DELIVERY_PROOF; SHIPMENT **1 : 1** PAYMENT_INVOICE
- VEHICLE **1 : N** LOCATION_PING; HUB **1 : N** VEHICLE (home); HUB **1 : N** EMPLOYEE
- PROFILE **1 : N** NOTIFICATION

### 3.3 EER Features to Show Explicitly

1. **Specialization/Generalization:** PROFILE → CUSTOMER, DRIVER, EMPLOYEE (disjoint, total).
2. **Weak entity:** ROUTE_STOP depends on ROUTE.
3. **Associative entity:** TRIP_SHIPMENT carries attributes (sequence, timestamps).
4. **Derived attributes:** shipment `charge`, `eta`, package volume.
5. **Multivalued handled:** a shipment's many packages and many events become separate entities.

**Deliverable:** ER diagram in Chen or crow's-foot notation drawn in draw.io / dbdiagram.io, exported as PNG and PDF.

---

## 4. Stage 3 — ER → Relational Model

Mapping rules applied:

1. Strong entity → table with PK.
2. 1:N → FK on the N side.
3. M:N → junction table (`trip_shipments`).
4. Weak entity → table with composite PK (`route_id`, `stop_no`).
5. Specialization → table-per-subtype with PK = FK to supertype (`profiles`).
6. Multivalued/repeating data → separate table.

### Relational Schema (PK underlined as `*`, FK marked `→`)

```
profiles(profile_id*, full_name, email, phone, role, created_at)
customers(customer_id* → profiles, company_name, customer_type)
drivers(driver_id* → profiles, license_no, license_expiry, availability, rating)
employees(employee_id* → profiles, hub_id → hubs, designation)
addresses(address_id*, line1, line2, city, state, postal_code, country, lat, lng)
hubs(hub_id*, name, address_id → addresses, capacity, status)
vehicles(vehicle_id*, plate_no, type, capacity_kg, status, home_hub_id → hubs)
routes(route_id*, name, origin_hub → hubs, destination_hub → hubs, distance_km)
route_stops(route_id* → routes, stop_no*, hub_id → hubs, expected_minutes)
shipments(shipment_id*, tracking_no, sender_id → customers, receiver_name, receiver_phone,
          origin_addr → addresses, dest_addr → addresses, service_type, status, charge, eta, created_at)
packages(package_id*, shipment_id → shipments, description, weight_kg, length_cm, width_cm, height_cm, category, is_fragile)
trips(trip_id*, driver_id → drivers, vehicle_id → vehicles, route_id → routes, status,
      planned_start, actual_start, actual_end)
trip_shipments(trip_id* → trips, shipment_id* → shipments, sequence_no, loaded_at, delivered_at)
tracking_events(event_id*, shipment_id → shipments, status, hub_id → hubs, note, created_by → profiles, created_at)
location_pings(ping_id*, vehicle_id → vehicles, trip_id → trips, lat, lng, speed_kmph, heading, recorded_at)
delivery_proofs(proof_id*, shipment_id → shipments UNIQUE, photo_url, recipient_name, otp_verified, signed_at)
invoices(invoice_id*, shipment_id → shipments UNIQUE, amount, tax, status, issued_at)
notifications(notification_id*, profile_id → profiles, shipment_id → shipments, message, is_read, created_at)
```

---

## 5. Stage 4 — Normalization (1NF → 2NF → 3NF)

Document a **worked example** showing the unnormalized table and each step.

**Unnormalized sheet (UNF):** `Shipment(tracking_no, sender_name, sender_phone, sender_address, receiver_name, receiver_address, packages{desc, weight}, driver_name, driver_license, vehicle_plate, vehicle_capacity, status_history{status, time}, hub_name, hub_city)`

| Step | Problem Found | Fix |
| --- | --- | --- |
| **1NF** | Repeating groups `packages{}` and `status_history{}`; composite address strings | Split into `packages` and `tracking_events` tables; atomic address columns in `addresses` |
| **2NF** | In `trip_shipments(trip_id, shipment_id, driver_name, sequence_no)`, `driver_name` depends only on `trip_id` (partial dependency) | Move driver data to `trips → drivers`; keep only attributes depending on the full composite key |
| **3NF** | Transitive dependencies: `shipment_id → vehicle_plate → vehicle_capacity`; `hub_id → hub_city`; `driver_id → license_expiry` | Extract `vehicles`, `hubs`, `addresses`, `drivers` as their own relations |

**Functional dependency list** (provide for each table), for example:

- `shipments: shipment_id → all columns`, `tracking_no → shipment_id` (candidate key)
- `vehicles: vehicle_id → plate_no, type, capacity_kg`; `plate_no → vehicle_id`
- `route_stops: (route_id, stop_no) → hub_id, expected_minutes`

**Result:** every table in 3NF (most in BCNF). Note any *deliberate denormalization* (e.g., `shipments.charge`, `shipments.status` cached from latest event) with justification: read performance, kept consistent by triggers.

---

## 6. Stage 5 — Database Design and DDL

### 6.1 Conventions

- `snake_case`, plural table names, `uuid` primary keys (`gen_random_uuid()`), `timestamptz` everywhere, `created_at`/`updated_at` on mutable tables.
- All migrations in `/supabase/migrations/` numbered and re-runnable.

### 6.2 Enumerated Types

```sql
create type user_role as enum ('admin','dispatcher','driver','customer');
create type shipment_status as enum ('CREATED','PICKED_UP','IN_TRANSIT','AT_HUB','OUT_FOR_DELIVERY','DELIVERED','FAILED_ATTEMPT','RETURNED','CANCELLED');
create type service_type as enum ('STANDARD','EXPRESS','SAME_DAY');
create type vehicle_status as enum ('AVAILABLE','ON_TRIP','MAINTENANCE','RETIRED');
create type trip_status as enum ('PLANNED','ONGOING','COMPLETED','CANCELLED');
```

### 6.2 Constraint Catalogue (must appear in DDL)

| Type | Examples |
| --- | --- |
| PRIMARY KEY | every table |
| FOREIGN KEY | with `ON DELETE RESTRICT` for operational data, `CASCADE` for packages and route stops |
| UNIQUE | `tracking_no`, `plate_no`, `license_no`, `profiles.email`, one proof/invoice per shipment |
| NOT NULL | all mandatory attributes |
| CHECK | `weight_kg > 0`, `capacity_kg > 0`, `lat between -90 and 90`, `lng between -180 and 180`, `license_expiry > current_date` at assignment, `rating between 0 and 5` |
| DEFAULT | `status='CREATED'`, `created_at=now()`, `is_read=false` |

### 6.3 Indexes

- `shipments(tracking_no)`, `shipments(sender_id, created_at desc)`, `shipments(status)`
- `tracking_events(shipment_id, created_at)`
- `location_pings(vehicle_id, recorded_at desc)` and a BRIN index on `recorded_at`
- `trips(driver_id, status)`, `notifications(profile_id, is_read)`

### 6.4 Database Objects (Business Logic Layer)

| Object | Purpose |
| --- | --- |
| **Trigger** `handle_new_user` | On `auth.users` insert, create `profiles` row with default role `customer` |
| **Trigger** `generate_tracking_no` | Build `RTL-YYYY-NNNNNN` from a sequence |
| **Trigger** `enforce_status_transition` | Validate allowed transitions via a lookup table `status_transitions(from, to)`; block edits after DELIVERED |
| **Trigger** `log_tracking_event` | After status change, insert `tracking_events` row and `notifications` row |
| **Trigger** `check_vehicle_capacity` | Sum package weights on a trip vs vehicle capacity |
| **Trigger** `check_driver_eligibility` | Reject expired license or overlapping ongoing trip |
| **Trigger** `set_updated_at` | Generic timestamp maintenance |
| **Function** `calculate_charge(weight, distance_km, service)` | Pricing formula, used on insert |
| **Function** `estimate_eta(shipment_id)` | Based on remaining route stops and average speed |
| **Function** `haversine_km(lat1,lng1,lat2,lng2)` | Distance helper |
| **Stored procedure / RPC** `assign_shipment_to_trip(shipment_id, trip_id)` | Transactional assignment with all checks |
| **RPC** `update_shipment_status(shipment_id, new_status, hub_id, note)` | Single entry point for status changes |
| **RPC** `record_location(vehicle_id, lat, lng, speed, heading)` | Insert ping and update ETA |
| **Views** | `v_active_shipments`, `v_driver_performance`, `v_hub_throughput`, `v_latest_vehicle_location`, `v_shipment_timeline` |
| **Materialized view** | `mv_daily_kpis` refreshed on schedule (`pg_cron`) |

### 6.5 Row Level Security Matrix

| Table | Admin | Dispatcher | Driver | Customer |
| --- | --- | --- | --- | --- |
| profiles | all | read all | own | own |
| shipments | all | all | assigned only | own only |
| tracking_events | all | all | assigned (insert) | own shipments (read) |
| location_pings | all | all | own vehicle (insert) | only for their active shipment's vehicle |
| vehicles, drivers, hubs, routes | CRUD | read/update | read | none |
| trips | all | CRUD | own | none |
| notifications | all | own | own | own |

Role checks use a `security definer` helper `auth_role()` that reads `profiles.role` to avoid recursive policies. **No table is left without RLS.**

---

## 7. Stage 6 — Data Population (DML)

### 7.1 Seed Volume

| Table | Rows |
| --- | --- |
| profiles | 40+ (1 admin, 3 dispatchers, 10 drivers, 26 customers) |
| addresses | 60 |
| hubs | 8 (across Indian cities, e.g., Chennai, Bengaluru, Hyderabad, Mumbai, Delhi, Kolkata, Pune, Coimbatore) |
| vehicles | 15 |
| routes / route_stops | 10 / 35 |
| shipments / packages | 120 / 180 |
| trips / trip_shipments | 25 / 120 |
| tracking_events | 500+ (consistent with each shipment's lifecycle) |
| location_pings | 2000+ along real route geometry |
| notifications, invoices, proofs | proportional |

### 7.2 Rules

- Seed script in `seed.sql` plus a TypeScript/Node generator for realistic pings.
- Data must satisfy all constraints and tell a believable story (delivered, in transit, delayed, failed, cancelled in all proportions).
- Include a **live simulator** (`npm run simulate`) that moves vehicles along routes and updates statuses every few seconds, for the demo.
- Demo accounts for each role documented in the README.
- Also show manual `INSERT`, `UPDATE`, `DELETE` samples in documentation.

---

## 8. Stage 7 — Front-End Design

### 8.1 Design Direction

**Concept:** "Control tower" aesthetic. Calm, precise, premium logistics brand. Feels like a real SaaS product (think Linear / Stripe / Vercel / Flexport), not a template.

**Avoiding the "AI look"** — explicit rules:

- No purple-to-blue gradient blobs, no generic glassmorphism cards, no emoji icons, no stock "Welcome to the future" copy.
- One strong palette: deep navy/ink background (`#0B1020`), warm off-white (`#F4F1EA`), a single signal accent (electric amber `#FFB020`) and a secondary teal (`#2DD4BF`) used only for "live/active" states.
- Typography: a distinctive display face (e.g., **Space Grotesk** or **Sora**) paired with **Inter** for UI and **JetBrains Mono** for tracking IDs and coordinates.
- Copy written like a real company: specific, short, operational ("12 vehicles live · 3 delayed").
- Real data in every screenshot; no lorem ipsum.
- Consistent 8-pt spacing grid, subtle borders instead of heavy shadows, deliberate asymmetry in layouts.

### 8.2 3D and Motion System

| Where | Effect | Library |
| --- | --- | --- |
| Landing hero | Interactive 3D globe with glowing shipment arcs between hubs, slow rotation, mouse parallax | **three.js** via React Three Fiber, or `three-globe` |
| Landing scroll | Scroll-linked storytelling: parcel travels through a 3D route as the user scrolls (Create → Pickup → Hub → Delivery) | **GSAP ScrollTrigger** + Lenis smooth scroll |
| Sections | Staggered reveal, number counters, magnetic buttons | GSAP / Framer Motion |
| Tracking page | Animated route polyline, pulsing vehicle marker, smooth marker interpolation between pings | MapLibre GL / Mapbox GL |
| Dashboard | Count-up KPIs, animated charts, skeleton loaders | Framer Motion, Recharts / visx |
| Reference inspirations | Study award-style sites on Awwwards, Codrops, and Three.js Journey demos for composition and pacing; rebuild original work, do not copy templates or assets | — |

Performance guardrails: lazy-load 3D, cap DPR at 2, fallback static image on low-end devices, honor `prefers-reduced-motion`.

### 8.3 Site Map and Screens

**Public**

1. **Landing** — 3D hero, live-stats strip, how-it-works scroll story, feature grid, network map, testimonials-style case numbers, CTA, footer.
2. **Track Shipment** — big tracking-ID input, result page with live map, timeline, ETA, package details.
3. **Login / Signup / Reset** — split layout with animated visual; role-aware redirect.

**Customer portal** 4. Dashboard (active shipments, recent history) 5. New Shipment wizard (3 steps: addresses → package → service and price quote) 6. My Shipments (filter, search, status chips) 7. Shipment Detail (live tracking, timeline, invoice, proof of delivery) 8. Notifications and Profile

**Dispatcher console** 9. Live Operations Map (all vehicles, status-colored, cluster, click for detail drawer) 10. Shipments Board (table + kanban by status, bulk assign) 11. Trip Planner (drag shipments onto a trip, capacity bar live) 12. Fleet and Drivers (CRUD, availability, license expiry alerts) 13. Hubs and Routes management

**Driver app (mobile-first)** 14. Today's Trips and stop list 15. Trip Run view (navigate, mark picked up/delivered, failed attempt with reason) 16. Proof of Delivery capture (photo, OTP, name) 17. Auto location sharing toggle

**Admin** 18. Analytics dashboard (KPIs, charts) 19. User Management and role assignment 20. Audit log viewer (tracking_events) 21. Reports and CSV export

### 8.4 Component Library

Build with **Tailwind CSS + shadcn/ui** as the base, heavily customized with the design tokens above. Core components: AppShell, Sidebar, DataTable (sort/filter/paginate), StatusBadge, Timeline, MapView, StatCard, Wizard, Drawer, CommandPalette (⌘K), Toasts, EmptyStates, Skeletons.

### 8.5 UX Requirements

- Dark and light themes.
- Fully responsive (breakpoints 360 / 768 / 1280 / 1536).
- Form validation with Zod and inline errors; optimistic UI where safe.
- Empty, loading and error state designed for every screen.
- Accessibility: focus rings, ARIA labels, contrast AA, keyboard navigation.

---

## 9. Stage 8 — Business Logic Implementation

Where each rule lives (defense in depth):

| Rule | DB (source of truth) | App layer |
| --- | --- | --- |
| Status transitions | trigger + `status_transitions` table | UI shows only valid next actions |
| Capacity limit | trigger + RPC | live capacity bar in Trip Planner |
| Driver eligibility | trigger | filter dropdown |
| Charge calculation | `calculate_charge()` | quote preview calls RPC |
| ETA | `estimate_eta()` updated on each ping | countdown UI |
| Notifications | trigger inserts row | Realtime subscription toasts |
| Tracking ID | trigger + sequence | copy-to-clipboard |
| Immutable events | RLS (no update/delete) | read-only timeline |

**Pricing formula (example):** `charge = base(service) + rate_per_kg × weight + rate_per_km × distance`, plus 18% GST stored in the invoice. Constants kept in a `pricing_rules` table so they are editable without code changes.

**Transaction example:** `assign_shipment_to_trip` runs in one transaction: lock vehicle row → verify capacity → verify driver → insert `trip_shipments` → update shipment status to `PICKED_UP`/`IN_TRANSIT` → write event and notification → commit or roll back everything.

---

## 10. Stage 9 — Database Connectivity & Architecture

### 10.1 Architecture

```
Browser (Next.js App Router, TypeScript)
   │  supabase-js (anon key + user JWT)         ┌───────────────────────────┐
   ├──────────────────────────────────────────▶ │ Supabase                  │
   │  Realtime (WebSocket)                      │  • Auth (JWT)             │
   ◀──────────────────────────────────────────  │  • PostgREST / RPC        │
   │                                            │  • Postgres + RLS         │
Server (Next.js route handlers / Edge Functions)│  • Realtime               │
   │  service role key (server only) ─────────▶ │  • Storage (proof photos) │
                                                └───────────────────────────┘
Simulator script (Node) ──▶ record_location() RPC
```

### 10.2 Tech Stack

| Layer | Choice |
| --- | --- |
| Frontend | Next.js 14+ (App Router), TypeScript, Tailwind, shadcn/ui |
| 3D/Motion | three.js + R3F, GSAP, Lenis, Framer Motion |
| Maps | MapLibre GL JS with free OSM tiles (no paid key) |
| Backend | Supabase (Postgres, Auth, Realtime, Storage), Edge Functions for webhooks/cron tasks |
| Data access | `@supabase/supabase-js`, `@supabase/ssr` for cookie sessions; generated types via `supabase gen types` |
| Validation | Zod |
| Charts | Recharts |
| Deployment | Vercel (frontend) + Supabase cloud |

### 10.3 Authentication Flow

1. Signup → Supabase Auth → `handle_new_user` trigger creates profile (role `customer`).
2. Login → session cookie via `@supabase/ssr`; middleware reads role and redirects to the right portal.
3. Route protection in Next.js middleware **and** RLS in the database.
4. Staff accounts created by Admin through a server-only route using the service role.

### 10.4 Realtime Channels

- `vehicle:{id}` subscribes to `location_pings` inserts
- `shipment:{tracking_no}` subscribes to `tracking_events` inserts
- `notifications:{profile_id}` for toasts Client smooths marker motion by interpolating between pings.

### 10.5 Security Checklist

- Service role key only on the server; `.env` never committed.
- RLS enabled and tested per role; no `using (true)` policies except public tracking RPC.
- Public tracking exposed through a `security definer` RPC `public_track(tracking_no)` returning only non-sensitive fields.
- Input validation client and server; parameterized queries only; rate-limit the public tracking endpoint.
- Storage bucket policies: drivers upload, customers read their own proofs.

### 10.6 Folder Structure

```
/app            (routes: (public), (customer), (dispatcher), (driver), (admin))
/components     (ui, map, charts, 3d, layout)
/lib            (supabase clients, hooks, utils, zod schemas)
/supabase
   /migrations  (01_types.sql … 10_rls.sql)
   seed.sql
/scripts        (simulate.ts)
/docs           (ER diagram, normalization, test report, screenshots)
```

---

## 11. Stage 10 — Testing and Validation

### 11.1 Test Types

| Level | What | Tool |
| --- | --- | --- |
| Schema | Constraints reject bad data (negative weight, bad lat/lng, duplicate plate) | SQL scripts / pgTAP |
| Triggers/functions | Transition rules, capacity, eligibility, charge, ETA | pgTAP / SQL asserts |
| RLS | Each role can only see and do what the matrix allows | Test as each role with real JWTs |
| API/RPC | Valid and invalid inputs, error messages | Vitest |
| UI | Auth flows, wizard, tracking, driver status updates | Playwright E2E |
| Realtime | Ping from simulator appears on map in under 1 s | Manual + scripted |
| Performance | Query plans with `EXPLAIN ANALYZE` on key queries before/after indexes | SQL |
| Responsive/A11y | Lighthouse ≥ 90 performance/accessibility on key pages | Lighthouse |

### 11.2 Sample Test Cases

| ID | Scenario | Expected |
| --- | --- | --- |
| TC-01 | Insert package with weight −2 | CHECK violation |
| TC-02 | Move shipment DELIVERED → IN_TRANSIT | Rejected by trigger |
| TC-03 | Assign 1200 kg to 1000 kg vehicle | Rejected, rollback |
| TC-04 | Driver with expired license assigned | Rejected |
| TC-05 | Customer A queries Customer B's shipment | 0 rows (RLS) |
| TC-06 | Driver updates a shipment not assigned to them | Denied |
| TC-07 | Update/delete a tracking_event | Denied |
| TC-08 | Public track with valid ID | Returns limited fields only |
| TC-09 | Simulator ping | Marker moves live on customer page |
| TC-10 | Concurrent assignment to same vehicle | One succeeds, one fails cleanly |

Deliver a **test report table** (ID, input, expected, actual, pass/fail, screenshot).

---

## 12. Stage 11 — Demonstration and Documentation

### 12.1 Demo Script (8–10 minutes)

1. Problem and ER diagram (60 s)
2. Normalization example and schema in Supabase dashboard (90 s)
3. Landing page 3D hero and scroll story (45 s)
4. Customer signs up → creates shipment → sees tracking ID and quote (90 s)
5. Dispatcher assigns shipment to trip; capacity rule rejection shown live (90 s)
6. Driver updates status; customer page updates live with simulator running (90 s)
7. Show a blocked invalid transition and an RLS denial (60 s)
8. Admin analytics and views (45 s)
9. Q&A prep: why 3NF, why triggers, why RLS

### 12.2 Documentation Pack

1. Cover page, abstract, problem statement
2. Requirement analysis (this PRD sections 2)
3. ER/EER diagram with explanation
4. Relational schema
5. Normalization with FD lists
6. DDL scripts (annotated)
7. DML scripts and sample query outputs
8. Advanced SQL: joins, subqueries, aggregates, window functions (`rank()` for driver performance), CTEs, views
9. Triggers, functions, procedures with explanation
10. Frontend screenshots for every screen
11. Architecture and connectivity description
12. Test report
13. Limitations and future scope (route optimization, IoT GPS, payments, mobile apps)
14. Conclusion, references, GitHub and live-site links

### 12.3 Required Showcase Queries

- Shipments per hub per month (GROUP BY, HAVING)
- Top 5 drivers by on-time rate (window function + CTE)
- Delayed shipments (join with expected vs actual)
- Vehicles with utilization under 40% (subquery)
- Customer lifetime value (aggregate + join)
- Latest location per vehicle (`DISTINCT ON`)

---

## 13. Delivery Plan

| Phase | Work | Output |
| --- | --- | --- |
| 1 | Requirements, ER/EER, relational model, normalization | Docs and diagrams |
| 2 | DDL, constraints, indexes, enums, migrations | Working schema on Supabase |
| 3 | Triggers, functions, RPCs, views, RLS | Business logic layer + tests |
| 4 | Seed data and simulator | Realistic dataset, live pings |
| 5 | Design system, landing page with 3D | Public site |
| 6 | Auth, customer portal, tracking page with map | Core customer flow |
| 7 | Dispatcher console, driver app, admin analytics | Full roles |
| 8 | Realtime polish, performance, accessibility | Production quality |
| 9 | Testing, bug fixes, documentation, demo rehearsal | Final submission |

---

## 14. Acceptance Criteria (Definition of Done)

- [ ] All 11 teacher stages have a dedicated, complete section in the documentation.
- [ ] Every table is in 3NF with justification for any denormalization.
- [ ] Schema deployed on Supabase via versioned migrations; seed data loaded.
- [ ] RLS enabled on all tables and verified for all four roles.
- [ ] Invalid transitions, capacity overflows and ineligible drivers are blocked by the database.
- [ ] Live tracking works end to end with under 1 s latency.
- [ ] Frontend is responsive, themed, 3D landing works with fallback, and passes Lighthouse ≥ 90.
- [ ] No console errors; no secrets in the repo; README with setup and demo credentials.
- [ ] 100% of listed test cases pass and are documented.
- [ ] Demo runs cleanly from a fresh browser in under 10 minutes.

---

## 15. Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| RLS recursion or misconfiguration | Data leak or blocked queries | `security definer` helper, per-role tests |
| 3D slows low-end laptops | Poor demo | Lazy load, DPR cap, static fallback |
| Free-tier Supabase limits (realtime connections, storage) | Demo failure | Throttle pings (every 3–5 s), prune old pings, cache |
| Map tile or network failure during demo | Broken tracking view | Pre-recorded fallback video, local simulator |
| Scope creep | Missed deadline | Strict MVP: Phases 1–7 first, polish after |
| Looks "templated" | Lower impression | Follow section 8.1 rules; custom tokens, real copy and data |

---

## 16. Appendix — Glossary

**RLS:** Row Level Security. **EER:** Enhanced ER model. **ETA:** Estimated time of arrival. **POD:** Proof of delivery. **FD:** Functional dependency. **RPC:** Remote procedure call (Postgres function exposed by Supabase). **Hub:** Warehouse/sorting facility.