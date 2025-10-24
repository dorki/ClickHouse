-- Test multiple conditions on the same array in join
SET parallel_replicas_local_plan=1;

DROP TABLE IF EXISTS t_left;
DROP TABLE IF EXISTS t_right;

CREATE TABLE t_left
(
    id1 UInt32,
    id2 UInt32,
    name String
) ENGINE = MergeTree()
ORDER BY id1;

CREATE TABLE t_right
(
    id UInt32,
    value String,
    arr Array(UInt32)
) ENGINE = MergeTree()
ORDER BY id;

-- Insert test data
INSERT INTO t_left VALUES
    (1, 2, 'Alice'),
    (1, 3, 'Bob'),
    (2, 3, 'Charlie'),
    (5, 10, 'David'),
    (10, 20, 'Eve');

INSERT INTO t_right VALUES
    (1, 'Alpha', [1, 2, 3]),
    (2, 'Beta', [1, 2]),
    (3, 'Gamma', [2, 3]),
    (4, 'Delta', [1]),
    (5, 'Epsilon', [5, 10]),
    (6, 'Zeta', []),
    (7, 'Eta', [10, 20, 30]);

-- Test 1: Two has() conditions on same array with constants - AND
SELECT 'Test 1: Two has() AND conditions - constants';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(r.arr, 1) AND has(r.arr, 2)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 2: Two has() conditions on same array with constants - OR
SELECT 'Test 2: Two has() OR conditions - constants';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(r.arr, 1) OR has(r.arr, 2)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 3: Two has() conditions on same array from left table - AND
SELECT 'Test 3: Two has() AND conditions - from left';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(r.arr, l.id1) AND has(r.arr, l.id2)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 4: Two has() conditions on same array from left table - OR
SELECT 'Test 4: Two has() OR conditions - from left';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(r.arr, l.id1) OR has(r.arr, l.id2)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 5: RIGHT JOIN with two AND conditions
SELECT 'Test 5: RIGHT JOIN with two AND conditions';
SELECT l.name, r.value
FROM t_left l
RIGHT JOIN t_right r ON has(r.arr, l.id1) AND has(r.arr, l.id2)
ORDER BY l.name NULLS LAST, r.value
SETTINGS join_algorithm='hash';

-- Test 6: RIGHT JOIN with two OR conditions
SELECT 'Test 6: RIGHT JOIN with two OR conditions';
SELECT l.name, r.value
FROM t_left l
RIGHT JOIN t_right r ON has(r.arr, l.id1) OR has(r.arr, l.id2)
ORDER BY l.name NULLS LAST, r.value
SETTINGS join_algorithm='hash';

-- Test 7: Three has() conditions - complex
SELECT 'Test 7: Three has() conditions - complex';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON (has(r.arr, 1) AND has(r.arr, 2)) OR has(r.arr, 10)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 8: Same array checked from both sides of comparison
SELECT 'Test 8: Same array with mixed conditions';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(r.arr, l.id1) AND has(r.arr, 20)
ORDER BY l.name, r.value
SETTINGS join_algorithm='hash';

-- Test 9: FULL JOIN with multiple OR conditions
SELECT 'Test 9: FULL JOIN with multiple OR conditions';
SELECT l.name, r.value
FROM t_left l
FULL JOIN t_right r ON has(r.arr, l.id1) OR has(r.arr, l.id2)
ORDER BY l.name NULLS LAST, r.value
SETTINGS join_algorithm='hash';

-- Test 10: Parallel hash with multiple conditions
SELECT 'Test 10: Parallel hash with multiple AND conditions';
SELECT l.name, r.value
FROM t_left l
INNER JOIN t_right r ON has(r.arr, l.id1) AND has(r.arr, l.id2)
ORDER BY l.name, r.value
SETTINGS join_algorithm='parallel_hash';

-- Cleanup
DROP TABLE IF EXISTS t_left;
DROP TABLE IF EXISTS t_right;
