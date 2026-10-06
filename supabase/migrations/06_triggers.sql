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
