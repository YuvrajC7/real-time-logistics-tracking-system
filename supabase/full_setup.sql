-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- pg_cron for scheduled materialized view refresh (enable in Supabase dashboard if needed)
-- CREATE EXTENSION IF NOT EXISTS pg_cron;


-- Enum Types
CREATE TYPE user_role AS ENUM ('admin', 'dispatcher', 'driver', 'customer');
CREATE TYPE shipment_status AS ENUM (
  'CREATED', 'PICKED_UP', 'IN_TRANSIT', 'AT_HUB',
  'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED_ATTEMPT', 'RETURNED', 'CANCELLED'
);
CREATE TYPE service_type AS ENUM ('STANDARD', 'EXPRESS', 'SAME_DAY');
CREATE TYPE vehicle_status AS ENUM ('AVAILABLE', 'ON_TRIP', 'MAINTENANCE', 'RETIRED');
CREATE TYPE trip_status AS ENUM ('PLANNED', 'ONGOING', 'COMPLETED', 'CANCELLED');
CREATE TYPE invoice_status AS ENUM ('PENDING', 'PAID', 'CANCELLED');
CREATE TYPE hub_status AS ENUM ('ACTIVE', 'INACTIVE', 'MAINTENANCE');
CREATE TYPE customer_type AS ENUM ('INDIVIDUAL', 'BUSINESS');
CREATE TYPE employee_designation AS ENUM ('DISPATCHER', 'ADMIN', 'HUB_MANAGER');


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


-- Performance indexes as specified in PRD §6.3

-- shipments
CREATE INDEX idx_shipments_tracking_no ON shipments(tracking_no);
CREATE INDEX idx_shipments_sender_created ON shipments(sender_id, created_at DESC);
CREATE INDEX idx_shipments_status ON shipments(status);

-- tracking_events
CREATE INDEX idx_tracking_events_shipment_time ON tracking_events(shipment_id, created_at);

-- location_pings
CREATE INDEX idx_location_pings_vehicle_time ON location_pings(vehicle_id, recorded_at DESC);
CREATE INDEX idx_location_pings_recorded_brin ON location_pings USING BRIN (recorded_at);

-- trips
CREATE INDEX idx_trips_driver_status ON trips(driver_id, status);
CREATE INDEX idx_trips_vehicle_status ON trips(vehicle_id, status);

-- notifications
CREATE INDEX idx_notifications_profile_read ON notifications(profile_id, is_read);

-- trip_shipments
CREATE INDEX idx_trip_shipments_shipment ON trip_shipments(shipment_id);

-- packages
CREATE INDEX idx_packages_shipment ON packages(shipment_id);

-- profiles
CREATE INDEX idx_profiles_role ON profiles(role);

-- route_stops
CREATE INDEX idx_route_stops_hub ON route_stops(hub_id);


-- ============================================================
-- HELPER: auth_role() — SECURITY DEFINER to avoid RLS recursion
-- ============================================================
CREATE OR REPLACE FUNCTION auth_role()
RETURNS user_role
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM profiles WHERE profile_id = auth.uid();
$$;

