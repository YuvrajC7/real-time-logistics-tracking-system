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
