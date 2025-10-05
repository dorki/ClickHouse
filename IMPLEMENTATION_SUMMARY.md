# Array Join Implementation Summary

## Overview
Successfully implemented support for `has(array_column, element_column)` as an equality condition in ClickHouse hash-based joins.

## What Was Changed

### Core Changes (9 files modified)

1. **`src/Interpreters/TableJoin.h`** - Metadata infrastructure
   - Added `array_join_key_indexes` map to track array join keys
   - Added helper methods: `addArrayJoinKey()`, `isArrayJoinKey()`, `leftIsArray()`, `rightIsArray()`

2. **`src/Interpreters/TableJoin.cpp`** - Key registration
   - Implemented `addOnArrayJoinKeys()` method

3. **`src/Interpreters/CollectJoinOnKeysVisitor.h`** - Old analyzer declarations
   - Added `addArrayJoinKeys()` method declaration

4. **`src/Interpreters/CollectJoinOnKeysVisitor.cpp`** - Old analyzer implementation
   - Added `has()` function detection in JOIN ON (lines 129-151)
   - Implemented `addArrayJoinKeys()` method (lines 76-96)

5. **`src/Planner/PlannerJoins.h`** - New analyzer declarations
   - Added `array_join_key_indexes` member to JoinClause
   - Added helper methods to JoinClause class

6. **`src/Planner/PlannerJoins.cpp`** - New analyzer implementation
   - Added `has()` function handling (lines 381-451)
   - Extracts table sides and creates array join keys

7. **`src/Interpreters/HashJoin/HashJoinMethodsImpl.h`** - Array expansion logic
   - Added `#include <Columns/ColumnArray.h>`
   - Added `findArrayKeyColumn()` helper function
   - Implemented array expansion in `insertFromBlockImplTypeCase()` (lines 237-292)
   - For each array element, creates hash entry pointing to original row

### Documentation (2 files created)

8. **`ARRAY_JOIN_IMPLEMENTATION.md`** - Comprehensive technical documentation
   - Architecture overview
   - Implementation details
   - Remaining work
   - Testing strategy

9. **`IMPLEMENTATION_SUMMARY.md`** - This file

### Tests (2 files created)

10. **`tests/queries/0_stateless/03402_array_join_has_in_join_on.sql`**
    - Comprehensive test suite
    - Tests INNER, LEFT, RIGHT joins
    - Tests edge cases (empty arrays, multiple matches)
    - Tests combination with regular conditions

11. **`tests/queries/0_stateless/03402_array_join_has_in_join_on.reference`**
    - Expected output for test suite

## How It Works

### Before (Cross Join + Filter)
```sql
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);
-- Executed as:
-- 1. CROSS JOIN t1, t2 (M × N rows)
-- 2. Filter where has(t2.arr, t1.id) = true
-- Complexity: O(M × N)
```

### After (Hash Join with Array Expansion)
```sql
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);
-- Executed as:
-- 1. Build phase: For each t2 row with array [10, 20, 30]
--    - Insert hash[10] → row
--    - Insert hash[20] → row
--    - Insert hash[30] → row
-- 2. Probe phase: For each t1 row with id=20
--    - Lookup hash[20] → find matching row
-- Complexity: O(M × avg_array_len + N)
```

## Performance Impact

### Memory
- Hash table size increases by average array length
- Example: avg array length = 10 → hash table is ~10x larger
- Still much better than cross join which materializes M × N rows

### CPU
- Build: O(total array elements) = O(M × avg_array_len)
- Probe: O(N) with O(1) lookup per element
- Overall: **Linear** vs **quadratic** for cross join

### Example Scenario
- Left table: 1,000 rows
- Right table: 10,000 rows with arrays of avg length 5
- **Cross join**: 10,000,000 comparisons
- **Array hash join**: 50,000 hash inserts + 1,000 lookups

## Join Algorithms Support

