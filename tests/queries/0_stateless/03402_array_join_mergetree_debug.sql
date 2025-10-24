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
