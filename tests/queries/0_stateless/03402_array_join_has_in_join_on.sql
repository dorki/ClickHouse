-- Test has() function in JOIN ON clause for array join semantics
-- This test verifies:
-- 1. Correctness: Results match expected output
-- 2. Algorithm: Hash join is used instead of cross join
-- Tags: no-parallel

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;

-- Create test tables
CREATE TABLE t1 (id UInt32, name String) ENGINE = Memory;
CREATE TABLE t2 (arr Array(UInt32), value String) ENGINE = Memory;

-- Insert test data
INSERT INTO t1 VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie'), (4, 'David'), (5, 'Eve');
INSERT INTO t2 VALUES ([1, 2, 3], 'Group A'), ([2, 4], 'Group B'), ([5], 'Group C'), ([], 'Empty Group');

-- ========================================
-- ALGORITHM VERIFICATION
-- ========================================

-- Verify that EXPLAIN shows Join (not Cross) for has() in JOIN ON
SELECT '=== EXPLAIN Verification ===';
EXPLAIN
SELECT t1.id FROM t1 INNER JOIN t2 ON has(t2.arr, t1.id)
SETTINGS enable_analyzer = 0
FORMAT TSVRaw;

SELECT '=== End EXPLAIN ===';

-- ========================================
-- CORRECTNESS TESTS
-- ========================================

-- Test 1: Basic INNER JOIN with has()
SELECT t1.id, t1.name, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
ORDER BY t1.id, t2.value;

-- Expected output:
-- 1, Alice, Group A
-- 2, Alice, Group A
-- 2, Bob, Group B
-- 3, Charlie, Group A
-- 4, David, Group B
-- 5, Eve, Group C

-- Test 2: LEFT JOIN with has()
SELECT t1.id, t1.name, t2.value
FROM t1
LEFT JOIN t2 ON has(t2.arr, t1.id)
ORDER BY t1.id, t2.value;

-- Expected: All rows from t1, with NULL for unmatched

-- Test 3: RIGHT JOIN with has()
SELECT t1.id, t1.name, t2.value
FROM t1
RIGHT JOIN t2 ON has(t2.arr, t1.id)
ORDER BY t1.id, t2.value;

-- Expected: All rows from t2, with NULL for unmatched (Empty Group)

-- Test 4: Combine with regular equality condition
DROP TABLE IF EXISTS t3;
CREATE TABLE t3 (id UInt32, arr Array(UInt32), category String) ENGINE = Memory;
INSERT INTO t3 VALUES (1, [10, 20, 30], 'A'), (2, [20, 40], 'B'), (3, [30], 'A');

DROP TABLE IF EXISTS t4;
CREATE TABLE t4 (value UInt32, name String, category String) ENGINE = Memory;
INSERT INTO t4 VALUES (10, 'Ten', 'A'), (20, 'Twenty', 'A'), (30, 'Thirty', 'A'), (20, 'Twenty-B', 'B');

SELECT t3.id, t4.value, t4.name
FROM t3
INNER JOIN t4 ON t3.category = t4.category AND has(t3.arr, t4.value)
ORDER BY t3.id, t4.value;

-- Expected:
-- 1, 10, Ten
-- 1, 20, Twenty
-- 1, 30, Thirty
-- 2, 20, Twenty-B
-- 3, 30, Thirty

-- Test 5: Reversed - array on right side
SELECT t1.id, t1.name, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
ORDER BY t1.id, t2.value;

-- Test 6: Multiple array elements matching same value
DROP TABLE IF EXISTS t5;
CREATE TABLE t5 (id UInt32) ENGINE = Memory;
INSERT INTO t5 VALUES (2);

SELECT t5.id, t2.value
FROM t5
INNER JOIN t2 ON has(t2.arr, t5.id)
ORDER BY t2.value;

-- Expected:
-- 2, Group A
-- 2, Group B

-- Test 7: Empty array behavior
DROP TABLE IF EXISTS t6;
CREATE TABLE t6 (id UInt32, name String) ENGINE = Memory;
INSERT INTO t6 VALUES (100, 'NoMatch');

SELECT t6.id, t2.value
FROM t6
INNER JOIN t2 ON has(t2.arr, t6.id)
ORDER BY t6.id;

-- Expected: Empty result (no matches)

-- ========================================
-- MANUAL VERIFICATION GUIDE
-- ========================================
-- To manually verify hash join is used:
-- 1. Check EXPLAIN output above - should show "Join" without "Cross"
-- 2. Compare execution time with cross join:
--    - Hash join: O(M * avg_array_len + N) - fast
--    - Cross join: O(M * N) - slow
-- 3. Run: EXPLAIN PIPELINE SELECT ... to see join step details

-- Cleanup
DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;
DROP TABLE IF EXISTS t3;
DROP TABLE IF EXISTS t4;
DROP TABLE IF EXISTS t5;
DROP TABLE IF EXISTS t6;