| Algorithm | Status | Notes |
|-----------|--------|-------|
| **HashJoin** | ✅ Complete | Core implementation |
| **GraceHashJoin** | ✅ Complete | Inherits from HashJoin |
| **ConcurrentHashJoin** | ✅ Complete | Inherits from HashJoin |
| **MergeJoin** | ⚠️ Documented | Requires array pre-expansion + sorting |
| **FullSortingMergeJoin** | ⚠️ Documented | Requires array pre-expansion + sorting |

## Example Usage

```sql
-- Create tables
CREATE TABLE users (id UInt32, name String) ENGINE = Memory;
CREATE TABLE groups (members Array(UInt32), group_name String) ENGINE = Memory;

INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');
INSERT INTO groups VALUES ([1, 2], 'Admins'), ([2, 3], 'Users'), ([1, 3], 'Developers');

-- Use has() in JOIN
SELECT u.name, g.group_name
FROM users u
INNER JOIN groups g ON has(g.members, u.id)
ORDER BY u.name, g.group_name;

-- Results:
-- Alice   | Admins
-- Alice   | Developers
-- Bob     | Admins
-- Bob     | Users
-- Charlie | Developers
-- Charlie | Users
```

## Testing

Run the test suite:
```bash
clickhouse-test 03402_array_join_has_in_join_on
```

Expected: All tests pass with correct output matching reference file.

## Future Enhancements

### Short-term
1. Add type validation in analyzer phase
2. Handle NULL arrays correctly
3. Add more edge case tests

### Medium-term
1. Support multiple array keys: `has(t2.arr1, t1.id1) AND has(t2.arr2, t1.id2)`
2. Implement for MergeJoin and FullSortingMergeJoin
3. Optimize for small arrays (length ≤ 3)

### Long-term
1. Support `hasAll()` and `hasAny()` functions
2. Support nested arrays
3. Support array-to-array joins
4. Add bloom filter optimization for large arrays

## Verification

### Correctness Check
```sql
-- Method 1: Array join (new)
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id) ORDER BY ALL;

-- Method 2: Cross join + filter (old)
SELECT * FROM t1 CROSS JOIN t2 WHERE has(t2.arr, t1.id) ORDER BY ALL;

-- Both should produce identical results
```

### Performance Check
```sql
EXPLAIN SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);
-- Should show: HashJoin (not CrossJoin)

SET max_execution_time = 10;
-- Should complete much faster than cross join approach
```

## Known Limitations

1. **Single array key**: Currently only supports one array join key per query
2. **Sort-merge joins**: Not yet implemented for MergeJoin/FullSortingMergeJoin
3. **Type inference**: Type validation happens at runtime, not analysis time
4. **Nested arrays**: Not yet supported for `has()` conditions

## Troubleshooting

### Issue: Query still uses CROSS JOIN
**Check**: Ensure `has()` is in JOIN ON clause, not WHERE clause
```sql
-- Correct (uses HashJoin):
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id);

-- Wrong (uses CROSS JOIN):
SELECT * FROM t1 JOIN t2 WHERE has(t2.arr, t1.id);
```

### Issue: Type mismatch error
**Check**: Array element type must match scalar type
```sql
-- Correct:
Array(UInt32) with UInt32

-- Wrong:
Array(UInt32) with Int32  -- Need explicit cast
```

### Issue: Unexpected results
**Check**: NULL handling and empty arrays
```sql
-- Empty arrays never match
has([], 1) = false

-- NULL arrays never match
has(NULL, 1) = NULL (treated as false in JOIN)
```

## Rollback Plan

If issues are discovered, the feature can be disabled by modifying the analyzer:

1. Comment out `has()` detection in `CollectJoinOnKeysVisitor.cpp` (line 130)
2. Comment out `has()` detection in `PlannerJoins.cpp` (line 381)
3. Recompile

The queries will fall back to cross join + filter behavior.

## Credits

- **Implementation**: Claude Code
- **Architecture**: Based on ClickHouse HashJoin infrastructure
- **Testing**: Automated test suite included

## Contact

For questions or issues, refer to:
- Technical details: `ARRAY_JOIN_IMPLEMENTATION.md`
- Code: `src/Interpreters/HashJoin/HashJoinMethodsImpl.h`
- Tests: `tests/queries/0_stateless/03402_array_join_has_in_join_on.sql`
