-- Test array join keys during PROBE phase (array on LEFT side of probing)
-- Query: SELECT * FROM t_with_array JOIN t_with_scalar ON has(t_with_array.arr, t_with_scalar.id)
-- In this case, t_with_scalar is built (hash table with scalar keys)
-- and t_with_array is probed (needs to expand arrays during probing)

DROP TABLE IF EXISTS scalars;
DROP TABLE IF EXISTS arrays;

-- Create test tables
-- scalars table will be on RIGHT (built into hash table)
CREATE TABLE scalars (id UInt32, name String) ENGINE = Memory;
-- arrays table will be on LEFT (probed, needs array expansion)
CREATE TABLE arrays (arr Array(UInt32), group_name String) ENGINE = Memory;

-- Insert test data
INSERT INTO scalars VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie'), (4, 'David');
INSERT INTO arrays VALUES ([1, 2], 'Admins'), ([2, 3], 'Users'), ([1, 3], 'Developers'), ([], 'Empty'), ([5], 'NoMatch');

-- Test 1: INNER JOIN - array table on LEFT (probing side)
SELECT 'Test 1: INNER JOIN - array on probing side';
SELECT a.group_name, s.name
FROM arrays a
INNER JOIN scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 2: Test with parallel_hash
SELECT 'Test 2: Parallel hash';
SELECT a.group_name, s.name
FROM arrays a
INNER JOIN scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='parallel_hash';

-- Test 3: Test with grace_hash
SELECT 'Test 3: Grace hash';
SELECT a.group_name, s.name
FROM arrays a
INNER JOIN scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='grace_hash';

-- Test 4: LEFT JOIN
SELECT 'Test 4: LEFT JOIN';
SELECT a.group_name, s.name
FROM arrays a
LEFT JOIN scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 5: Empty arrays (should not match)
SELECT 'Test 5: Empty arrays';
SELECT a.group_name, s.name
FROM arrays a
INNER JOIN scalars s ON has(a.arr, s.id)
WHERE a.group_name = 'Empty'
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 6: With additional conditions
SELECT 'Test 6: With additional conditions';
SELECT a.group_name, s.name
FROM arrays a
INNER JOIN scalars s ON has(a.arr, s.id) AND s.id > 1
ORDER BY a.group_name, s.name
SETTINGS join_algorithm='hash';

-- Test 7: Test with old analyzer
SELECT 'Test 7: Old analyzer - hash';
SELECT a.group_name, s.name
FROM arrays a
INNER JOIN scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS enable_analyzer=0, join_algorithm='hash';

-- Test 8: Test with old analyzer - parallel_hash
SELECT 'Test 8: Old analyzer - parallel_hash';
SELECT a.group_name, s.name
FROM arrays a
INNER JOIN scalars s ON has(a.arr, s.id)
ORDER BY a.group_name, s.name
SETTINGS enable_analyzer=0, join_algorithm='parallel_hash';

-- Cleanup
DROP TABLE IF EXISTS scalars;
DROP TABLE IF EXISTS arrays;
