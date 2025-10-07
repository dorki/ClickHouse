-- Test to explicitly verify that has() in JOIN ON does NOT use CrossJoin
-- Tags: no-parallel

DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;

CREATE TABLE t1 (id UInt32) ENGINE = Memory;
CREATE TABLE t2 (arr Array(UInt32), value String) ENGINE = Memory;

INSERT INTO t1 VALUES (1), (2), (3);
INSERT INTO t2 VALUES ([1, 2], 'A'), ([3], 'B');

-- Test 1: Verify EXPLAIN does not contain "Cross" for has() in JOIN ON
-- The query plan should show "Join" but NOT "Cross"
SELECT '=== Query Plan for has() in JOIN ON ===';
EXPLAIN
SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw
SETTINGS enable_analyzer = 0; -- Test old analyzer

SELECT '---';

-- Same test with new analyzer
EXPLAIN
SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
FORMAT TSVRaw
SETTINGS enable_analyzer = 1; -- Test new analyzer

SELECT '---';

-- Test 2: For comparison, show that CROSS JOIN is used for WHERE clause
SELECT '=== Query Plan for has() in WHERE (should show Cross) ===';
EXPLAIN
SELECT t1.id, t2.value
FROM t1, t2
WHERE has(t2.arr, t1.id)
FORMAT TSVRaw;

SELECT '---';

-- Test 3: Check specific pattern in plan
SELECT '=== Check Join Type ===';
SELECT
    multiIf(
        explain_output LIKE '%Expression%Join%', 'Has Join',
        explain_output LIKE '%Cross%', 'Has Cross (FAIL)',
        'Unknown'
    ) as join_type_check
FROM (
    SELECT arrayStringConcat(
        splitByString('\n',
            (SELECT * FROM (
                EXPLAIN SELECT t1.id FROM t1 INNER JOIN t2 ON has(t2.arr, t1.id)
            ) FORMAT TSVRaw)
        ), ' '
    ) as explain_output
);

SELECT '---';

-- Test 4: Simple correctness check - count should match expected
SELECT '=== Count Matches ===';
SELECT count(*) as total_matches
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id);

SELECT '---';

-- Test 5: Check that results are correct (sanity check)
SELECT '=== Verify Correct Results ===';
SELECT t1.id, t2.value
FROM t1
INNER JOIN t2 ON has(t2.arr, t1.id)
ORDER BY t1.id, t2.value;

-- Cleanup
DROP TABLE IF EXISTS t1;
DROP TABLE IF EXISTS t2;
