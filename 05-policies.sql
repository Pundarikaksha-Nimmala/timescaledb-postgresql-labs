-- ===========================================
-- TimescaleDB Policies
-- ===========================================

------------------------------------------------
-- Retention Policy
------------------------------------------------

SELECT add_retention_policy(
    'sensor_data',
    INTERVAL '365 days'
);

------------------------------------------------
-- Background Jobs
------------------------------------------------

SELECT *
FROM timescaledb_information.jobs;

------------------------------------------------
-- Job Statistics
------------------------------------------------

SELECT *
FROM timescaledb_information.job_stats;
