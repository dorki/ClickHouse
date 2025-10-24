-- Comprehensive test for array join with MergeTree tables
-- Tests various join algorithms, data distributions, and edge cases

SET parallel_replicas_local_plan=1;

DROP TABLE IF EXISTS mt_scalars;
DROP TABLE IF EXISTS mt_arrays;
DROP TABLE IF EXISTS mt_large_scalars;
DROP TABLE IF EXISTS mt_large_arrays;

-- Test 1: Basic MergeTree tables with different data types
CREATE TABLE mt_scalars
(
    id UInt32,
    name String,
    category String,
    value Float64
) ENGINE = MergeTree()
ORDER BY id;

CREATE TABLE mt_arrays
(
    arr Array(UInt32),
    group_name String,
    priority UInt8,
    metadata String
) ENGINE = MergeTree()
ORDER BY group_name;

-- Insert data into scalars table
INSERT INTO mt_scalars VALUES
    (1, 'Alice', 'admin', 100.5),
    (2, 'Bob', 'user', 50.2),
    (3, 'Charlie', 'moderator', 75.8),
    (4, 'David', 'admin', 95.3),
    (5, 'Eve', 'user', 60.1);

-- Insert data into arrays table with various patterns
INSERT INTO mt_arrays VALUES
    ([1, 2], 'Admins', 1, 'High priority'),
    ([2, 3], 'Users', 2, 'Medium priority'),
    ([1, 3, 4], 'Moderators', 1, 'High priority'),
    ([], 'Empty', 3, 'No members'),
    ([5], 'SingleUser', 2, 'One member'),
    ([10, 20], 'NoMatch', 3, 'No matching ids'),
    ([1, 2, 3, 4, 5], 'Everyone', 1, 'All members');

-- Test 1: INNER JOIN with hash algorithm
SELECT 'Test 1: INNER JOIN hash';
SELECT a.group_name, s.name, s.category
FROM mt_arrays a
INNER JOIN mt_scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 2: INNER JOIN with parallel_hash
SELECT 'Test 2: INNER JOIN parallel_hash';
SELECT a.group_name, s.name, s.category
FROM mt_arrays a
INNER JOIN mt_scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='parallel_hash';

-- Test 3: LEFT JOIN with hash algorithm
SELECT 'Test 3: LEFT JOIN hash';
SELECT a.group_name, s.name
FROM mt_arrays a
LEFT JOIN mt_scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 4: LEFT JOIN with parallel_hash
SELECT 'Test 4: LEFT JOIN parallel_hash';
SELECT a.group_name, s.name
FROM mt_arrays a
LEFT JOIN mt_scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='parallel_hash';

-- Test 5: RIGHT JOIN (array on right side)
SELECT 'Test 5: RIGHT JOIN hash';
SELECT s.name, a.group_name
FROM mt_scalars s
RIGHT JOIN mt_arrays a ON has(a.arr, s.id)
ORDER BY s.name, a.group_name
SETTINGS join_algorithm='hash';

-- Test 6: Composite conditions with equality
SELECT 'Test 6: Composite conditions';
SELECT a.group_name, s.name, s.category
FROM mt_arrays a
INNER JOIN mt_scalars s ON has(a.arr, s.id) AND s.category = 'admin'
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 7: Multiple predicates
SELECT 'Test 7: Multiple predicates';
SELECT a.group_name, s.name, s.value
FROM mt_arrays a
INNER JOIN mt_scalars s ON has(a.arr, s.id) AND s.value > 70 AND a.priority = 1
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 8: Aggregations with array join
SELECT 'Test 8: Aggregations';
SELECT a.group_name, count(*) as member_count, avg(s.value) as avg_value
FROM mt_arrays a
INNER JOIN mt_scalars s ON has(a.arr, s.id)
GROUP BY a.group_name
ORDER BY a.group_name
SETTINGS join_algorithm='hash';

-- Test 9: Subquery with array join
SELECT 'Test 9: Subquery';
SELECT group_name, name_list
FROM (
    SELECT a.group_name, groupArray(s.name) as name_list
    FROM mt_arrays a
    INNER JOIN mt_scalars s ON has(a.arr, s.id)
    WHERE a.priority <= 2
    GROUP BY a.group_name
)
ORDER BY group_name
SETTINGS join_algorithm='hash';

-- Test 10: Old analyzer with hash
SELECT 'Test 10: Old analyzer hash';
SELECT a.group_name, s.name
FROM mt_arrays a
INNER JOIN mt_scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS enable_analyzer=0, join_algorithm='hash';

-- Test 11: Old analyzer with parallel_hash
SELECT 'Test 11: Old analyzer parallel_hash';
SELECT a.group_name, s.name
FROM mt_arrays a
INNER JOIN mt_scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS enable_analyzer=0, join_algorithm='parallel_hash';

-- Test 12: USING clause (if supported in new syntax)
SELECT 'Test 12: Empty arrays behavior';
SELECT a.group_name, count(s.id) as match_count
FROM mt_arrays a
LEFT JOIN mt_scalars s ON has(a.arr, s.id)
GROUP BY a.group_name
HAVING group_name IN ('Empty', 'NoMatch', 'Everyone')
ORDER BY a.group_name
SETTINGS join_algorithm='hash', join_use_nulls=1;

