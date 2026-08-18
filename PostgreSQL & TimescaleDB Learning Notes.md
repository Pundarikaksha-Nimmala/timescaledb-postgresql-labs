Why does TimescaleDB use PostgreSQL instead of building an entirely new database?
BIGSERIAL automatically generates unique values using an underlying sequence, avoiding the need to manually assign IDs.
TIMESTAMPTZ stores timestamps with time zone awareness, helping avoid issues when users or services operate in different time zones.
B-Tree: Instead of checking every row, PostgreSQL traverses the tree, which is much faster for large datasets.
PostgreSQL doesn't always use an index. It uses the plan with the lowest estimated cost.
PostgreSQL stores statistics (row counts, value distribution, etc.) to make planning decisions. After inserting a large amount of data, we run ANALYZE so the planner has accurate information.

Why does PostgreSQL sometimes use an Index Scan and other times a Bitmap Heap Scan?
Because the query returns many rows. A regular Index Scan would require many random heap lookups. PostgreSQL instead performs a Bitmap Index Scan to collect matching row locations, builds a bitmap of heap pages, and then reads those pages sequentially, reducing random I/O.


Why does PostgreSQL "recheck" if the index already found the rows?
Because a Bitmap Heap Scan stores page information, not complete row contents.
When PostgreSQL reads each heap page, it verifies that each returned row still satisfies:

Q1. Why Bitmap Heap Scan?
Because approximately 10% of the table matched the condition.
Too many rows for a simple Index Scan.
Too few rows for a full Sequential Scan.
Bitmap scanning is the middle ground.
Q2. What is a Heap?
Heap is PostgreSQL's term for the table's data pages where rows are physically stored.
Q3. Why run ANALYZE?
To update planner statistics so PostgreSQL can estimate row counts accurately and choose efficient execution plans.
Q4. Does creating an index guarantee PostgreSQL will use it?
No.
PostgreSQL's cost-based optimizer chooses the plan with the lowest estimated cost. Depending on table size and query selectivity, it may choose a Sequential Scan, Index Scan, or 

Bitmap Heap Scan.
Index
↓
Collect all matches
↓
Group by page
↓
Read pages once

Index Scan
Index
↓
Heap
↓
Index
↓
Heap
↓
Index
↓
Heap

What's the difference between an Index Scan and a Bitmap Heap Scan?
An Index Scan follows the index and fetches each matching row from the table immediately, which can lead to many random heap accesses. A Bitmap Heap Scan first performs a Bitmap Index Scan to identify all matching row locations, builds a bitmap of the heap pages that contain those rows, and then reads those pages efficiently, reducing random I/O when many rows match.

                Query
                  │
                  ▼
        How many rows match?
                  │
     ┌────────────┼────────────┐
     │            │            │
     ▼            ▼            ▼
 Very Few      Moderate      Most Rows
 (1–100)      (~1–20%)       (>30–50%)
     │            │            │
     ▼            ▼            ▼
 Index Scan   Bitmap Scan   Seq Scan
 
 There is a special scan type called an Index Only Scan, where PostgreSQL can answer the query using only the index without touching the table, provided certain conditions are met (such as the visibility map indicating the pages are safe).
 
When can PostgreSQL perform an Index Only Scan?
PostgreSQL can use an Index Only Scan when all the columns required by the query are available in the index, and the visibility map indicates that the relevant heap pages are all-visible, allowing PostgreSQL to avoid checking the table.

Why did PostgreSQL stop using Index Only Scan after selecting driver_id?
Because driver_id is not part of the idx_rides_fare index. PostgreSQL could use the index to locate matching rows, but it still had to access the heap to retrieve driver_id, so an Index Only Scan was no longer possible.

i created
CREATE INDEX idx
ON orders(customer_id, order_date);
Will it help this query?
SELECT *
FROM orders
WHERE order_date > CURRENT_DATE - 30;
No. The index is ordered by customer_id first. Since the query doesn't filter on the leading column, PostgreSQL generally can't efficiently use this composite index and will often choose a sequential scan.

create hyper table
SELECT create_hypertable(
    'sensor_data',
    by_range('time')
);

INSERT INTO sensor_data
SELECT
    now() - (g * interval '1 minute'),
    (random()*10)::int,
    random()*40,
    random()*100
FROM generate_series(1,100000) g;

SELECT * FROM timescaledb_information.hypertables;
SELECT * FROM timescaledb_information.chunks;

What is Chunk Pruning?
Chunk pruning is an optimization where TimescaleDB examines the query's time predicate and excludes chunks whose time ranges cannot contain matching rows. This significantly reduces the amount of data scanned.

How does TimescaleDB improve query performance?
TimescaleDB stores time-series data in hypertables, which are automatically partitioned into time-based chunks. During query planning, it performs chunk pruning so only relevant chunks are scanned. Within each selected chunk, PostgreSQL's optimizer chooses the most efficient access method, such as an index scan, bitmap scan, or sequential scan.

