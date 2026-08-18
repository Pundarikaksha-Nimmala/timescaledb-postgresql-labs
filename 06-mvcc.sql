-- ===========================================
-- MVCC Demonstration
-- ===========================================

------------------------------------------------
-- Create Table
------------------------------------------------

CREATE TABLE mvcc_demo (
    id SERIAL PRIMARY KEY,
    name TEXT
);

------------------------------------------------
-- Insert Data
------------------------------------------------

INSERT INTO mvcc_demo(name)
SELECT 'Employee'
FROM generate_series(1,20000);

------------------------------------------------
-- Update Data
------------------------------------------------

UPDATE mvcc_demo
SET name = name || ' Updated';

------------------------------------------------
-- Dead Tuples
------------------------------------------------

SELECT
    relname,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
WHERE relname='mvcc_demo';

------------------------------------------------
-- Vacuum Analyze
------------------------------------------------

VACUUM ANALYZE mvcc_demo;

------------------------------------------------
-- Table Size
------------------------------------------------

SELECT
    pg_size_pretty(pg_relation_size('mvcc_demo'));

------------------------------------------------
-- MVCC Statistics
------------------------------------------------

SELECT
    relname,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_live_tup,
    n_dead_tup,
    vacuum_count,
    autovacuum_count,
    analyze_count,
    autoanalyze_count
FROM pg_stat_user_tables
WHERE relname='mvcc_demo';
