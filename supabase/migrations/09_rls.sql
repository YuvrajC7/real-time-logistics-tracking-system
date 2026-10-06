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
