-- Large scale test for array join with hash/parallel_hash/grace_hash
SET parallel_replicas_local_plan=1;

DROP TABLE IF EXISTS t1_large;
DROP TABLE IF EXISTS t10_large;

-- Create tables with more data
CREATE TABLE t1_large (id UInt32, name String) ENGINE = Memory;
CREATE TABLE t10_large (arr Array(Nullable(UInt32)), value String, category UInt32) ENGINE = Memory;

-- Insert 1000 rows into t1_large (ids 1-1000)
INSERT INTO t1_large
SELECT
    number AS id,
    concat('User_', toString(number)) AS name
FROM numbers(1000);

-- Insert 200 rows into t10_large with arrays of varying sizes
-- Each array contains 1-10 elements that reference ids from t1_large
-- Some arrays have NULLs, some have duplicates, some have non-matching values
INSERT INTO t10_large
SELECT
    arrayMap(x -> if(x % 7 = 0, NULL, (number * 5 + x) % 1000), range(1 + (number % 10))) AS arr,
    concat('Value_', toString(number)) AS value,
    number % 5 AS category
FROM numbers(200);

-- Insert some specific test cases
INSERT INTO t10_large VALUES
    ([1, 2, 3, 4, 5], 'Sequential', 0),
    ([NULL, NULL, NULL], 'AllNulls', 1),
    ([999, 998, 997], 'HighIds', 2),
    ([1, 1, 1, 1], 'Duplicates', 3),
    ([500, NULL, 600, NULL, 700], 'MixedNulls', 4),
    ([1, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500], 'Sparse', 0);

-- Test 1: grace_hash with new analyzer
SELECT 'Test 1: grace_hash (new analyzer)';
SELECT count(*) AS match_count, countDistinct(t1_large.id) AS unique_ids
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
SETTINGS enable_analyzer = 1, join_algorithm='grace_hash';

-- Test 2: grace_hash with old analyzer
SELECT 'Test 2: grace_hash (old analyzer)';
SELECT count(*) AS match_count, countDistinct(t1_large.id) AS unique_ids
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
SETTINGS enable_analyzer = 0, join_algorithm='grace_hash';

-- Test 3: hash with new analyzer
SELECT 'Test 3: hash (new analyzer)';
SELECT count(*) AS match_count, countDistinct(t1_large.id) AS unique_ids
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
SETTINGS enable_analyzer = 1, join_algorithm='hash';

-- Test 4: hash with old analyzer
SELECT 'Test 4: hash (old analyzer)';
SELECT count(*) AS match_count, countDistinct(t1_large.id) AS unique_ids
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
SETTINGS enable_analyzer = 0, join_algorithm='hash';

-- Test 5: parallel_hash with new analyzer
SELECT 'Test 5: parallel_hash (new analyzer)';
SELECT count(*) AS match_count, countDistinct(t1_large.id) AS unique_ids
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
SETTINGS enable_analyzer = 1, join_algorithm='parallel_hash';

-- Test 6: parallel_hash with old analyzer
SELECT 'Test 6: parallel_hash (old analyzer)';
SELECT count(*) AS match_count, countDistinct(t1_large.id) AS unique_ids
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
SETTINGS enable_analyzer = 0, join_algorithm='parallel_hash';

-- Test 7: Verify specific test cases with grace_hash
SELECT 'Test 7: Specific cases verification (grace_hash)';
SELECT t10_large.value, count(*) AS match_count
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
WHERE t10_large.value IN ('Sequential', 'AllNulls', 'HighIds', 'Duplicates', 'MixedNulls', 'Sparse')
GROUP BY t10_large.value
ORDER BY t10_large.value
SETTINGS enable_analyzer = 1, join_algorithm='grace_hash';

-- Test 8: Verify specific test cases with parallel_hash
SELECT 'Test 8: Specific cases verification (parallel_hash)';
SELECT t10_large.value, count(*) AS match_count
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
WHERE t10_large.value IN ('Sequential', 'AllNulls', 'HighIds', 'Duplicates', 'MixedNulls', 'Sparse')
GROUP BY t10_large.value
ORDER BY t10_large.value
SETTINGS enable_analyzer = 1, join_algorithm='parallel_hash';

-- Test 9: Sample of actual matches (grace_hash)
SELECT 'Test 9: Sample matches (grace_hash)';
SELECT t1_large.id, t10_large.value
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
WHERE t1_large.id IN (1, 2, 3, 500, 999)
ORDER BY t1_large.id, t10_large.value
SETTINGS enable_analyzer = 1, join_algorithm='grace_hash';

-- Test 10: Sample of actual matches (parallel_hash)
SELECT 'Test 10: Sample matches (parallel_hash)';
SELECT t1_large.id, t10_large.value
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
WHERE t1_large.id IN (1, 2, 3, 500, 999)
ORDER BY t1_large.id, t10_large.value
SETTINGS enable_analyzer = 1, join_algorithm='parallel_hash';

-- Test 11: Group by category with grace_hash
SELECT 'Test 11: Group by category (grace_hash)';
SELECT t10_large.category, count(*) AS match_count
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
GROUP BY t10_large.category
ORDER BY t10_large.category
SETTINGS enable_analyzer = 1, join_algorithm='grace_hash';

-- Test 12: Group by category with parallel_hash
SELECT 'Test 12: Group by category (parallel_hash)';
SELECT t10_large.category, count(*) AS match_count
FROM t1_large
INNER JOIN t10_large ON has(t10_large.arr, t1_large.id)
GROUP BY t10_large.category
ORDER BY t10_large.category
SETTINGS enable_analyzer = 1, join_algorithm='parallel_hash';

-- Cleanup
DROP TABLE IF EXISTS t1_large;
DROP TABLE IF EXISTS t10_large;
