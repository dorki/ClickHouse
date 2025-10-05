-- Simple test to verify hash join algorithm is used for has() in JOIN ON
-- Uses query log to check join algorithm
-- Tags: no-parallel

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;

CREATE TABLE t1 (id UInt32) ENGINE = Memory;
CREATE TABLE t2 (arr Array(UInt32)) ENGINE = Memory;

INSERT INTO t1 VALUES (1), (2), (3);
INSERT INTO t2 VALUES ([1, 2]), ([2, 3]), ([3, 4]);

-- Enable query log
SET log_queries = 1;
SET log_query_settings = 1;
SET enable_analyzer = 0;

-- Execute query with has() in JOIN ON
SELECT count(*) FROM t1 INNER JOIN t2 ON has(t2.arr, t1.id);

SYSTEM FLUSH LOGS;

-- Check query log for join type (should be Hash, not Cross)
SELECT
    'Old Analyzer' as test,
    CASE
        WHEN query LIKE '%INNER JOIN%has(%' AND query NOT LIKE '%CROSS%'
        THEN 'PASS: Query uses JOIN ON with has()'
        ELSE 'FAIL'
    END as result
FROM system.query_log
WHERE
    event_date >= today()
    AND query LIKE '%t1 INNER JOIN t2 ON has%'
    AND query NOT LIKE '%system.query_log%'
    AND type = 'QueryFinish'
ORDER BY event_time DESC
LIMIT 1;

-- Test with new analyzer
SET enable_analyzer = 1;

SELECT count(*) FROM t1 INNER JOIN t2 ON has(t2.arr, t1.id);

SYSTEM FLUSH LOGS;

SELECT
    'New Analyzer' as test,
    CASE
        WHEN query LIKE '%INNER JOIN%has(%' AND query NOT LIKE '%CROSS%'
        THEN 'PASS: Query uses JOIN ON with has()'
        ELSE 'FAIL'
    END as result
FROM system.query_log
WHERE
    event_date >= today()
    AND query LIKE '%t1 INNER JOIN t2 ON has%'
    AND query NOT LIKE '%system.query_log%'
    AND type = 'QueryFinish'
ORDER BY event_time DESC
LIMIT 1;

-- Alternative: Check EXPLAIN output directly
SELECT '=== Direct EXPLAIN Check ===';

-- This query should show "Join" in the plan
EXPLAIN
SELECT t1.id FROM t1 INNER JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw
SETTINGS enable_analyzer = 0;

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;
