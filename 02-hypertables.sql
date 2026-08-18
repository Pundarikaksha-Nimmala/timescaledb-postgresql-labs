-- ===========================================
-- TimescaleDB Hypertables
-- ===========================================

------------------------------------------------
-- Create Table
------------------------------------------------

CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    device_id INT,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION
);

------------------------------------------------
-- Convert to Hypertable
------------------------------------------------

SELECT create_hypertable(
    'sensor_data',
    by_range('time')
);

------------------------------------------------
-- Verify Hypertable
------------------------------------------------

SELECT *
FROM timescaledb_information.hypertables;

------------------------------------------------
-- View Chunks
------------------------------------------------

SELECT *
FROM timescaledb_information.chunks;

------------------------------------------------
-- Chunk Pruning (Recent Data)
------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM sensor_data
WHERE time >= NOW() - INTERVAL '2 days';

------------------------------------------------
-- Query Across Multiple Chunks
------------------------------------------------

EXPLAIN ANALYZE
SELECT *
FROM sensor_data
WHERE time >= NOW() - INTERVAL '60 days';