What is time_bucket()?
time_bucket() groups timestamps into fixed time intervals such as 5 minutes, 1 hour, or 1 day. It's designed for time-series data and is optimized for TimescaleDB hypertables. It's commonly used with aggregate functions like AVG, COUNT, SUM, and is the foundation of continuous aggregates.

SELECT
    time_bucket('1 hour', time) AS hour,
    COUNT(*) AS readings,
    AVG(temperature),
    MAX(temperature),
    MIN(temperature)
FROM sensor_data
GROUP BY hour
ORDER BY hour DESC;

A customer says their Grafana dashboard is slow. What would you check?
Is the query using time_bucket() appropriately?
Is the dashboard querying raw hypertable data or a continuous aggregate?
Is chunk pruning occurring (time filter present)?
Are appropriate indexes available?
Is the selected time range unnecessarily large?
Are compression policies or retention policies affecting performance?

That shows you understand both PostgreSQL execution and TimescaleDB-specific optimizations.


A Continuous Aggregate is simply a precomputed summary table that TimescaleDB keeps automatically updated.

CREATE MATERIALIZED VIEW sensor_hourly_summary
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    COUNT(*) AS readings,
    AVG(temperature) AS avg_temperature,
    MIN(temperature) AS min_temperature,
    MAX(temperature) AS max_temperature
FROM sensor_data
GROUP BY bucket;

SELECT *
FROM sensor_hourly_summary
ORDER BY bucket DESC
LIMIT 10;

If TimescaleDB is updating the summary automatically, how does it know when to refresh?
The answer is: Refresh Policies.

A continuous aggregate doesn't update after every insert by default. That would still be expensive.

Instead, a background job refreshes it on a schedule, for example:

Every minute
Every 5 minutes
Every hour

Do you expect the readings count in the latest bucket to increase immediately?
Most people answer Yes.
Not by default. New data is written to the hypertable immediately, while the continuous aggregate is refreshed according to its refresh policy (or manually via refresh_continuous_aggregate). This avoids the overhead of recomputing aggregates on every insert.

Refresh:
CALL refresh_continuous_aggregate(
    'sensor_hourly_summary',
    NULL,
    NULL
);

Why are Continuous Aggregates faster than running GROUP BY on the hypertable?
Continuous Aggregates precompute and store aggregate values for historical buckets. On query, TimescaleDB reads the precomputed results and, if real-time aggregates are enabled, combines them with only the newest raw data that hasn't yet been materialized. This avoids scanning and aggregating the full hypertable every time.

Why does TimescaleDB compress better than PostgreSQL?
PostgreSQL stores data row-by-row. Hypercore stores older chunks in a columnar layout where similar values are adjacent. That makes algorithms like delta encoding, run-length encoding, XOR, and dictionary compression much more effective, often reducing storage dramatically

If some chunks are compressed and some are not, do applications need different SQL?
No. Applications always query the hypertable. TimescaleDB automatically reads compressed chunks using the columnstore engine and uncompressed chunks using the rowstore engine, then merges the results transparently.

ALTER TABLE sensor_data
SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT *
FROM sensor_data
WHERE device_id = 5;

SELECT *
FROM sensor_data
WHERE device_id = 5
ORDER BY time DESC
LIMIT 100;

Why choose device_id as segmentby?
Because queries often filter by device. Grouping compressed data by device_id reduces the amount of compressed data that needs to be scanned.

Why choose time DESC?
Most dashboards ask for recent data

For segment:
Choose a column that:
repeats often
is commonly filtered

Can I segment by multiple columns?
timescaledb.compress_segmentby =
'tenant_id,device_id'

SELECT compress_chunk('_timescaledb_internal._hyper_1_11_chunk');

SELECT
    chunk_name,
    is_compressed
FROM timescaledb_information.chunks
WHERE chunk_name = '_hyper_1_11_chunk';

SELECT *
FROM chunk_compression_stats('_timescaledb_internal._hyper_1_11_chunk');

Q1. Does compression affect inserts?
Answer:
No. New inserts always go to the newest uncompressed chunks. Compression is intended for older, relatively immutable chunks.

Q2. Can compressed chunks still be queried?
Answer:
Yes. Applications continue querying the hypertable. TimescaleDB transparently reads compressed and uncompressed chunks and combines the results.

Q3. Why compress only old chunks?
Answer:
Recent data receives frequent inserts and updates, making row storage more efficient. Historical data is mostly read-only, so compressing it reduces storage and often improves analytical query performance.

compression_policy:
SELECT add_compression_policy(
    'sensor_data',
    INTERVAL '30 days'
);

check policies:
SELECT *
FROM timescaledb_information.jobs;
SELECT *
FROM timescaledb_information.job_stats;


Q1. Why use policies instead of cron jobs?
Answer:
Policies are built into TimescaleDB, understand chunks and hypertables, run as background workers, and are more reliable and easier to manage than external cron scripts.

Q2. Why not delete rows manually?
Answer:
Deleting millions of rows is slow and creates table bloat. Retention policies drop entire chunks, which is much faster.

Q3. Why refresh continuous aggregates periodically?
Answer:
To keep summaries up to date without recalculating every query.

