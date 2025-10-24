-- Comprehensive test suite for array join with all join types and edge cases
SET parallel_replicas_local_plan=1;

DROP TABLE IF EXISTS t_left;
DROP TABLE IF EXISTS t_right;
DROP TABLE IF EXISTS t_middle;

-- Create test tables
CREATE TABLE t_left
(
    id UInt32,
    name String,
    arr Array(UInt32)
) ENGINE = MergeTree()
ORDER BY id;

CREATE TABLE t_right
(
    id UInt32,
    value String,
    arr Array(UInt32)
) ENGINE = MergeTree()
ORDER BY id;

CREATE TABLE t_middle
(
    id UInt32,
    label String,
    arr Array(UInt32)
) ENGINE = MergeTree()
ORDER BY id;

-- Insert test data
INSERT INTO t_left VALUES
    (1, 'Alice', [10, 20]),
    (2, 'Bob', [20, 30]),
    (3, 'Charlie', []),
    (4, 'David', [40]),
    (5, 'Eve', [10, 20, 30]);

INSERT INTO t_right VALUES
    (10, 'Apple', [1, 2]),
    (20, 'Banana', [1, 2, 5]),
    (30, 'Cherry', [2]),
    (40, 'Date', []),
    (50, 'Elderberry', [99]);

INSERT INTO t_middle VALUES
    (1, 'Label_A', [10, 40]),
    (2, 'Label_B', [20]),
    (3, 'Label_C', []),
    (5, 'Label_E', [10, 20, 30]);

