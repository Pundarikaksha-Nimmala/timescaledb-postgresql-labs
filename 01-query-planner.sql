-- ===========================================
-- PostgreSQL Query Planner & Indexes
-- ===========================================

------------------------------------------------
-- Create Indexes
------------------------------------------------

CREATE INDEX idx_rides_fare
ON rides(fare);

CREATE INDEX idx_driver_time
ON rides(driver_id, ride_time);

CREATE INDEX idx_ride_time
ON rides(ride_time);

------------------------------------------------
-- Sequential Scan
------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM rides
WHERE ride_time > NOW() - INTERVAL '30 days';

------------------------------------------------
-- Bitmap Heap Scan
------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM rides
WHERE driver_id = 100;

------------------------------------------------
-- Bitmap Heap Scan using Composite Index
------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM rides
WHERE driver_id = 100
AND ride_time > NOW() - INTERVAL '30 days';

------------------------------------------------
-- Index Only Scan
------------------------------------------------

EXPLAIN ANALYZE
SELECT fare, driver_id
FROM rides
WHERE fare > 990;
