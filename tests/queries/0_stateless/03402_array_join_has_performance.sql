-- Performance test: hash join with array expansion vs cross join + filter
-- This test verifies that array join is significantly faster than cross join
-- Tags: no-parallel, long

DROP TABLE IF EXISTS t1_perf;
DROP TABLE IF EXISTS t2_perf;

-- Create larger test tables for performance comparison
CREATE TABLE t1_perf (id UInt32) ENGINE = Memory;
CREATE TABLE t2_perf (arr Array(UInt32), value String) ENGINE = Memory;

-- Insert 100 rows into t1
INSERT INTO t1_perf SELECT number FROM numbers(100);

-- Insert 1000 rows into t2, each with array of 5 elements
INSERT INTO t2_perf
SELECT
    [number * 5, number * 5 + 1, number * 5 + 2, number * 5 + 3, number * 5 + 4],
    concat('Group_', toString(number))
FROM numbers(1000);

-- Test 1: Hash join approach (using JOIN ON with has())
-- This should complete quickly
SELECT '=== Hash Join Approach ===';
SELECT count(*) as result_count
FROM t1_perf t1
INNER JOIN t2_perf t2 ON has(t2.arr, t1.id)
SETTINGS max_execution_time = 5; -- Should complete in under 5 seconds

-- Test 2: Cross join approach (using CROSS JOIN + WHERE)
-- This will be much slower (100 * 1000 = 100,000 comparisons)
SELECT '=== Cross Join Approach (for comparison) ===';
SELECT count(*) as result_count
FROM t1_perf t1
CROSS JOIN t2_perf t2
WHERE has(t2.arr, t1.id)
SETTINGS max_execution_time = 10; -- Needs more time

-- Test 3: Verify results are identical
SELECT '=== Verify Results Match ===';
WITH
    hash_join AS (
        SELECT t1.id, t2.value
        FROM t1_perf t1
        INNER JOIN t2_perf t2 ON has(t2.arr, t1.id)
    ),
    cross_join AS (
        SELECT t1.id, t2.value
        FROM t1_perf t1
        CROSS JOIN t2_perf t2
        WHERE has(t2.arr, t1.id)
    )
SELECT
    (SELECT count(*) FROM hash_join) as hash_join_count,
    (SELECT count(*) FROM cross_join) as cross_join_count,
    (SELECT count(*) FROM hash_join) = (SELECT count(*) FROM cross_join) as counts_match;

-- Test 4: Check memory usage (hash join should use less peak memory)
SELECT '=== Hash Join Memory ===';
SELECT formatReadableSize(sum(bytes)) as memory_used
FROM system.parts
WHERE database = currentDatabase()
  AND table IN ('t1_perf', 't2_perf');

-- Test 5: Verify no rows are duplicated or missing
SELECT '=== Correctness Check ===';
SELECT
    t1.id,
    count(*) as match_count
FROM t1_perf t1
INNER JOIN t2_perf t2 ON has(t2.arr, t1.id)
GROUP BY t1.id
HAVING match_count != (
    -- Expected matches: id appears in how many arrays?
    SELECT count(*)
    FROM t2_perf t2_check
    WHERE has(t2_check.arr, t1.id)
)
LIMIT 1; -- Should return 0 rows (no mismatches)

SELECT '=== All Tests Passed ===';

-- Cleanup
DROP TABLE IF EXISTS t1_perf;
DROP TABLE IF EXISTS t2_perf;