-- Test 1: INNER JOIN - array on right
SELECT 'Test 1: INNER JOIN - array on right';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(r.arr, l.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 2: INNER JOIN - array on left
SELECT 'Test 2: INNER JOIN - array on left';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 3: LEFT JOIN - array on right
SELECT 'Test 3: LEFT JOIN - array on right';
SELECT l.name, r.value
FROM t_left l
LEFT JOIN t_right r ON has(r.arr, l.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 4: LEFT JOIN - array on left
SELECT 'Test 4: LEFT JOIN - array on left';
SELECT l.name, r.value
FROM t_left l
LEFT JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 5: RIGHT JOIN - array on right
SELECT 'Test 5: RIGHT JOIN - array on right';
SELECT l.name, r.value
FROM t_left l
RIGHT JOIN t_right r ON has(r.arr, l.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 6: RIGHT JOIN - array on left
SELECT 'Test 6: RIGHT JOIN - array on left';
SELECT l.name, r.value
FROM t_left l
RIGHT JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 7: FULL JOIN - array on right
SELECT 'Test 7: FULL JOIN - array on right';
SELECT l.name, r.value
FROM t_left l
FULL JOIN t_right r ON has(r.arr, l.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 8: FULL JOIN - array on left
SELECT 'Test 8: FULL JOIN - array on left';
SELECT l.name, r.value
FROM t_left l
FULL JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 9: Array on left with constant filter - INNER
SELECT 'Test 9: Array on left with constant filter - INNER';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, r.id) AND has(l.arr, 20)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 10: Array on right with constant filter - LEFT
SELECT 'Test 10: Array on right with constant filter - LEFT';
SELECT l.name, r.value
FROM t_left l
LEFT JOIN t_right r ON has(r.arr, l.id) AND r.id < 30
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 11: OR condition - both array joins
SELECT 'Test 11: OR condition - both array joins';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, r.id) OR has(r.arr, l.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 12: Mixed AND/OR - array + scalar
SELECT 'Test 12: Mixed AND/OR - array + scalar';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, 20) AND r.id = 20
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 13: Empty arrays behavior - RIGHT JOIN
SELECT 'Test 13: Empty arrays behavior - RIGHT JOIN';
SELECT l.name, r.value
FROM t_left l
RIGHT JOIN t_right r ON has(r.arr, l.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 14: Empty arrays on left - LEFT JOIN
SELECT 'Test 14: Empty arrays on left - LEFT JOIN';
SELECT l.name, r.value
FROM t_left l
LEFT JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 15: Duplicate array values - INNER
SELECT 'Test 15: Duplicate array values - INNER';
SELECT l.name, r.value, count(*) as cnt
FROM t_left l
INNER JOIN t_right r ON has(l.arr, 20)
GROUP BY l.name, r.value
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 16: Three-way join - array in middle
SELECT 'Test 16: Three-way join - array in middle';
SELECT l.name, m.label, r.value
FROM t_left l
INNER JOIN t_middle m ON has(m.arr, l.arr[1])
INNER JOIN t_right r ON m.id = r.id
ORDER BY l.name, m.label, r.value
SETTINGS join_algorithm='hash';

-- Test 17: Three-way join - arrays in first and last
SELECT 'Test 17: Three-way join - arrays in first and last';
SELECT l.name, m.label, r.value
FROM t_left l
INNER JOIN t_middle m ON l.id = m.id
INNER JOIN t_right r ON has(r.arr, m.id)
ORDER BY l.name, m.label, r.value
SETTINGS join_algorithm='hash';

-- Test 18: Self-join with arrays
SELECT 'Test 18: Self-join with arrays';
SELECT l1.name as name1, l2.name as name2
FROM t_left l1
INNER JOIN t_left l2 ON has(l1.arr, 20) AND has(l2.arr, 20) AND l1.id < l2.id
ORDER BY name1, name2
SETTINGS join_algorithm='hash';

-- Test 19: Subquery with array join
SELECT 'Test 19: Subquery with array join';
SELECT name, total_matches
FROM (
    SELECT l.name, count(*) as total_matches
    FROM t_left l
    INNER JOIN t_right r ON has(l.arr, r.id)
    GROUP BY l.name
)
ORDER BY name
SETTINGS join_algorithm='hash';

-- Test 20: FULL JOIN with empty arrays on both sides
SELECT 'Test 20: FULL JOIN with empty arrays';
SELECT l.name, r.value
FROM t_left l
FULL JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 21: Parallel hash - complex case
SELECT 'Test 21: Parallel hash - complex case';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='parallel_hash';

-- Test 22: RIGHT JOIN with parallel_hash
SELECT 'Test 22: RIGHT JOIN with parallel_hash';
SELECT l.name, r.value
FROM t_left l
RIGHT JOIN t_right r ON has(r.arr, l.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='parallel_hash';

-- Test 23: Array on left + WHERE filter
SELECT 'Test 23: Array on left + WHERE filter';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, r.id)
WHERE r.id >= 20
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 24: Array on right + aggregation
SELECT 'Test 24: Array on right + aggregation';
SELECT r.value, count(*) as match_count
FROM t_left l
INNER JOIN t_right r ON has(r.arr, l.id)
GROUP BY r.value
ORDER BY r.value
SETTINGS join_algorithm='hash';

-- Test 25: Chained - INNER(array) then LEFT(scalar)
SELECT 'Test 25: Chained - INNER(array) then LEFT(scalar)';
SELECT l.name, m.label, r.value
FROM t_left l
INNER JOIN t_middle m ON has(m.arr, l.arr[1])
LEFT JOIN t_right r ON m.id = r.id
ORDER BY l.name, m.label, r.value
SETTINGS join_algorithm='hash';

-- Test 26: Chained - LEFT(scalar) then RIGHT(array)
SELECT 'Test 26: Chained - LEFT(scalar) then RIGHT(array)';
SELECT l.name, m.label, r.value
FROM t_left l
LEFT JOIN t_middle m ON l.id = m.id
RIGHT JOIN t_right r ON has(r.arr, m.id)
ORDER BY l.name, m.label, r.value
SETTINGS join_algorithm='hash';

-- Test 27: Multiple array checks with AND on same array
SELECT 'Test 27: Multiple array checks with AND';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, r.id) AND has(l.arr, 10)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 28: Grace hash with array join
SELECT 'Test 28: Grace hash with array join';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(l.arr, r.id)
ORDER BY l.name, r.value
SETTINGS join_algorithm='grace_hash';

-- Cleanup
DROP TABLE IF EXISTS t_left;
DROP TABLE IF EXISTS t_right;
DROP TABLE IF EXISTS t_middle;
