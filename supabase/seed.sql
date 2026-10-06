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
