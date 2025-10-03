-- Test to verify that has() in JOIN ON uses hash join, not cross join
-- Tags: no-parallel

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;

-- Create test tables
CREATE TABLE t1 (id UInt32, name String) ENGINE = Memory;
CREATE TABLE t2 (arr Array(UInt32), value String) ENGINE = Memory;

INSERT INTO t1 VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie'), (4, 'David'), (5, 'Eve');
INSERT INTO t2 VALUES ([1, 2, 3], 'Group A'), ([2, 4], 'Group B'), ([5], 'Group C'), ([], 'Empty Group');

-- Test 1: Verify EXPLAIN shows HashJoin for has() in JOIN ON
EXPLAIN actions=1
SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw;

SELECT '---';

-- Test 2: Verify EXPLAIN header shows join type
EXPLAIN header=1, actions=0
SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw;

SELECT '---';

-- Test 3: Compare with explicit CROSS JOIN (should show Cross)
EXPLAIN header=1, actions=0
SELECT t1.id, t2.value
FROM t1
CROSS JOIN t2
WHERE has(t2.arr, t1.id)
FORMAT TSVRaw;

SELECT '---';

-- Test 4: Verify pipeline contains Join step (not Cross)
EXPLAIN PIPELINE
SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw;

SELECT '---';

-- Test 5: Check query plan tree
EXPLAIN
SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw;

SELECT '---';

-- Test 6: Verify with LEFT JOIN as well
EXPLAIN
SELECT t1.id, t2.value
FROM t1
LEFT JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw;

SELECT '---';

-- Test 7: Verify with RIGHT JOIN
EXPLAIN
SELECT t1.id, t2.value
FROM t1
RIGHT JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw;

-- Cleanup
DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;
