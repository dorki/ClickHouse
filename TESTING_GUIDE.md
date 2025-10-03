# Testing Guide: Array Join with has() Implementation

## Overview
This guide explains how to verify that `has(array_col, element_col)` uses hash join instead of cross join.

## Quick Verification

### Method 1: EXPLAIN Query Plan
```sql
EXPLAIN
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);
```

**Expected output should contain:**
- ✅ `Join` or `HashJoin`
- ❌ **NOT** `Cross` or `CrossJoin`

**Example of correct output:**
```
Expression
  Join (hash)
    Expression
      ReadFromMemoryStorage (t1)
    Expression
      ReadFromMemoryStorage (t2)
```

**Example of incorrect output (old behavior):**
```
Expression
  Filter
    Cross Join  ← WRONG! Should not see this
      ReadFromMemoryStorage (t1)
      ReadFromMemoryStorage (t2)
```

### Method 2: Performance Comparison
```sql
-- Should be fast (hash join with array expansion)
SELECT count(*) FROM t1 JOIN t2 ON has(t2.arr, t1.id);

-- Should be slow (cross join + filter)
SELECT count(*) FROM t1 CROSS JOIN t2 WHERE has(t2.arr, t1.id);
```

For tables with 1000 rows each and average array length of 5:
- **Hash join**: ~5,000 hash inserts + 1,000 lookups ≈ **0.01 seconds**
- **Cross join**: ~1,000,000 comparisons ≈ **1-10 seconds**

If both queries take similar time, hash join is **not** being used.

### Method 3: Check Query Log
```sql
SET log_queries = 1;

SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);

SYSTEM FLUSH LOGS;

-- Check the executed query
SELECT query, type
FROM system.query_log
WHERE query LIKE '%has(t2.arr%'
ORDER BY event_time DESC
LIMIT 1;
```

Verify the query shows `JOIN ON has()` not `WHERE has()`.

## Test Suites

### Test 1: Correctness Test
**File**: `tests/queries/0_stateless/03402_array_join_has_in_join_on.sql`

**Purpose**: Verify results are correct for all join types

**Run**:
```bash
clickhouse-test 03402_array_join_has_in_join_on
```

**What it tests**:
- INNER JOIN with has()
- LEFT JOIN with has()
- RIGHT JOIN with has()
- Combination with other conditions
- Edge cases (empty arrays, no matches)
- EXPLAIN output includes "Join"

**Expected**: All queries return correct results matching reference file

### Test 2: Algorithm Verification Test
**File**: `tests/queries/0_stateless/03402_array_join_has_verify_algorithm.sql`

**Purpose**: Explicitly verify hash join algorithm is used

**Run**:
```bash
clickhouse-test 03402_array_join_has_verify_algorithm
```

**What it tests**:
- EXPLAIN shows HashJoin for has() in JOIN ON
- EXPLAIN shows Cross for has() in WHERE (comparison)
- Pipeline shows Join step
- Multiple join types (INNER, LEFT, RIGHT)

**Expected**: Plans show "Join" not "Cross" for JOIN ON queries

### Test 3: Performance Test
**File**: `tests/queries/0_stateless/03402_array_join_has_performance.sql`

**Purpose**: Verify hash join is faster than cross join

**Run**:
```bash
clickhouse-test 03402_array_join_has_performance
```

**What it tests**:
- Hash join completes within time limit
- Cross join takes longer
- Results are identical
- No duplicate rows

**Expected**: Hash join completes much faster than cross join

### Test 4: No Cross Join Test
**File**: `tests/queries/0_stateless/03402_array_join_has_no_cross.sql`

**Purpose**: Explicitly check for absence of CrossJoin

**Run**:
```bash
clickhouse-test 03402_array_join_has_no_cross
```

**What it tests**:
- Query plan does not contain "Cross"
- Query plan contains "Join"
- Works with both old and new analyzer

**Expected**: No occurrence of "Cross" in EXPLAIN output

## Manual Testing Checklist

### ✅ Step 1: Create Test Data
```sql
CREATE TABLE users (id UInt32, name String) ENGINE = Memory;
CREATE TABLE groups (members Array(UInt32), group_name String) ENGINE = Memory;

INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');
INSERT INTO groups VALUES ([1,2], 'Admins'), ([2,3], 'Users');
```

### ✅ Step 2: Check EXPLAIN Output
```sql
EXPLAIN SELECT * FROM users u JOIN groups g ON has(g.members, u.id);
```

**Check for**: Line containing `Join` without `Cross`

### ✅ Step 3: Verify Results
```sql
SELECT u.name, g.group_name
FROM users u
JOIN groups g ON has(g.members, u.id)
ORDER BY u.name, g.group_name;
```

**Expected**:
```
Alice   | Admins
Bob     | Admins
Bob     | Users
Charlie | Users
```

### ✅ Step 4: Compare with Cross Join
```sql
-- Method 1: JOIN ON has() (should use hash join)
EXPLAIN SELECT count(*) FROM users u JOIN groups g ON has(g.members, u.id);

-- Method 2: WHERE has() (uses cross join)
EXPLAIN SELECT count(*) FROM users u, groups g WHERE has(g.members, u.id);
```

**Check for**: Different plans - first should show `Join`, second should show `Cross`