Q4. What background jobs exist in TimescaleDB?

Expected answer:

Compression
Continuous Aggregate Refresh
Retention
Reorder (older versions)
Other maintenance jobs

best insert method instead of normal inserts:
COPY sensor_data
FROM '/tmp/sensor.csv'
CSV HEADER;

Why is PostgreSQL durable?
Because every change is written to the Write-Ahead Log before it's considered committed.

Q1. Why is COPY faster than INSERT?
Expected answer:
Less SQL parsing
Fewer commits
Streaming data
Reduced network overhead

Q2. Why do many indexes reduce insert performance?
Because every inserted row must also be inserted into each index.

Q3. What is WAL? (Write-Ahead Log)
A sequential log that records changes before they're written to the data files, enabling crash recovery and durability.

Q4. A customer says inserts slowed after adding five indexes. Why?
Because each insert now has to maintain five additional index structures, increasing write cost.

Q1. Why doesn't PostgreSQL overwrite rows?
Answer: Because of MVCC. Updates create new row versions so readers and writers don't block each other.

Q2. What is a dead tuple?
Answer: An obsolete row version that is no longer visible to any active transaction.

Q3. Why do dead tuples hurt performance?
Answer: They increase table size and force scans to process more pages, causing table bloat.

Q4. Difference between VACUUM and VACUUM FULL?
VACUUM	VACUUM FULL
Removes dead tuples	Rewrites the entire table
Reuses space internally	Returns space to the OS
Doesn't require an exclusive table rewrite	Takes an exclusive lock
Safe for routine use	Usually reserved for special cases

Q5. What does Autovacuum do?
It automatically vacuums and analyzes tables based on configurable thresholds, preventing excessive bloat and keeping planner statistics current.

Check dead tuples:
SELECT
relname,
n_live_tup,
n_dead_tup
FROM pg_stat_user_tables
WHERE relname='mvcc_demo';


table size check:
SELECT pg_size_pretty(pg_relation_size('mvcc_demo'));

diagnostic qury for dead tuples and autovaccum

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
WHERE relname = 'mvcc_demo';

To check locks on tables:
SELECT
    pid,
    usename,
    state,
    wait_event_type,
    wait_event,
    query
FROM pg_stat_activity
WHERE datname = current_database();

Why PostgreSQL waits instead of failing?
Because of MVCC.
If PostgreSQL allowed both updates simultaneously:
1000 +100 =1100
1000 -100 =900
One update would overwrite the other.
This is called a lost update, and PostgreSQL prevents it by locking the row (more precisely, by waiting on the transaction that last modified it).

blocked by:
SELECT
    pid,
    pg_blocking_pids(pid) AS blocked_by,
    query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;

Topic	What it answers	Real-world use case
EXPLAIN ANALYZE	How is this query executed?	Query optimization, slow SQL
pg_stat_activity	What is running now?	Find blocked, idle, or long-running queries
pg_stat_statements	Which queries are expensive overall?	Identify top resource-consuming SQL
pg_locks	Who owns or waits for locks?	Debug lock contention and deadlocks
VACUUM / Autovacuum	How are dead tuples cleaned up?	Prevent table/index bloat and maintain performance
WAL / Replication	How are changes logged and replicated?	High availability, replicas, crash recovery
Query Planner Statistics	Why did the planner choose this plan?	Fix bad execution plans with updated statistics
Backup / Recovery	How can data be restored after failures?	Disaster recovery, migrations, accidental data deletion


Concept	Purpose
Row storage	Best for frequent INSERT/UPDATE/DELETE
Columnstore	Best for analytics and historical data
Compression policy	Automatically compress old chunks
compress_chunk()	Compress a specific chunk manually
compress_after	Age threshold before compression
Segment By (legacy)	Group similar rows together
Order By (legacy)	Improve compression ratio within groups
Retention policy	Remove very old compressed data

Function	Purpose	Example Use Case
ROW_NUMBER()	Unique numbering	Latest row per device, deduplication
RANK()	Competition ranking (gaps after ties)	Leaderboards
DENSE_RANK()	Ranking without gaps	Top N distinct values
LAG()	Previous row	Compare with previous sensor reading
LEAD()	Next row	Predict or compare with next event
SUM() OVER	Running total	Revenue over time
AVG() OVER	Average without collapsing rows	Compare employee to department average
COUNT() OVER	Count per partition	Number of rides per driver
MIN()/MAX() OVER	Partition minimum/maximum	Highest fare per driver
FIRST_VALUE()	First value in ordered partition	First reading or highest salary
LAST_VALUE()	Last value in ordered partition	Latest or lowest value (with proper frame)
NTILE()	Split into buckets	Quartiles, percentiles
What Tiger Data is most likely to ask

For a TimescaleDB Support Engineer role, I'd prioritize these in order:

✅ ROW_NUMBER() – latest row per device
✅ LAG() – compare current vs previous sensor reading
✅ SUM() OVER – running totals
✅ AVG() OVER – per-device or per-department averages
✅ RANK() / DENSE_RANK() – top-N analytics

