# Large Scale Array Join Test

## Test File: 03402_array_join_large_scale.sql

This test validates array join functionality at scale across all three join algorithms: `hash`, `parallel_hash`, and `grace_hash`.

## Test Data

### t1_large Table
- **Rows**: 1,000
- **Columns**: `id` (1-1000), `name` (User_N)
- **Purpose**: Left side of join with scalar keys

### t10_large Table
- **Rows**: 206 (200 generated + 6 specific test cases)
- **Columns**: `arr` (Array(Nullable(UInt32))), `value` (String), `category` (UInt32)
- **Purpose**: Right side of join with array keys

### Generated Data Pattern
For rows 0-199:
```sql
arr = arrayMap(x -> if(x % 7 = 0, NULL, (number * 5 + x) % 1000), range(1 + (number % 10)))
```

This creates:
- Arrays of size 1-10 elements (varies by row number)
- Every 7th position contains NULL
- Values range from 0-999 (wrapping)
- ~1,000 array elements total across all rows

### Specific Test Cases (6 additional rows)
1. **Sequential**: `[1, 2, 3, 4, 5]` - Simple sequential values
2. **AllNulls**: `[NULL, NULL, NULL]` - Only NULL elements (should match nothing)
3. **HighIds**: `[999, 998, 997]` - High ID values
4. **Duplicates**: `[1, 1, 1, 1]` - Duplicate values in array
5. **MixedNulls**: `[500, NULL, 600, NULL, 700]` - Alternating values and NULLs
6. **Sparse**: `[1, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500]` - Sparse distribution

## Test Coverage

### Tests 1-6: Overall Match Counts
Tests all three algorithms (hash, parallel_hash, grace_hash) with both new and old analyzer.

**Expected Results**:
- **Total Matches**: 1,806
- **Unique IDs Matched**: 806

These numbers represent:
- How many (left_row, right_row) pairs have matching values
- How many distinct left-side IDs found matches

All 6 tests should produce identical results, validating consistency across algorithms.

### Tests 7-8: Specific Case Verification
Validates the 6 specific test cases work correctly:
- **Duplicates**: 1 match (id=1 appears in array)
- **HighIds**: 3 matches (ids 997, 998, 999)
- **MixedNulls**: 3 matches (ids 500, 600, 700 - NULLs ignored)
- **Sequential**: 5 matches (ids 1-5)
- **Sparse**: 11 matches (ids at 50-step intervals)
- **AllNulls**: 0 matches (correctly omitted from results)

### Tests 9-10: Sample Matches
Spot-checks specific IDs to ensure correct row associations:
- ID 1: Should match "Duplicates" and "Sequential"
- ID 2, 3: Should match "Sequential"
- ID 500: Should match "MixedNulls" and "Sparse"
- ID 999: Should match "HighIds"

### Tests 11-12: Category Aggregation
Groups results by category (0-4) to verify:
- Correct row associations
- Aggregation works with array joins
- Distribution across categories (~360 matches each)

## What This Tests

### Correctness
- ✅ NULL handling in arrays
- ✅ Duplicate values in arrays
- ✅ Large number of rows (1000+)
- ✅ Varying array sizes (1-11 elements)
- ✅ Value distribution across range
- ✅ Both analyzers (old and new)

### Performance Characteristics
- **hash**: Single-threaded baseline
- **parallel_hash**: Multi-threaded with bucket distribution
- **grace_hash**: Disk-based with bucket spilling

### Edge Cases
- Arrays with all NULLs
- Arrays with duplicates
- Empty result sets
- High cardinality joins

## Expected Behavior

All tests should produce **identical results** regardless of:
1. Join algorithm used (hash/parallel_hash/grace_hash)
2. Analyzer version (old/new)
3. Number of threads (for parallel_hash)
4. Memory limits (for grace_hash spilling)

Any discrepancy indicates a bug in the array join implementation for that algorithm.

## How to Run

```bash
# Run the test
clickhouse-client --multiquery < 03402_array_join_large_scale.sql > actual.out

# Compare with reference
diff 03402_array_join_large_scale.reference actual.out

# No output means test passed
```

## Debugging

If a test fails, check:
1. **Match count differences**: Bug in dispatch or filtering logic
2. **Missing rows**: Bug in NULL handling or bucket assignment
3. **Wrong associations**: Bug in row-to-array element mapping
4. **Crashes**: Memory corruption or assertion failure

Enable debug output in the code to see:
- Dispatch decisions (which rows go to which buckets)
- Element filtering (which array elements are accepted by each bucket)
- Hash calculations (verify consistency between dispatch and build)
