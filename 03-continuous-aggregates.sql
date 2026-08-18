-- ===========================================
-- Continuous Aggregates
-- ===========================================

------------------------------------------------
-- Query Raw Hypertable
------------------------------------------------

SELECT
    time_bucket('1 hour', time) AS bucket,
    COUNT(*) AS readings,
    AVG(temperature) AS avg_temperature,
    MIN(temperature) AS min_temperature,
    MAX(temperature) AS max_temperature
FROM sensor_data
GROUP BY bucket
ORDER BY bucket DESC;

------------------------------------------------
-- Create Continuous Aggregate
------------------------------------------------

CREATE MATERIALIZED VIEW sensor_hour_summary
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    COUNT(*) AS readings,
    AVG(temperature) AS avg_temperature,
    MIN(temperature) AS min_temperature,
    MAX(temperature) AS max_temperature
FROM sensor_data
GROUP BY bucket;

------------------------------------------------
-- Query Continuous Aggregate
------------------------------------------------

SELECT *
FROM sensor_hour_summary
ORDER BY bucket DESC
LIMIT 10;

------------------------------------------------
-- Add Refresh Policy
------------------------------------------------

SELECT add_continuous_aggregate_policy(
    'sensor_hour_summary',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '15 minutes'
);

------------------------------------------------
-- View Continuous Aggregates
------------------------------------------------

SELECT *
FROM timescaledb_information.continuous_aggregates;
