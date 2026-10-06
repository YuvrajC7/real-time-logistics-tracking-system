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