-- Large scale test with MergeTree
CREATE TABLE mt_large_scalars
(
    id UInt32,
    name String,
    timestamp DateTime,
    status String
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (status, id);

CREATE TABLE mt_large_arrays
(
    arr Array(UInt32),
    value String,
    date Date,
    category UInt8
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (category, date);

-- Insert 5000 rows into scalars table
INSERT INTO mt_large_scalars
SELECT
    number AS id,
    concat('User_', toString(number)) AS name,
    toDateTime('2024-01-01 00:00:00') + INTERVAL number SECOND AS timestamp,
    if(number % 3 = 0, 'active', if(number % 3 = 1, 'inactive', 'pending')) AS status
FROM numbers(5000);

-- Insert 500 rows into arrays table with varying array sizes
INSERT INTO mt_large_arrays
SELECT
    arrayMap(x -> (number * 10 + x) % 5000, range(1 + (number % 20))) AS arr,
    concat('Group_', toString(number)) AS value,
    toDate('2024-01-01') + INTERVAL (number % 100) DAY AS date,
    (number % 10) AS category
FROM numbers(500);

-- Insert specific edge cases
INSERT INTO mt_large_arrays VALUES
    ([1, 100, 1000, 2000, 3000, 4000], 'Sparse', toDate('2024-01-15'), 0),
    ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 'Sequential', toDate('2024-02-01'), 1),
    ([4999, 4998, 4997, 4996, 4995], 'HighIds', toDate('2024-03-01'), 2),
    ([500, 500, 500, 500], 'Duplicates', toDate('2024-04-01'), 3),
    ([], 'EmptyArray', toDate('2024-05-01'), 4);

-- Test 13: Large scale with hash
SELECT 'Test 13: Large scale hash';
SELECT count(*) AS total_matches, countDistinct(s.id) AS unique_ids
FROM mt_large_arrays a
INNER JOIN mt_large_scalars s ON has(a.arr, s.id)
SETTINGS join_algorithm='hash';

-- Test 14: Large scale with parallel_hash
SELECT 'Test 14: Large scale parallel_hash';
SELECT count(*) AS total_matches, countDistinct(s.id) AS unique_ids
FROM mt_large_arrays a
INNER JOIN mt_large_scalars s ON has(a.arr, s.id)
SETTINGS join_algorithm='parallel_hash';

-- Test 15: Large scale with grace_hash
SELECT 'Test 15: Large scale grace_hash';
SELECT count(*) AS total_matches, countDistinct(s.id) AS unique_ids
FROM mt_large_arrays a
INNER JOIN mt_large_scalars s ON has(a.arr, s.id)
SETTINGS join_algorithm='grace_hash';

-- Test 16: Verify specific edge cases
SELECT 'Test 16: Edge cases verification';
SELECT a.value, count(*) AS match_count
FROM mt_large_arrays a
INNER JOIN mt_large_scalars s ON has(a.arr, s.id)
WHERE a.value IN ('Sparse', 'Sequential', 'HighIds', 'Duplicates', 'EmptyArray')
GROUP BY a.value
ORDER BY a.value
SETTINGS join_algorithm='parallel_hash';

-- Test 17: Partition pruning with array join
SELECT 'Test 17: Partition pruning';
SELECT count(*) AS matches
FROM mt_large_arrays a
INNER JOIN mt_large_scalars s ON has(a.arr, s.id)
WHERE s.timestamp >= toDateTime('2024-01-01 01:00:00')
  AND s.timestamp < toDateTime('2024-01-01 02:00:00')
  AND a.date = toDate('2024-01-15')
SETTINGS join_algorithm='hash';

-- Test 18: Aggregation by status with array join
SELECT 'Test 18: Aggregation by status';
SELECT s.status, count(*) AS match_count, countDistinct(a.value) AS unique_groups
FROM mt_large_arrays a
INNER JOIN mt_large_scalars s ON has(a.arr, s.id)
GROUP BY s.status
ORDER BY s.status
SETTINGS join_algorithm='parallel_hash';

-- Test 19: PREWHERE with array join (MergeTree specific)
SELECT 'Test 19: PREWHERE optimization';
SELECT count(*) AS matches
FROM mt_large_scalars s
INNER JOIN mt_large_arrays a ON has(a.arr, s.id)
WHERE s.status = 'active'
SETTINGS join_algorithm='hash';

-- Test 20: Mixed old and new analyzer comparison
SELECT 'Test 20: Analyzer comparison - sample';
SELECT a.value, s.name
FROM mt_large_arrays a
INNER JOIN mt_large_scalars s ON has(a.arr, s.id)
WHERE s.id IN (1, 100, 500, 1000)
ORDER BY s.id, a.value
LIMIT 10
SETTINGS enable_analyzer=1, join_algorithm='hash';

-- Cleanup
DROP TABLE IF EXISTS mt_scalars;
DROP TABLE IF EXISTS mt_arrays;
DROP TABLE IF EXISTS mt_large_scalars;
DROP TABLE IF EXISTS mt_large_arrays;
