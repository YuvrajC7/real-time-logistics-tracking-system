-- ============================================================
-- TABLE: profiles (supertype — mirrors auth.users)
-- ============================================================
CREATE TABLE profiles (
  profile_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name     TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  phone         TEXT,
  role          user_role NOT NULL DEFAULT 'customer',
  avatar_url    TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: customers (subtype)
-- ============================================================
CREATE TABLE customers (
  customer_id   UUID PRIMARY KEY REFERENCES profiles(profile_id) ON DELETE CASCADE,
  company_name  TEXT,
  customer_type customer_type NOT NULL DEFAULT 'INDIVIDUAL'
);

-- ============================================================
-- TABLE: drivers (subtype)
-- ============================================================
CREATE TABLE drivers (
  driver_id       UUID PRIMARY KEY REFERENCES profiles(profile_id) ON DELETE CASCADE,
  license_no      TEXT NOT NULL UNIQUE,
  license_expiry  DATE NOT NULL,
  availability    BOOLEAN NOT NULL DEFAULT TRUE,
  rating          NUMERIC(3,2) CHECK (rating >= 0 AND rating <= 5),
  total_deliveries INTEGER NOT NULL DEFAULT 0,
  on_time_count    INTEGER NOT NULL DEFAULT 0
);

-- ============================================================
-- TABLE: addresses
-- ============================================================
CREATE TABLE addresses (
  address_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  line1       TEXT NOT NULL,
  line2       TEXT,
  city        TEXT NOT NULL,
  state       TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  country     TEXT NOT NULL DEFAULT 'India',
  lat         NUMERIC(10,7) CHECK (lat BETWEEN -90 AND 90),
  lng         NUMERIC(10,7) CHECK (lng BETWEEN -180 AND 180),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: hubs
-- ============================================================
CREATE TABLE hubs (
  hub_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  address_id  UUID NOT NULL REFERENCES addresses(address_id) ON DELETE RESTRICT,
  capacity    INTEGER NOT NULL CHECK (capacity > 0),
  status      hub_status NOT NULL DEFAULT 'ACTIVE',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: employees (subtype — dispatchers and admins)
-- ============================================================
CREATE TABLE employees (
  employee_id  UUID PRIMARY KEY REFERENCES profiles(profile_id) ON DELETE CASCADE,
  hub_id       UUID REFERENCES hubs(hub_id) ON DELETE SET NULL,
  designation  employee_designation NOT NULL DEFAULT 'DISPATCHER'
);

-- ============================================================
-- TABLE: vehicles
-- ============================================================
CREATE TABLE vehicles (
  vehicle_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plate_no      TEXT NOT NULL UNIQUE,
  type          TEXT NOT NULL,
  capacity_kg   NUMERIC(10,2) NOT NULL CHECK (capacity_kg > 0),
  status        vehicle_status NOT NULL DEFAULT 'AVAILABLE',
  home_hub_id   UUID REFERENCES hubs(hub_id) ON DELETE SET NULL,
  model         TEXT,
  year          INTEGER CHECK (year >= 1990 AND year <= 2030),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: routes
-- ============================================================
CREATE TABLE routes (
  route_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL UNIQUE,
  origin_hub_id    UUID NOT NULL REFERENCES hubs(hub_id) ON DELETE RESTRICT,
  destination_hub_id UUID NOT NULL REFERENCES hubs(hub_id) ON DELETE RESTRICT,
  distance_km      NUMERIC(10,2) NOT NULL CHECK (distance_km > 0),
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: route_stops (weak entity — composite PK)
-- ============================================================
CREATE TABLE route_stops (
  route_id         UUID NOT NULL REFERENCES routes(route_id) ON DELETE CASCADE,
  stop_no          INTEGER NOT NULL CHECK (stop_no >= 1),
  hub_id           UUID NOT NULL REFERENCES hubs(hub_id) ON DELETE RESTRICT,
  expected_minutes INTEGER NOT NULL CHECK (expected_minutes > 0),
  PRIMARY KEY (route_id, stop_no)
);

-- ============================================================
-- TABLE: shipments
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS shipment_seq START 1;

CREATE TABLE shipments (
  shipment_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tracking_no     TEXT NOT NULL UNIQUE,
  sender_id       UUID NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
  receiver_name   TEXT NOT NULL,
  receiver_phone  TEXT NOT NULL,
  origin_addr_id  UUID NOT NULL REFERENCES addresses(address_id) ON DELETE RESTRICT,
  dest_addr_id    UUID NOT NULL REFERENCES addresses(address_id) ON DELETE RESTRICT,
  service_type    service_type NOT NULL DEFAULT 'STANDARD',
  status          shipment_status NOT NULL DEFAULT 'CREATED',
  charge          NUMERIC(12,2),
  eta             TIMESTAMPTZ,
  special_notes   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: packages
-- ============================================================
CREATE TABLE packages (
  package_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id  UUID NOT NULL REFERENCES shipments(shipment_id) ON DELETE CASCADE,
  description  TEXT NOT NULL,
  weight_kg    NUMERIC(10,2) NOT NULL CHECK (weight_kg > 0),
  length_cm    NUMERIC(10,2) CHECK (length_cm > 0),
  width_cm     NUMERIC(10,2) CHECK (width_cm > 0),
  height_cm    NUMERIC(10,2) CHECK (height_cm > 0),
  category     TEXT NOT NULL DEFAULT 'General',
  is_fragile   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: trips
-- ============================================================
CREATE TABLE trips (
  trip_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id       UUID NOT NULL REFERENCES drivers(driver_id) ON DELETE RESTRICT,
  vehicle_id      UUID NOT NULL REFERENCES vehicles(vehicle_id) ON DELETE RESTRICT,
  route_id        UUID REFERENCES routes(route_id) ON DELETE SET NULL,
  from_hub_id     UUID REFERENCES hubs(hub_id) ON DELETE SET NULL,
  to_hub_id       UUID REFERENCES hubs(hub_id) ON DELETE SET NULL,
  status          trip_status NOT NULL DEFAULT 'PLANNED',
  planned_start   TIMESTAMPTZ NOT NULL,
  actual_start    TIMESTAMPTZ,
  actual_end      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: trip_shipments (associative M:N entity)
-- ============================================================
CREATE TABLE trip_shipments (
  trip_id      UUID NOT NULL REFERENCES trips(trip_id) ON DELETE RESTRICT,
  shipment_id  UUID NOT NULL REFERENCES shipments(shipment_id) ON DELETE RESTRICT,
  sequence_no  INTEGER NOT NULL CHECK (sequence_no >= 1),
  loaded_at    TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  PRIMARY KEY (trip_id, shipment_id)
);

-- ============================================================
-- TABLE: tracking_events (immutable log)
-- ============================================================
CREATE TABLE tracking_events (
  event_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id  UUID NOT NULL REFERENCES shipments(shipment_id) ON DELETE RESTRICT,
  status       shipment_status NOT NULL,
  hub_id       UUID REFERENCES hubs(hub_id) ON DELETE SET NULL,
  note         TEXT,
  created_by   UUID REFERENCES profiles(profile_id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: location_pings
-- ============================================================
CREATE TABLE location_pings (
  ping_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id  UUID NOT NULL REFERENCES vehicles(vehicle_id) ON DELETE CASCADE,
  trip_id     UUID REFERENCES trips(trip_id) ON DELETE SET NULL,
  lat         NUMERIC(10,7) NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lng         NUMERIC(10,7) NOT NULL CHECK (lng BETWEEN -180 AND 180),
  speed_kmph  NUMERIC(6,2) CHECK (speed_kmph >= 0),
  heading     NUMERIC(5,2) CHECK (heading >= 0 AND heading < 360),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: delivery_proofs
-- ============================================================
CREATE TABLE delivery_proofs (
  proof_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id     UUID NOT NULL UNIQUE REFERENCES shipments(shipment_id) ON DELETE RESTRICT,
  photo_url       TEXT NOT NULL,
  recipient_name  TEXT NOT NULL,
  otp_verified    BOOLEAN NOT NULL DEFAULT FALSE,
  signed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: invoices
-- ============================================================
CREATE TABLE invoices (
  invoice_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shipment_id UUID NOT NULL UNIQUE REFERENCES shipments(shipment_id) ON DELETE RESTRICT,
  amount      NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  tax         NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (tax >= 0),
  status      invoice_status NOT NULL DEFAULT 'PENDING',
  issued_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: notifications
-- ============================================================
CREATE TABLE notifications (
  notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id      UUID NOT NULL REFERENCES profiles(profile_id) ON DELETE CASCADE,
  shipment_id     UUID REFERENCES shipments(shipment_id) ON DELETE CASCADE,
  message         TEXT NOT NULL,
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: status_transitions (lookup for valid state machine)
-- ============================================================
CREATE TABLE status_transitions (
  from_status  shipment_status NOT NULL,
  to_status    shipment_status NOT NULL,
  PRIMARY KEY (from_status, to_status)
);

-- Seed valid transitions
INSERT INTO status_transitions (from_status, to_status) VALUES
  ('CREATED',          'PICKED_UP'),
  ('CREATED',          'CANCELLED'),
  ('PICKED_UP',        'IN_TRANSIT'),
  ('PICKED_UP',        'FAILED_ATTEMPT'),
  ('PICKED_UP',        'CANCELLED'),
  ('IN_TRANSIT',       'AT_HUB'),
  ('IN_TRANSIT',       'OUT_FOR_DELIVERY'),
  ('IN_TRANSIT',       'FAILED_ATTEMPT'),
  ('AT_HUB',          'IN_TRANSIT'),
  ('AT_HUB',          'OUT_FOR_DELIVERY'),
  ('AT_HUB',          'CANCELLED'),
  ('OUT_FOR_DELIVERY', 'DELIVERED'),
  ('OUT_FOR_DELIVERY', 'FAILED_ATTEMPT'),
  ('FAILED_ATTEMPT',   'OUT_FOR_DELIVERY'),
  ('FAILED_ATTEMPT',   'RETURNED'),
  ('FAILED_ATTEMPT',   'CANCELLED'),
  ('RETURNED',         'CANCELLED');

-- ============================================================
-- TABLE: pricing_rules (editable without code changes)
-- ============================================================
CREATE TABLE pricing_rules (
  service      service_type PRIMARY KEY,
  base_charge  NUMERIC(10,2) NOT NULL CHECK (base_charge >= 0),
  rate_per_kg  NUMERIC(10,2) NOT NULL CHECK (rate_per_kg >= 0),
  rate_per_km  NUMERIC(10,2) NOT NULL CHECK (rate_per_km >= 0),
  gst_rate     NUMERIC(5,4) NOT NULL DEFAULT 0.18
);

INSERT INTO pricing_rules (service, base_charge, rate_per_kg, rate_per_km) VALUES
  ('STANDARD', 50.00, 8.00, 2.50),
  ('EXPRESS',  100.00, 12.00, 4.00),
  ('SAME_DAY', 200.00, 20.00, 8.00);