-- ============================================================
-- HELPER: haversine_km(lat1,lng1,lat2,lng2)
-- ============================================================
CREATE OR REPLACE FUNCTION haversine_km(
  lat1 NUMERIC, lng1 NUMERIC,
  lat2 NUMERIC, lng2 NUMERIC
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  r     CONSTANT NUMERIC := 6371;
  dlat  NUMERIC := RADIANS(lat2 - lat1);
  dlng  NUMERIC := RADIANS(lng2 - lng1);
  a     NUMERIC;
BEGIN
  a := SIN(dlat/2)^2 + COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * SIN(dlng/2)^2;
  RETURN r * 2 * ASIN(SQRT(a));
END;
$$;

-- ============================================================
-- FUNCTION: calculate_charge(weight, distance_km, service)
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_charge(
  p_weight      NUMERIC,
  p_distance_km NUMERIC,
  p_service     service_type
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_rule   pricing_rules%ROWTYPE;
  v_base   NUMERIC;
  v_gst    NUMERIC;
BEGIN
  SELECT * INTO v_rule FROM pricing_rules WHERE service = p_service;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown service type: %', p_service;
  END IF;
  v_base := v_rule.base_charge
            + (v_rule.rate_per_kg * p_weight)
            + (v_rule.rate_per_km * p_distance_km);
  v_gst  := v_base * v_rule.gst_rate;
  RETURN ROUND(v_base + v_gst, 2);
END;
$$;

-- ============================================================
-- FUNCTION: estimate_eta(shipment_id)
-- Returns an estimated delivery timestamp based on remaining stops
-- ============================================================
CREATE OR REPLACE FUNCTION estimate_eta(p_shipment_id UUID)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_eta          TIMESTAMPTZ;
  v_trip_id      UUID;
  v_route_id     UUID;
  v_remaining_min INTEGER := 0;
BEGIN
  -- Find active trip for this shipment
  SELECT ts.trip_id INTO v_trip_id
  FROM trip_shipments ts
  JOIN trips t ON ts.trip_id = t.trip_id
  WHERE ts.shipment_id = p_shipment_id
    AND t.status IN ('PLANNED', 'ONGOING')
  ORDER BY t.planned_start DESC
  LIMIT 1;

  IF v_trip_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Get route
  SELECT route_id INTO v_route_id FROM trips WHERE trip_id = v_trip_id;

  IF v_route_id IS NOT NULL THEN
    -- Sum remaining stop times (simplified: sum all stops)
    SELECT COALESCE(SUM(expected_minutes), 120)
    INTO v_remaining_min
    FROM route_stops
    WHERE route_id = v_route_id;
  ELSE
    v_remaining_min := 120;
  END IF;

  -- ETA = now + remaining minutes
  v_eta := NOW() + (v_remaining_min || ' minutes')::INTERVAL;
  RETURN v_eta;
END;
$$;

-- ============================================================
-- RPC: public_track(tracking_no) — security definer, no RLS bypass
-- Returns only non-sensitive fields
-- ============================================================
CREATE OR REPLACE FUNCTION public_track(p_tracking_no TEXT)
RETURNS TABLE (
  tracking_no     TEXT,
  status          shipment_status,
  receiver_name   TEXT,
  service_type    service_type,
  eta             TIMESTAMPTZ,
  created_at      TIMESTAMPTZ,
  origin_city     TEXT,
  dest_city       TEXT
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.tracking_no,
    s.status,
    s.receiver_name,
    s.service_type,
    s.eta,
    s.created_at,
    oa.city AS origin_city,
    da.city AS dest_city
  FROM shipments s
  JOIN addresses oa ON s.origin_addr_id = oa.address_id
  JOIN addresses da ON s.dest_addr_id = da.address_id
  WHERE s.tracking_no = p_tracking_no;
$$;

-- ============================================================
-- RPC: get_shipment_events(tracking_no) — public timeline
-- ============================================================
CREATE OR REPLACE FUNCTION get_shipment_events(p_tracking_no TEXT)
RETURNS TABLE (
  status     shipment_status,
  hub_name   TEXT,
  note       TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    te.status,
    h.name AS hub_name,
    te.note,
    te.created_at
  FROM tracking_events te
  LEFT JOIN hubs h ON te.hub_id = h.hub_id
  JOIN shipments s ON te.shipment_id = s.shipment_id
  WHERE s.tracking_no = p_tracking_no
  ORDER BY te.created_at ASC;
$$;

-- ============================================================
-- RPC: get_vehicle_location(tracking_no) — for customer map
-- ============================================================
CREATE OR REPLACE FUNCTION get_vehicle_location(p_tracking_no TEXT)
RETURNS TABLE (
  lat         NUMERIC,
  lng         NUMERIC,
  speed_kmph  NUMERIC,
  recorded_at TIMESTAMPTZ
)
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT lp.lat, lp.lng, lp.speed_kmph, lp.recorded_at
  FROM location_pings lp
  JOIN trips t ON lp.trip_id = t.trip_id
  JOIN trip_shipments ts ON ts.trip_id = t.trip_id
  JOIN shipments s ON ts.shipment_id = s.shipment_id
  WHERE s.tracking_no = p_tracking_no
    AND t.status = 'ONGOING'
  ORDER BY lp.recorded_at DESC
  LIMIT 1;
$$;


-- ============================================================
-- TRIGGER: handle_new_user
-- Creates a profiles row when a new auth.users row is inserted
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO profiles (profile_id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    NEW.email,
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'customer')
  )
  ON CONFLICT (profile_id) DO NOTHING;

  -- If customer role, also insert into customers table
  IF COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'customer') = 'customer' THEN
    INSERT INTO customers (customer_id, customer_type)
    VALUES (NEW.id, 'INDIVIDUAL')
    ON CONFLICT (customer_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- ============================================================
-- TRIGGER: generate_tracking_no
-- Generates RTL-YYYY-NNNNNN on shipment insert
-- ============================================================
CREATE OR REPLACE FUNCTION generate_tracking_no()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.tracking_no IS NULL OR NEW.tracking_no = '' THEN
    NEW.tracking_no := 'RTL-' || TO_CHAR(NOW(), 'YYYY') || '-' ||
                       LPAD(NEXTVAL('shipment_seq')::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER before_shipment_insert
  BEFORE INSERT ON shipments
  FOR EACH ROW EXECUTE PROCEDURE generate_tracking_no();

-- ============================================================
-- TRIGGER: enforce_status_transition
-- Validates allowed transitions; blocks edits after DELIVERED
-- ============================================================
CREATE OR REPLACE FUNCTION enforce_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Block any change once DELIVERED
  IF OLD.status = 'DELIVERED' THEN
    RAISE EXCEPTION 'Cannot change status of a delivered shipment (ID: %)', OLD.shipment_id;
  END IF;

  -- Allow same-status update (idempotent)
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Check lookup table for valid transition
  IF NOT EXISTS (
    SELECT 1 FROM status_transitions
    WHERE from_status = OLD.status AND to_status = NEW.status
  ) THEN
    RAISE EXCEPTION 'Invalid status transition: % -> % for shipment %',
      OLD.status, NEW.status, OLD.tracking_no;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER before_shipment_status_update
  BEFORE UPDATE OF status ON shipments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE PROCEDURE enforce_status_transition();

-- ============================================================
-- TRIGGER: log_tracking_event
-- After status change, insert tracking_event and notification
-- ============================================================
CREATE OR REPLACE FUNCTION log_tracking_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_profile_id UUID;
  v_msg TEXT;
BEGIN
  -- Insert tracking event
  INSERT INTO tracking_events (shipment_id, status, created_by)
  VALUES (NEW.shipment_id, NEW.status, auth.uid());

  -- Build notification message
  v_msg := 'Your shipment ' || NEW.tracking_no || ' is now ' || NEW.status::TEXT;

  -- Get sender profile
  SELECT profile_id INTO v_sender_profile_id
  FROM customers WHERE customer_id = NEW.sender_id;

  -- Notify sender
  INSERT INTO notifications (profile_id, shipment_id, message)
  VALUES (v_sender_profile_id, NEW.shipment_id, v_msg);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER after_shipment_status_change
  AFTER UPDATE OF status ON shipments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE PROCEDURE log_tracking_event();

-- ============================================================
-- TRIGGER: check_vehicle_capacity
-- On trip_shipments insert, verify total weight <= capacity
-- ============================================================
CREATE OR REPLACE FUNCTION check_vehicle_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_weight  NUMERIC;
  v_capacity      NUMERIC;
  v_vehicle_id    UUID;
BEGIN
  SELECT vehicle_id INTO v_vehicle_id FROM trips WHERE trip_id = NEW.trip_id;

  SELECT capacity_kg INTO v_capacity FROM vehicles WHERE vehicle_id = v_vehicle_id;

  SELECT COALESCE(SUM(p.weight_kg), 0)
  INTO v_total_weight
  FROM trip_shipments ts
  JOIN packages p ON ts.shipment_id = p.shipment_id
  WHERE ts.trip_id = NEW.trip_id;

  -- Add weight of new shipment's packages
  v_total_weight := v_total_weight + (
    SELECT COALESCE(SUM(weight_kg), 0)
    FROM packages
    WHERE shipment_id = NEW.shipment_id
  );

  IF v_total_weight > v_capacity THEN
    RAISE EXCEPTION 'Vehicle capacity exceeded: %.2f kg loaded, capacity is %.2f kg',
      v_total_weight, v_capacity;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER before_trip_shipment_insert
  BEFORE INSERT ON trip_shipments
  FOR EACH ROW EXECUTE PROCEDURE check_vehicle_capacity();

-- ============================================================
-- TRIGGER: check_driver_eligibility
-- On trip insert, verify driver license not expired + not double-booked
-- ============================================================
CREATE OR REPLACE FUNCTION check_driver_eligibility()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_expiry DATE;
  v_overlap_count INTEGER;
BEGIN
  -- Check license expiry
  SELECT license_expiry INTO v_expiry FROM drivers WHERE driver_id = NEW.driver_id;

  IF v_expiry < CURRENT_DATE THEN
    RAISE EXCEPTION 'Driver license expired on % — cannot assign to trip', v_expiry;
  END IF;

  -- Check overlapping ongoing trips for same driver
  SELECT COUNT(*) INTO v_overlap_count
  FROM trips
  WHERE driver_id = NEW.driver_id
    AND trip_id <> NEW.trip_id
    AND status IN ('PLANNED', 'ONGOING')
    AND (
      (planned_start, COALESCE(actual_end, planned_start + INTERVAL '12 hours'))
      OVERLAPS
      (NEW.planned_start, NEW.planned_start + INTERVAL '12 hours')
    );

  IF v_overlap_count > 0 THEN
    RAISE EXCEPTION 'Driver is already assigned to an overlapping trip';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER before_trip_insert_driver_check
  BEFORE INSERT OR UPDATE ON trips
  FOR EACH ROW EXECUTE PROCEDURE check_driver_eligibility();

-- ============================================================
-- TRIGGER: set_updated_at — generic timestamp maintenance
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER set_updated_at_profiles
  BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE OR REPLACE TRIGGER set_updated_at_shipments
  BEFORE UPDATE ON shipments FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE OR REPLACE TRIGGER set_updated_at_vehicles
  BEFORE UPDATE ON vehicles FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE OR REPLACE TRIGGER set_updated_at_trips
  BEFORE UPDATE ON trips FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
CREATE OR REPLACE TRIGGER set_updated_at_hubs
  BEFORE UPDATE ON hubs FOR EACH ROW EXECUTE PROCEDURE set_updated_at();


-- ============================================================
-- RPC: assign_shipment_to_trip
-- Transactional: verifies capacity + driver, inserts trip_shipments,
-- updates shipment status
-- ============================================================
CREATE OR REPLACE FUNCTION assign_shipment_to_trip(
  p_shipment_id UUID,
  p_trip_id     UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_seq     INTEGER;
  v_trip    trips%ROWTYPE;
  v_ship    shipments%ROWTYPE;
BEGIN
  -- Lock the trip row to prevent concurrent double-assign
  SELECT * INTO v_trip FROM trips WHERE trip_id = p_trip_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Trip not found: %', p_trip_id;
  END IF;

  IF v_trip.status NOT IN ('PLANNED', 'ONGOING') THEN
    RAISE EXCEPTION 'Trip % is not in a state that accepts shipments', p_trip_id;
  END IF;

  SELECT * INTO v_ship FROM shipments WHERE shipment_id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found: %', p_shipment_id;
  END IF;

  IF v_ship.status NOT IN ('CREATED', 'AT_HUB') THEN
    RAISE EXCEPTION 'Shipment % cannot be assigned (status: %)', p_shipment_id, v_ship.status;
  END IF;

  -- Get next sequence number
  SELECT COALESCE(MAX(sequence_no), 0) + 1
  INTO v_seq
  FROM trip_shipments
  WHERE trip_id = p_trip_id;

  -- Insert into trip_shipments (capacity trigger fires here)
  INSERT INTO trip_shipments (trip_id, shipment_id, sequence_no)
  VALUES (p_trip_id, p_shipment_id, v_seq);

  -- Update shipment status to PICKED_UP
  UPDATE shipments SET status = 'PICKED_UP' WHERE shipment_id = p_shipment_id;

  RETURN jsonb_build_object(
    'success', true,
    'trip_id', p_trip_id,
    'shipment_id', p_shipment_id,
    'sequence_no', v_seq
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ============================================================
-- RPC: update_shipment_status
-- Single entry point for all status changes
-- ============================================================
CREATE OR REPLACE FUNCTION update_shipment_status(
  p_shipment_id UUID,
  p_new_status  shipment_status,
  p_hub_id      UUID DEFAULT NULL,
  p_note        TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_old_status shipment_status;
BEGIN
  SELECT status INTO v_old_status FROM shipments WHERE shipment_id = p_shipment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found: %', p_shipment_id;
  END IF;

  -- The trigger enforce_status_transition will validate the transition
  UPDATE shipments SET status = p_new_status WHERE shipment_id = p_shipment_id;

  -- Update the hub_id on the auto-inserted tracking event
  IF p_hub_id IS NOT NULL OR p_note IS NOT NULL THEN
    UPDATE tracking_events
    SET hub_id = p_hub_id, note = p_note
    WHERE event_id = (
      SELECT event_id FROM tracking_events
      WHERE shipment_id = p_shipment_id
        AND status = p_new_status
      ORDER BY created_at DESC
      LIMIT 1
    );
  END IF;

  -- If DELIVERED, create delivery proof placeholder and mark invoice PAID
  IF p_new_status = 'DELIVERED' THEN
    UPDATE invoices SET status = 'PAID' WHERE shipment_id = p_shipment_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'new_status', p_new_status);
EXCEPTION
  WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ============================================================
-- RPC: record_location
-- Inserts a location ping and updates shipment ETA
-- ============================================================
CREATE OR REPLACE FUNCTION record_location(
  p_vehicle_id UUID,
  p_lat        NUMERIC,
  p_lng        NUMERIC,
  p_speed      NUMERIC DEFAULT NULL,
  p_heading    NUMERIC DEFAULT NULL,
  p_trip_id    UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ping_id UUID;
BEGIN
  INSERT INTO location_pings (vehicle_id, trip_id, lat, lng, speed_kmph, heading)
  VALUES (p_vehicle_id, p_trip_id, p_lat, p_lng, p_speed, p_heading)
  RETURNING ping_id INTO v_ping_id;

  RETURN jsonb_build_object('success', true, 'ping_id', v_ping_id);
END;
$$;

-- ============================================================
-- RPC: get_dispatcher_stats
-- Returns live KPIs for dispatcher dashboard
-- ============================================================
CREATE OR REPLACE FUNCTION get_dispatcher_stats()
RETURNS JSONB
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'total_active_vehicles',
      (SELECT COUNT(*) FROM vehicles WHERE status = 'ON_TRIP'),
    'total_shipments_today',
      (SELECT COUNT(*) FROM shipments WHERE created_at::DATE = CURRENT_DATE),
    'in_transit',
      (SELECT COUNT(*) FROM shipments WHERE status = 'IN_TRANSIT'),
    'delivered_today',
      (SELECT COUNT(*) FROM shipments
       WHERE status = 'DELIVERED' AND updated_at::DATE = CURRENT_DATE),
    'failed_today',
      (SELECT COUNT(*) FROM shipments
       WHERE status = 'FAILED_ATTEMPT' AND updated_at::DATE = CURRENT_DATE)
  );
$$;


-- ============================================================
-- VIEW: v_active_shipments
-- Joined view for dispatcher: active shipments with addresses
-- ============================================================
CREATE OR REPLACE VIEW v_active_shipments AS
SELECT
  s.shipment_id,
  s.tracking_no,
  s.status,
  s.service_type,
  s.charge,
  s.eta,
  s.created_at,
  p.full_name    AS sender_name,
  p.email        AS sender_email,
  p.phone        AS sender_phone,
  s.receiver_name,
  s.receiver_phone,
  oa.city        AS origin_city,
  oa.state       AS origin_state,
  oa.line1       AS origin_line1,
  da.city        AS dest_city,
  da.state       AS dest_state,
  da.line1       AS dest_line1
FROM shipments s
JOIN customers c   ON s.sender_id     = c.customer_id
JOIN profiles p    ON c.customer_id   = p.profile_id
JOIN addresses oa  ON s.origin_addr_id = oa.address_id
JOIN addresses da  ON s.dest_addr_id   = da.address_id
WHERE s.status NOT IN ('DELIVERED', 'CANCELLED', 'RETURNED');

-- ============================================================
-- VIEW: v_driver_performance
-- Window function: RANK() drivers by on-time rate
-- ============================================================
CREATE OR REPLACE VIEW v_driver_performance AS
WITH driver_stats AS (
  SELECT
    d.driver_id,
    p.full_name,
    d.rating,
    d.total_deliveries,
    d.on_time_count,
    CASE
      WHEN d.total_deliveries > 0
      THEN ROUND((d.on_time_count::NUMERIC / d.total_deliveries) * 100, 2)
      ELSE 0
    END AS on_time_rate_pct
  FROM drivers d
  JOIN profiles p ON d.driver_id = p.profile_id
)
SELECT
  driver_id,
  full_name,
  rating,
  total_deliveries,
  on_time_count,
  on_time_rate_pct,
  RANK() OVER (ORDER BY on_time_rate_pct DESC, total_deliveries DESC) AS performance_rank
FROM driver_stats;

-- ============================================================
-- VIEW: v_hub_throughput
-- Shipments per hub per month (GROUP BY + HAVING)
-- ============================================================
CREATE OR REPLACE VIEW v_hub_throughput AS
SELECT
  h.hub_id,
  h.name AS hub_name,
  DATE_TRUNC('month', te.created_at) AS month,
  COUNT(*) AS shipment_count,
  COUNT(*) FILTER (WHERE te.status = 'DELIVERED') AS delivered_count,
  COUNT(*) FILTER (WHERE te.status = 'FAILED_ATTEMPT') AS failed_count
FROM tracking_events te
JOIN hubs h ON te.hub_id = h.hub_id
GROUP BY h.hub_id, h.name, DATE_TRUNC('month', te.created_at)
HAVING COUNT(*) > 0
ORDER BY month DESC, shipment_count DESC;

-- ============================================================
-- VIEW: v_latest_vehicle_location
-- Latest ping per vehicle using DISTINCT ON
-- ============================================================
CREATE OR REPLACE VIEW v_latest_vehicle_location AS
SELECT DISTINCT ON (lp.vehicle_id)
  lp.vehicle_id,
  v.plate_no,
  v.type AS vehicle_type,
  v.status AS vehicle_status,
  h.name AS home_hub_name,
  lp.lat,
  lp.lng,
  lp.speed_kmph,
  lp.heading,
  lp.trip_id,
  lp.recorded_at,
  t.status AS trip_status,
  p.full_name AS driver_name
FROM location_pings lp
JOIN vehicles v ON lp.vehicle_id = v.vehicle_id
LEFT JOIN hubs h ON v.home_hub_id = h.hub_id
LEFT JOIN trips t ON lp.trip_id = t.trip_id
LEFT JOIN drivers d ON t.driver_id = d.driver_id
LEFT JOIN profiles p ON d.driver_id = p.profile_id
ORDER BY lp.vehicle_id, lp.recorded_at DESC;

-- ============================================================
-- VIEW: v_shipment_timeline
-- Full timeline per shipment
-- ============================================================
CREATE OR REPLACE VIEW v_shipment_timeline AS
SELECT
  te.event_id,
  te.shipment_id,
  s.tracking_no,
  te.status,
  h.name AS hub_name,
  te.note,
  p.full_name AS created_by_name,
  te.created_at
FROM tracking_events te
JOIN shipments s ON te.shipment_id = s.shipment_id
LEFT JOIN hubs h ON te.hub_id = h.hub_id
LEFT JOIN profiles p ON te.created_by = p.profile_id
ORDER BY te.shipment_id, te.created_at ASC;

-- ============================================================
-- VIEW: v_delayed_shipments
-- Shipments past their ETA and not delivered
-- ============================================================
CREATE OR REPLACE VIEW v_delayed_shipments AS
SELECT
  s.shipment_id,
  s.tracking_no,
  s.status,
  s.eta,
  NOW() - s.eta AS delay_interval,
  p.full_name AS sender_name,
  da.city AS dest_city
FROM shipments s
JOIN customers c ON s.sender_id = c.customer_id
JOIN profiles p ON c.customer_id = p.profile_id
JOIN addresses da ON s.dest_addr_id = da.address_id
WHERE s.eta IS NOT NULL
  AND s.eta < NOW()
  AND s.status NOT IN ('DELIVERED', 'CANCELLED', 'RETURNED');

-- ============================================================
-- MATERIALIZED VIEW: mv_daily_kpis
-- Refreshed daily (or manually via pg_cron)
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_daily_kpis AS
SELECT
  DATE_TRUNC('day', s.created_at) AS day,
  COUNT(*) AS total_shipments,
  COUNT(*) FILTER (WHERE s.status = 'DELIVERED') AS delivered,
  COUNT(*) FILTER (WHERE s.status = 'FAILED_ATTEMPT') AS failed,
  COUNT(*) FILTER (WHERE s.status = 'CANCELLED') AS cancelled,
  SUM(s.charge) AS total_revenue,
  ROUND(AVG(s.charge), 2) AS avg_charge,
  COUNT(*) FILTER (WHERE s.status = 'DELIVERED') * 100.0 /
    NULLIF(COUNT(*), 0) AS delivery_rate_pct
FROM shipments s
GROUP BY DATE_TRUNC('day', s.created_at)
ORDER BY day DESC
WITH DATA;

CREATE UNIQUE INDEX ON mv_daily_kpis(day);

-- Function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_daily_kpis()
RETURNS VOID LANGUAGE SQL AS $$
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_kpis;
$$;


-- ============================================================
-- ROW LEVEL SECURITY
-- Enable RLS on every table, then define policies per role
-- Uses auth_role() SECURITY DEFINER helper to avoid recursion
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers          ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers            ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees          ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE hubs               ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE routes             ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_stops        ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments          ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages           ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips              ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_shipments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking_events    ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_pings     ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_proofs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices           ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications      ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_rules      ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- profiles
-- ============================================================
-- Admin: all
CREATE POLICY profiles_admin_all ON profiles
  USING (auth_role() = 'admin')
  WITH CHECK (auth_role() = 'admin');

-- Dispatcher: read all
CREATE POLICY profiles_dispatcher_read ON profiles
  FOR SELECT USING (auth_role() = 'dispatcher');

-- Driver: own only
CREATE POLICY profiles_driver_own ON profiles
  USING (auth_role() = 'driver' AND profile_id = auth.uid())
  WITH CHECK (auth_role() = 'driver' AND profile_id = auth.uid());

-- Customer: own only
CREATE POLICY profiles_customer_own ON profiles
  USING (auth_role() = 'customer' AND profile_id = auth.uid())
  WITH CHECK (auth_role() = 'customer' AND profile_id = auth.uid());

-- ============================================================
-- customers
-- ============================================================
CREATE POLICY customers_admin_all ON customers
  USING (auth_role() = 'admin');
CREATE POLICY customers_dispatcher_read ON customers
  FOR SELECT USING (auth_role() IN ('dispatcher', 'driver'));
CREATE POLICY customers_own ON customers
  USING (auth_role() = 'customer' AND customer_id = auth.uid())
  WITH CHECK (auth_role() = 'customer' AND customer_id = auth.uid());

-- ============================================================
-- drivers
-- ============================================================
CREATE POLICY drivers_admin_all ON drivers
  USING (auth_role() = 'admin');
CREATE POLICY drivers_dispatcher_read ON drivers
  FOR SELECT USING (auth_role() = 'dispatcher');
CREATE POLICY drivers_own ON drivers
  USING (auth_role() = 'driver' AND driver_id = auth.uid())
  WITH CHECK (auth_role() = 'driver' AND driver_id = auth.uid());

-- ============================================================
-- employees
-- ============================================================
CREATE POLICY employees_admin_all ON employees
  USING (auth_role() = 'admin');
CREATE POLICY employees_dispatcher_own ON employees
  USING (auth_role() = 'dispatcher' AND employee_id = auth.uid());

-- ============================================================
-- addresses (all authenticated can create, own can read)
-- ============================================================
CREATE POLICY addresses_admin_all ON addresses
  USING (auth_role() = 'admin');
CREATE POLICY addresses_authenticated_read ON addresses
  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY addresses_insert ON addresses
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================================
-- hubs (admin CRUD, others read)
-- ============================================================
CREATE POLICY hubs_admin_all ON hubs
  USING (auth_role() = 'admin');
CREATE POLICY hubs_read ON hubs
  FOR SELECT USING (auth_role() IN ('dispatcher', 'driver', 'customer'));

-- ============================================================
-- vehicles
-- ============================================================
CREATE POLICY vehicles_admin_all ON vehicles
  USING (auth_role() = 'admin');
CREATE POLICY vehicles_dispatcher_read_update ON vehicles
  FOR SELECT USING (auth_role() = 'dispatcher');
CREATE POLICY vehicles_driver_read ON vehicles
  FOR SELECT USING (auth_role() = 'driver');

-- ============================================================
-- routes and route_stops (admin CRUD, dispatcher+driver read)
-- ============================================================
CREATE POLICY routes_admin ON routes USING (auth_role() = 'admin');
CREATE POLICY routes_read ON routes
  FOR SELECT USING (auth_role() IN ('dispatcher', 'driver'));
CREATE POLICY route_stops_admin ON route_stops USING (auth_role() = 'admin');
CREATE POLICY route_stops_read ON route_stops
  FOR SELECT USING (auth_role() IN ('dispatcher', 'driver'));

-- ============================================================
-- shipments
-- ============================================================
CREATE POLICY shipments_admin_all ON shipments
  USING (auth_role() = 'admin');
CREATE POLICY shipments_dispatcher_all ON shipments
  USING (auth_role() = 'dispatcher');
-- Driver sees shipments on their active trips
CREATE POLICY shipments_driver_assigned ON shipments
  FOR SELECT USING (
    auth_role() = 'driver' AND
    EXISTS (
      SELECT 1 FROM trip_shipments ts
      JOIN trips t ON ts.trip_id = t.trip_id
      WHERE ts.shipment_id = shipments.shipment_id
        AND t.driver_id = auth.uid()
    )
  );
-- Customer sees own shipments only
CREATE POLICY shipments_customer_own ON shipments
  FOR SELECT USING (
    auth_role() = 'customer' AND
    sender_id = auth.uid()
  );
CREATE POLICY shipments_customer_insert ON shipments
  FOR INSERT WITH CHECK (
    auth_role() = 'customer' AND
    sender_id = auth.uid()
  );

-- ============================================================
-- packages
-- ============================================================
CREATE POLICY packages_admin_all ON packages USING (auth_role() = 'admin');
CREATE POLICY packages_dispatcher_all ON packages USING (auth_role() = 'dispatcher');
CREATE POLICY packages_driver_read ON packages
  FOR SELECT USING (
    auth_role() = 'driver' AND
    EXISTS (
      SELECT 1 FROM trip_shipments ts
      JOIN trips t ON ts.trip_id = t.trip_id
      WHERE ts.shipment_id = packages.shipment_id AND t.driver_id = auth.uid()
    )
  );
CREATE POLICY packages_customer_own ON packages
  FOR SELECT USING (
    auth_role() = 'customer' AND
    EXISTS (SELECT 1 FROM shipments s WHERE s.shipment_id = packages.shipment_id AND s.sender_id = auth.uid())
  );
CREATE POLICY packages_customer_insert ON packages
  FOR INSERT WITH CHECK (
    auth_role() = 'customer' AND
    EXISTS (SELECT 1 FROM shipments s WHERE s.shipment_id = packages.shipment_id AND s.sender_id = auth.uid())
  );

-- ============================================================
-- trips
-- ============================================================
CREATE POLICY trips_admin_all ON trips USING (auth_role() = 'admin');
CREATE POLICY trips_dispatcher_crud ON trips USING (auth_role() = 'dispatcher');
CREATE POLICY trips_driver_own ON trips
  USING (auth_role() = 'driver' AND driver_id = auth.uid());

-- ============================================================
-- trip_shipments
-- ============================================================
CREATE POLICY trip_shipments_admin_all ON trip_shipments USING (auth_role() = 'admin');
CREATE POLICY trip_shipments_dispatcher ON trip_shipments USING (auth_role() = 'dispatcher');
CREATE POLICY trip_shipments_driver ON trip_shipments
  FOR SELECT USING (
    auth_role() = 'driver' AND
    EXISTS (SELECT 1 FROM trips t WHERE t.trip_id = trip_shipments.trip_id AND t.driver_id = auth.uid())
  );

-- ============================================================
-- tracking_events (immutable: no update/delete for anyone)
-- ============================================================
CREATE POLICY tracking_events_admin_all ON tracking_events
  USING (auth_role() = 'admin');
CREATE POLICY tracking_events_dispatcher_read ON tracking_events
  FOR SELECT USING (auth_role() = 'dispatcher');
-- Dispatcher can insert
CREATE POLICY tracking_events_dispatcher_insert ON tracking_events
  FOR INSERT WITH CHECK (auth_role() IN ('dispatcher', 'admin'));
-- Driver: insert only for their assigned shipments
CREATE POLICY tracking_events_driver_insert ON tracking_events
  FOR INSERT WITH CHECK (
    auth_role() = 'driver' AND
    EXISTS (
      SELECT 1 FROM trip_shipments ts
      JOIN trips t ON ts.trip_id = t.trip_id
      WHERE ts.shipment_id = tracking_events.shipment_id AND t.driver_id = auth.uid()
    )
  );
-- Driver: read own assigned shipments
CREATE POLICY tracking_events_driver_read ON tracking_events
  FOR SELECT USING (
    auth_role() = 'driver' AND
    EXISTS (
      SELECT 1 FROM trip_shipments ts
      JOIN trips t ON ts.trip_id = t.trip_id
      WHERE ts.shipment_id = tracking_events.shipment_id AND t.driver_id = auth.uid()
    )
  );
-- Customer: read own shipments events
CREATE POLICY tracking_events_customer_read ON tracking_events
  FOR SELECT USING (
    auth_role() = 'customer' AND
    EXISTS (
      SELECT 1 FROM shipments s
      WHERE s.shipment_id = tracking_events.shipment_id AND s.sender_id = auth.uid()
    )
  );

-- ============================================================
-- location_pings
-- ============================================================
CREATE POLICY location_pings_admin_all ON location_pings USING (auth_role() = 'admin');
CREATE POLICY location_pings_dispatcher_read ON location_pings
  FOR SELECT USING (auth_role() = 'dispatcher');
CREATE POLICY location_pings_driver_insert ON location_pings
  FOR INSERT WITH CHECK (
    auth_role() = 'driver' AND vehicle_id IN (
      SELECT vehicle_id FROM trips WHERE driver_id = auth.uid() AND status = 'ONGOING'
    )
  );
CREATE POLICY location_pings_driver_read ON location_pings
  FOR SELECT USING (
    auth_role() = 'driver' AND vehicle_id IN (
      SELECT vehicle_id FROM trips WHERE driver_id = auth.uid()
    )
  );
-- Customer can only see pings for their active shipment's vehicle
CREATE POLICY location_pings_customer_read ON location_pings
  FOR SELECT USING (
    auth_role() = 'customer' AND
    trip_id IN (
      SELECT ts.trip_id FROM trip_shipments ts
      JOIN shipments s ON ts.shipment_id = s.shipment_id
      WHERE s.sender_id = auth.uid()
    )
  );

-- ============================================================
-- delivery_proofs
-- ============================================================
CREATE POLICY delivery_proofs_admin_all ON delivery_proofs USING (auth_role() = 'admin');
CREATE POLICY delivery_proofs_dispatcher_read ON delivery_proofs
  FOR SELECT USING (auth_role() = 'dispatcher');
CREATE POLICY delivery_proofs_driver_insert ON delivery_proofs
  FOR INSERT WITH CHECK (auth_role() = 'driver');
CREATE POLICY delivery_proofs_customer_own ON delivery_proofs
  FOR SELECT USING (
    auth_role() = 'customer' AND
    EXISTS (
      SELECT 1 FROM shipments s
      WHERE s.shipment_id = delivery_proofs.shipment_id AND s.sender_id = auth.uid()
    )
  );

-- ============================================================
-- invoices
-- ============================================================
CREATE POLICY invoices_admin_all ON invoices USING (auth_role() = 'admin');
CREATE POLICY invoices_dispatcher_read ON invoices
  FOR SELECT USING (auth_role() = 'dispatcher');
CREATE POLICY invoices_customer_own ON invoices
  FOR SELECT USING (
    auth_role() = 'customer' AND
    EXISTS (
      SELECT 1 FROM shipments s
      WHERE s.shipment_id = invoices.shipment_id AND s.sender_id = auth.uid()
    )
  );

-- ============================================================
-- notifications
-- ============================================================
CREATE POLICY notifications_admin_all ON notifications USING (auth_role() = 'admin');
CREATE POLICY notifications_own ON notifications
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

-- ============================================================
-- status_transitions and pricing_rules (read-only for all auth)
-- ============================================================
CREATE POLICY status_transitions_read ON status_transitions
  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY status_transitions_admin ON status_transitions
  USING (auth_role() = 'admin');
CREATE POLICY pricing_rules_read ON pricing_rules
  FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY pricing_rules_admin ON pricing_rules
  USING (auth_role() = 'admin');


-- ============================================================
-- STORAGE: delivery-proofs bucket
-- Drivers upload proof photos; customers read their own
-- ============================================================

-- Create the bucket (run via Supabase client, not raw SQL, but we doc it here)
-- In Supabase dashboard: Storage > New bucket > delivery-proofs > Private

-- Storage policies (applied via Supabase Storage RLS)
-- These are reference policies; apply them in the Supabase Storage dashboard
-- or via the management API.

-- Policy: Drivers can upload to their own folder
-- USING: (bucket_id = 'delivery-proofs' AND auth.role() = 'authenticated')
-- WITH CHECK: auth_role() = 'driver'

-- Policy: Customers can read proofs for their own shipments  
-- This requires a join which is handled by the application layer
-- using a signed URL generated server-side.

-- Storage helper function: generate signed URL for proof
CREATE OR REPLACE FUNCTION get_proof_url(p_shipment_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_photo_url TEXT;
  v_sender_id UUID;
BEGIN
  -- Check caller owns this shipment
  SELECT dp.photo_url, s.sender_id
  INTO v_photo_url, v_sender_id
  FROM delivery_proofs dp
  JOIN shipments s ON dp.shipment_id = s.shipment_id
  WHERE dp.shipment_id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Proof not found for shipment %', p_shipment_id;
  END IF;

  -- Only sender or admin/dispatcher may access
  IF auth_role() = 'customer' AND v_sender_id <> auth.uid() THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  RETURN v_photo_url;
END;
$$;


-- ============================================================
-- SEED DATA FOR RTLTS
-- Generates profiles, hubs, addresses, vehicles, shipments, etc.
-- ============================================================

-- 1. AUTH USERS & PROFILES
-- We will insert directly into auth.users. The handle_new_user trigger will create profiles.
-- We must then update the profiles to set roles.
DO $$
DECLARE
  v_admin_id UUID := gen_random_uuid();
  v_dispatch_id UUID := gen_random_uuid();
  v_driver1_id UUID := gen_random_uuid();
  v_customer1_id UUID := gen_random_uuid();
  i INT;
  v_uid UUID;
BEGIN
  -- Insert demo accounts
    INSERT INTO auth.users (id, email, raw_user_meta_data, encrypted_password, email_confirmed_at) VALUES
      (v_admin_id, 'admin@rtlts.in', '{"full_name": "Admin User"}', crypt('Admin@123', gen_salt('bf')), now()),
      (v_dispatch_id, 'dispatch@rtlts.in', '{"full_name": "Dispatcher One"}', crypt('Dispatch@123', gen_salt('bf')), now()),
      (v_driver1_id, 'driver1@rtlts.in', '{"full_name": "Driver One"}', crypt('Driver@123', gen_salt('bf')), now()),
      (v_customer1_id, 'customer1@rtlts.in', '{"full_name": "Customer One"}', crypt('Customer@123', gen_salt('bf')), now())
    ON CONFLICT (id) DO NOTHING;

  -- Update their roles
  UPDATE profiles SET role = 'admin' WHERE profile_id = v_admin_id;
  UPDATE profiles SET role = 'dispatcher' WHERE profile_id = v_dispatch_id;
  UPDATE profiles SET role = 'driver' WHERE profile_id = v_driver1_id;
  UPDATE profiles SET role = 'customer' WHERE profile_id = v_customer1_id;
  
  -- The trigger automatically inserted them into customers because role defaulted to customer.
  -- Delete the ones that are NOT customers.
  DELETE FROM customers WHERE customer_id IN (v_admin_id, v_dispatch_id, v_driver1_id);

  -- Insert subtypes
  INSERT INTO employees (employee_id, designation) VALUES (v_admin_id, 'ADMIN'), (v_dispatch_id, 'DISPATCHER');
  INSERT INTO drivers (driver_id, license_no, license_expiry, rating, total_deliveries, on_time_count) 
    VALUES (v_driver1_id, 'DL-IND-001', '2030-12-31', 4.8, 150, 145);
  INSERT INTO customers (customer_id, company_name, customer_type) VALUES (v_customer1_id, 'Demo Corp', 'BUSINESS') ON CONFLICT (customer_id) DO UPDATE SET company_name = EXCLUDED.company_name, customer_type = EXCLUDED.customer_type;

  -- Generate 9 more drivers
  FOR i IN 2..10 LOOP
    v_uid := gen_random_uuid();
    INSERT INTO auth.users (id, email, raw_user_meta_data, encrypted_password, email_confirmed_at) 
      VALUES (v_uid, 'driver' || i || '@rtlts.in', '{"full_name": "Driver ' || i || '"}', crypt('Driver@123', gen_salt('bf')), now())
      ON CONFLICT (id) DO NOTHING;
    UPDATE profiles SET role = 'driver' WHERE profile_id = v_uid;
    DELETE FROM customers WHERE customer_id = v_uid;
    INSERT INTO drivers (driver_id, license_no, license_expiry) VALUES (v_uid, 'DL-IND-00' || i, '2030-12-31');
  END LOOP;

  -- Generate 25 more customers
  FOR i IN 2..26 LOOP
    v_uid := gen_random_uuid();
    INSERT INTO auth.users (id, email, raw_user_meta_data, encrypted_password, email_confirmed_at) 
      VALUES (v_uid, 'customer' || i || '@rtlts.in', '{"full_name": "Customer ' || i || '"}', crypt('Customer@123', gen_salt('bf')), now())
      ON CONFLICT (id) DO NOTHING;
    UPDATE profiles SET role = 'customer' WHERE profile_id = v_uid;
    -- The trigger already inserted into customers, we don't need to insert again.
  END LOOP;

  -- Generate 2 more dispatchers
  FOR i IN 2..3 LOOP
    v_uid := gen_random_uuid();
    INSERT INTO auth.users (id, email, raw_user_meta_data, encrypted_password, email_confirmed_at) 
      VALUES (v_uid, 'dispatch' || i || '@rtlts.in', '{"full_name": "Dispatcher ' || i || '"}', crypt('Dispatch@123', gen_salt('bf')), now())
      ON CONFLICT (id) DO NOTHING;
    UPDATE profiles SET role = 'dispatcher' WHERE profile_id = v_uid;
    DELETE FROM customers WHERE customer_id = v_uid;
    INSERT INTO employees (employee_id, designation) VALUES (v_uid, 'DISPATCHER');
  END LOOP;
END $$;

-- 2. HUBS & ADDRESSES
DO $$
DECLARE
  v_cities TEXT[] := ARRAY['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Kolkata', 'Hyderabad', 'Pune', 'Coimbatore'];
  v_lats NUMERIC[] := ARRAY[19.0760, 28.7041, 12.9716, 13.0827, 22.5726, 17.3850, 18.5204, 11.0168];
  v_lngs NUMERIC[] := ARRAY[72.8777, 77.1025, 77.5946, 80.2707, 88.3639, 78.4867, 73.8567, 76.9558];
  i INT;
  v_addr_id UUID;
BEGIN
  FOR i IN 1..8 LOOP
    v_addr_id := gen_random_uuid();
    INSERT INTO addresses (address_id, line1, city, state, postal_code, lat, lng)
      VALUES (v_addr_id, 'Hub Road ' || i, v_cities[i], 'State', '10000' || i, v_lats[i], v_lngs[i]);
    INSERT INTO hubs (name, address_id, capacity) VALUES (v_cities[i] || ' Central Hub', v_addr_id, 10000);
  END LOOP;
END $$;

-- 3. VEHICLES
DO $$
DECLARE
  v_hub_ids UUID[];
  i INT;
BEGIN
  SELECT array_agg(hub_id) INTO v_hub_ids FROM hubs;
  FOR i IN 1..15 LOOP
    INSERT INTO vehicles (plate_no, type, capacity_kg, home_hub_id)
      VALUES ('MH-12-TR-' || (1000+i), 'Truck', 5000, v_hub_ids[1 + (i % 8)]);
  END LOOP;
END $$;

-- 4. ROUTES & STOPS
DO $$
DECLARE
  v_hub_ids UUID[];
  v_route_id UUID;
  i INT;
BEGIN
  SELECT array_agg(hub_id) INTO v_hub_ids FROM hubs;
  FOR i IN 1..10 LOOP
    v_route_id := gen_random_uuid();
    INSERT INTO routes (route_id, name, origin_hub_id, destination_hub_id, distance_km)
      VALUES (v_route_id, 'Route ' || i, v_hub_ids[1 + (i % 8)], v_hub_ids[1 + ((i+1) % 8)], 500 + (i * 50));
    -- Stops
    INSERT INTO route_stops (route_id, stop_no, hub_id, expected_minutes) VALUES 
      (v_route_id, 1, v_hub_ids[1 + (i % 8)], 0),
      (v_route_id, 2, v_hub_ids[1 + ((i+1) % 8)], 600);
  END LOOP;
END $$;

-- 5. SHIPMENTS & PACKAGES (120 shipments)
DO $$
DECLARE
  v_customer_ids UUID[];
  v_sender_id UUID;
  v_origin_addr UUID;
  v_dest_addr UUID;
  v_shipment_id UUID;
  v_statuses shipment_status[] := ARRAY['CREATED', 'PICKED_UP', 'IN_TRANSIT', 'AT_HUB', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED_ATTEMPT']::shipment_status[];
  i INT;
BEGIN
  SELECT array_agg(customer_id) INTO v_customer_ids FROM customers;
  
  FOR i IN 1..120 LOOP
    v_sender_id := v_customer_ids[1 + (i % array_length(v_customer_ids, 1))];
    
    -- Create random addresses for shipments
    v_origin_addr := gen_random_uuid();
    v_dest_addr := gen_random_uuid();
    
    INSERT INTO addresses (address_id, line1, city, state, postal_code, lat, lng) VALUES 
      (v_origin_addr, 'Sender Addr ' || i, 'City A', 'State', '111111', 20.0 + (random()*5), 75.0 + (random()*5)),
      (v_dest_addr, 'Receiver Addr ' || i, 'City B', 'State', '222222', 20.0 + (random()*5), 75.0 + (random()*5));
      
    v_shipment_id := gen_random_uuid();
    -- Need to bypass triggers or just let trigger handle it
    -- The trigger 'generate_tracking_no' will auto-fill tracking_no
    -- But we need to insert the row
    INSERT INTO shipments (shipment_id, tracking_no, sender_id, receiver_name, receiver_phone, origin_addr_id, dest_addr_id, service_type, status, charge, eta)
      VALUES (v_shipment_id, 'TMP-'||i, v_sender_id, 'Receiver ' || i, '9999999999', v_origin_addr, v_dest_addr, 'STANDARD', v_statuses[1 + (i % 7)], 150.00, now() + interval '3 days');
      
    -- Packages
    INSERT INTO packages (shipment_id, description, weight_kg) VALUES (v_shipment_id, 'Box ' || i, 10 + (random() * 20));
  END LOOP;
END $$;

-- 6. TRIPS & EVENTS (Simulate some active trips)
DO $$
DECLARE
  v_driver_ids UUID[];
  v_vehicle_ids UUID[];
  v_route_ids UUID[];
  v_trip_id UUID;
  v_shipment_ids UUID[];
  i INT;
  j INT;
BEGIN
  SELECT array_agg(driver_id) INTO v_driver_ids FROM drivers;
  SELECT array_agg(vehicle_id) INTO v_vehicle_ids FROM vehicles;
  SELECT array_agg(route_id) INTO v_route_ids FROM routes;
  SELECT array_agg(shipment_id) INTO v_shipment_ids FROM shipments WHERE status = 'IN_TRANSIT' LIMIT 30;

  FOR i IN 1..5 LOOP
    v_trip_id := gen_random_uuid();
    INSERT INTO trips (trip_id, driver_id, vehicle_id, route_id, status, planned_start, actual_start)
      VALUES (v_trip_id, v_driver_ids[i], v_vehicle_ids[i], v_route_ids[i], 'ONGOING', now() - interval '1 day', now() - interval '1 day');
      
    -- Add 5 shipments per trip
    FOR j IN 1..5 LOOP
      IF (i-1)*5 + j <= array_length(v_shipment_ids, 1) THEN
        INSERT INTO trip_shipments (trip_id, shipment_id, sequence_no) VALUES (v_trip_id, v_shipment_ids[(i-1)*5 + j], j);
      END IF;
    END LOOP;
    
    -- Generate some location pings for the ongoing trips
    FOR j IN 1..100 LOOP
      INSERT INTO location_pings (vehicle_id, trip_id, lat, lng, speed_kmph, recorded_at)
        VALUES (v_vehicle_ids[i], v_trip_id, 20.0 + (random()*2), 75.0 + (random()*2), 60 + (random()*20), now() - ((100-j) * interval '5 minutes'));
    END LOOP;
  END LOOP;
END $$;
