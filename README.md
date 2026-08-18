# timescaledb-postgresql-labs
Interview-preparation-timescale-db
# TimescaleDB Hands-on Lab
This repository contains my hands-on exploration of PostgreSQL and TimescaleDB using Tiger Cloud.

## Topics Covered

- Hypertables
- Chunking and Chunk Pruning
- Index Scan vs Bitmap Heap Scan vs Index Only Scan
- EXPLAIN ANALYZE
- Continuous Aggregates
- Refresh Policies
- Compression (Columnstore)
- Compression Policies
- Retention Policies
- MVCC
- Lock Monitoring
- PostgreSQL Statistics
- Window Functions
- Common Table Expressions (CTEs)

## Environment

- PostgreSQL
- TimescaleDB 2.29
- Tiger Cloud

## What I Built

- Created hypertables from time-series data
- Configured automatic chunk creation
- Created hourly continuous aggregates
- Configured automatic refresh policies
- Enabled columnstore compression
- Applied compression and retention policies
- Compared query execution plans using EXPLAIN ANALYZE
- Explored PostgreSQL internals including MVCC, locks, and statistics views
