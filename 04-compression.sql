-- ===========================================
-- Columnstore Compression
-- ===========================================

------------------------------------------------
-- Enable Compression
------------------------------------------------

ALTER TABLE sensor_data
SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

------------------------------------------------
-- Verify Compression Enabled
------------------------------------------------

SELECT hypertable_name,
       compression_enabled
FROM timescaledb_information.hypertables;

------------------------------------------------
-- Add Compression Policy
------------------------------------------------

SELECT add_compression_policy(
    'sensor_data',
    INTERVAL '30 days'
);

------------------------------------------------
-- Compress a Chunk
------------------------------------------------

SELECT compress_chunk(
'_timescaledb_internal._hyper_1_11_chunk'
);

------------------------------------------------
-- Verify Compressed Chunk
------------------------------------------------

SELECT
    chunk_name,
    is_compressed
FROM timescaledb_information.chunks;

------------------------------------------------
-- Compression Statistics
------------------------------------------------

SELECT *
FROM hypertable_compression_stats('sensor_data');
