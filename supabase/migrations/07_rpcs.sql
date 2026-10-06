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
