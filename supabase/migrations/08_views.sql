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