### ✅ Step 5: Benchmark
```sql
-- Create larger dataset
INSERT INTO users SELECT number, concat('User', toString(number)) FROM numbers(1000);
INSERT INTO groups SELECT
    [number*5, number*5+1, number*5+2, number*5+3, number*5+4],
    concat('Group', toString(number))
FROM numbers(1000);

-- Time hash join (should be fast)
SELECT count(*) FROM users u JOIN groups g ON has(g.members, u.id);

-- Time cross join (should be slow)
SELECT count(*) FROM users u CROSS JOIN groups g WHERE has(g.members, u.id);
```

**Check for**: Hash join completes 10-100x faster

## Interpreting EXPLAIN Output

### Good Output (Hash Join)
```
Expression
  Join (hash, inner, keys: has(arr, id))  ← Good! Hash join
    Expression
      ReadFromMemoryStorage
    Expression
      ReadFromMemoryStorage
```

or simply:
```
Expression
  Join
    ReadFromMemoryStorage
    ReadFromMemoryStorage
```

### Bad Output (Cross Join)
```
Expression
  Filter (has(arr, id))  ← Bad! Filtering after cross join
    Cross Join           ← Bad! Cross join instead of hash join
      ReadFromMemoryStorage
      ReadFromMemoryStorage
```

## Common Issues

### Issue 1: Still seeing Cross Join
**Symptom**: EXPLAIN shows `Cross Join` or `Filter` with `has()`

**Possible causes**:
1. Using `WHERE has()` instead of `JOIN ON has()`
2. Implementation not compiled in
3. Old query plan cached

**Solutions**:
```sql
-- Wrong: has() in WHERE
SELECT * FROM t1, t2 WHERE has(t2.arr, t1.id);

-- Correct: has() in JOIN ON
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);

-- Clear plan cache
SYSTEM DROP QUERY CACHE;
```

### Issue 2: Performance not improved
**Symptom**: Hash join and cross join take similar time

**Possible causes**:
1. Dataset too small to show difference
2. Array join not being used
3. Other bottlenecks in query

**Solutions**:
- Use larger datasets (1000+ rows)
- Check EXPLAIN to verify join type
- Profile query execution

### Issue 3: Wrong results
**Symptom**: Results don't match expected output

**Debug steps**:
```sql
-- Compare results
(SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id))
EXCEPT
(SELECT * FROM t1 CROSS JOIN t2 WHERE has(t2.arr, t1.id));

-- Should return 0 rows if results match
```

## Advanced Verification

### Check Hash Table Statistics
```sql
SET collect_hash_table_stats_during_joins = 1;

SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);

-- Check statistics
SELECT * FROM system.hash_table_stats;
```

### Verify Array Expansion
```sql
-- For array [1,2,3], should create 3 hash entries
CREATE TABLE test_arr (arr Array(UInt32)) ENGINE = Memory;
INSERT INTO test_arr VALUES ([1,2,3]);

CREATE TABLE test_elem (id UInt32) ENGINE = Memory;
INSERT INTO test_elem VALUES (1), (2), (3), (4);

-- Should match 3 rows (1, 2, 3)
SELECT count(*) FROM test_elem e JOIN test_arr a ON has(a.arr, e.id);
-- Expected: 3
```

### Profile Memory Usage
```sql
SELECT
    formatReadableSize(memory_usage) as memory
FROM system.processes
WHERE query LIKE '%has%JOIN%';
```

Hash join with array expansion should use more memory than simple hash join, but much less than cross join.

## Automated Testing

### Run All Tests
```bash
# Run all array join tests
clickhouse-test 03402_array_join

# Run specific test
clickhouse-test 03402_array_join_has_in_join_on

# Run with verbose output
clickhouse-test --verbose 03402_array_join_has_in_join_on

# Run and show timing
clickhouse-test --time 03402_array_join_has_performance
```

### Continuous Integration
Add to CI pipeline:
```bash
#!/bin/bash
set -e

echo "Testing array join functionality..."
clickhouse-test 03402_array_join_has_in_join_on || exit 1

echo "Verifying hash join algorithm..."
clickhouse-test 03402_array_join_has_verify_algorithm || exit 1

echo "Performance validation..."
clickhouse-test 03402_array_join_has_performance || exit 1

echo "All array join tests passed!"
```

## Reporting Issues

If hash join is not being used, provide:

1. **EXPLAIN output**:
```sql
EXPLAIN SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);
```

2. **Table schemas**:
```sql
SHOW CREATE TABLE t1;
SHOW CREATE TABLE t2;
```

3. **Sample data**:
```sql
SELECT * FROM t1 LIMIT 5;
SELECT * FROM t2 LIMIT 5;
```

4. **ClickHouse version**:
```sql
SELECT version();
```

5. **Settings**:
```sql
SELECT name, value FROM system.settings WHERE name LIKE '%join%';
```

## Summary

✅ **Hash join IS being used if**:
- EXPLAIN shows `Join` without `Cross`
- Query completes much faster than cross join equivalent
- Results are correct

❌ **Hash join is NOT being used if**:
- EXPLAIN shows `Cross Join`
- EXPLAIN shows `Filter` with `has()` after join
- Performance similar to cross join
- has() appears in WHERE instead of JOIN ON

---

**For more details, see**: `ARRAY_JOIN_IMPLEMENTATION.md`
