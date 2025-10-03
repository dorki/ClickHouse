# Detailed Change Analysis: TableJoin.cpp

## File Location
`src/Interpreters/TableJoin.cpp`

## Purpose of This File
This file contains the **implementation** of the `TableJoin` class declared in `TableJoin.h`. While the header defines the interface and data structures, this file provides the actual functionality.

## Role in ClickHouse Architecture

```
TableJoin.h         TableJoin.cpp
    ↓                   ↓
[Declarations]  →  [Implementations]
    ↓                   ↓
Public API exposed  Implementation details
```

This file is where:
- Constructor logic lives
- Key registration happens
- Validation occurs
- AST (Abstract Syntax Tree) manipulation takes place

---

## Changes Made

### Single Change: Implemented `addOnArrayJoinKeys()` Method

**Location**: Lines 281-293 (after existing `addOnKeys()` method)

**Code added**:
```cpp
void TableJoin::addOnArrayJoinKeys(ASTPtr & left_table_ast, ASTPtr & right_table_ast, bool left_is_array)
{
    assertHasOneOnExpr();

    String left_name = left_table_ast->getColumnName();
    String right_name = right_table_ast->getAliasOrColumnName();

    key_asts_left.push_back(left_table_ast);
    key_asts_right.push_back(right_table_ast);

    clauses.back().addArrayJoinKey(left_name, right_name, left_is_array);
    right_key_aliases[right_table_ast->getColumnName()] = right_name;
}
```

---

## Line-by-Line Analysis

### Line 281: Method Signature
```cpp
void TableJoin::addOnArrayJoinKeys(ASTPtr & left_table_ast, ASTPtr & right_table_ast, bool left_is_array)
```

**Parameter details**:

**`ASTPtr & left_table_ast`**
- Type: `ASTPtr` = `std::shared_ptr<IAST>`
- Represents: Left side of the join condition as an Abstract Syntax Tree node
- Example: For `has(t2.arr, t1.id)`, this would be AST for `t1.id`
- Why reference (`&`)?: Avoid copying shared_ptr (performance)

**`ASTPtr & right_table_ast`**
- Type: Same as above
- Represents: Right side of the join condition
- Example: For `has(t2.arr, t1.id)`, this would be AST for `t2.arr`

**`bool left_is_array`**
- Indicates which side contains the array
- `true` = left side is array, right side is element
- `false` = right side is array, left side is element
- Example: `has(t2.arr, t1.id)` → `left_is_array = false`

**Return type**: `void`
- Method modifies object state, doesn't return anything

---

### Line 283: Assertion Check
```cpp
assertHasOneOnExpr();
```

**Purpose**: Ensure we're in a valid state to add keys

**What this checks**:
```cpp
// Implementation (in TableJoin.cpp, elsewhere):
void TableJoin::assertHasOneOnExpr() const
{
    if (clauses.size() != 1)
        throw Exception(ErrorCodes::LOGICAL_ERROR,
            "Expected exactly one JOIN ON clause, got {}", clauses.size());
}
```

**Why this is needed**:
- Multiple OR clauses: `(t1.a = t2.a) OR (t1.b = t2.b)`
- Each OR clause is a separate `JoinOnClause`
- Array join currently only supports single clause
- This ensures we don't accidentally corrupt data

**Example scenarios**:

**✅ Valid (single clause)**:
```sql
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id) AND t1.name = t2.name
-- clauses.size() = 1 → Passes assertion
```

**❌ Invalid (multiple clauses)**:
```sql
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id) OR t1.flag = t2.flag
-- clauses.size() = 2 → Throws exception
-- Error: Array join with OR not yet supported
```

**Why fail fast here?**
- Better error message: "Unsupported: array join with OR"
- Prevents data corruption (adding key to wrong clause)
- Makes debugging easier

---

### Lines 285-286: Extract Column Names from AST
```cpp
String left_name = left_table_ast->getColumnName();
String right_name = right_table_ast->getAliasOrColumnName();
```

**Understanding AST nodes**:

An AST node represents parsed SQL. For `t1.id`, the AST contains:
- Table name: "t1"
- Column name: "id"
- Full qualified name: "t1.id"

**`getColumnName()` vs `getAliasOrColumnName()`**:

**`getColumnName()`**:
```cpp
// Returns the column name from the AST
// Example: t1.id → "t1.id"
// Example: id → "id"
// Does NOT consider aliases
```

**`getAliasOrColumnName()`**:
```cpp
// Returns alias if present, otherwise column name
// Example: t1.id AS my_id → "my_id"
// Example: t1.id → "t1.id"
// Handles user-defined aliases
```

**Why different methods for left and right?**

Actually, this is **historical consistency** with existing `addOnKeys()` method:
```cpp
void TableJoin::addOnKeys(ASTPtr & left_table_ast, ASTPtr & right_table_ast, bool null_safe_comparison)
{
    addKey(left_table_ast->getColumnName(), right_table_ast->getAliasOrColumnName(), ...);
    //     ↑ Same pattern                     ↑ Same pattern
}
```

In practice, the analyzer ensures names are fully qualified at this point, so the difference rarely matters. But we maintain consistency with existing code.

**Example**:
```sql
-- Query:
SELECT * FROM t1 JOIN t2 ON has(t2.arr AS array_col, t1.id)

-- After parsing:
left_table_ast: AST for "t1.id"
  → getColumnName() = "t1.id"

right_table_ast: AST for "t2.arr AS array_col"
  → getAliasOrColumnName() = "array_col"  (uses alias!)
  → getColumnName() = "t2.arr"            (ignores alias)

-- Result:
left_name = "t1.id"
right_name = "array_col"  (uses the alias if present)
```

---

### Lines 288-289: Store AST Nodes
```cpp
key_asts_left.push_back(left_table_ast);
key_asts_right.push_back(right_table_ast);
```

**Purpose**: Keep original AST nodes for later use

**Data structure**:
```cpp
class TableJoin {
    ASTs key_asts_left;   // std::vector<ASTPtr>
    ASTs key_asts_right;  // std::vector<ASTPtr>
};
```

**Why store ASTs after extracting names?**

ASTs contain more information than just names:
1. **Type information**: Column data type
2. **Expression details**: If key is `CAST(col AS Int32)`, AST has cast info
3. **Source location**: For error messages
4. **Optimization hints**: Expression complexity, etc.

**Usage later**:
```cpp
// Example: Type checking
for (size_t i = 0; i < key_asts_left.size(); ++i)
{
    DataTypePtr left_type = key_asts_left[i]->getType();
    DataTypePtr right_type = key_asts_right[i]->getType();

    if (isArrayJoinKey(i))
    {
        // Verify: right_type is Array(T) and left_type is T
        validateArrayJoinTypes(left_type, right_type);
    }
}
```

**Memory management**:
- `ASTPtr` is `shared_ptr<IAST>` - reference counted
- Multiple places can hold the same AST
- Automatically freed when last reference goes away

---

### Line 291: Register Array Join Key
```cpp
clauses.back().addArrayJoinKey(left_name, right_name, left_is_array);
```

**Breaking down the call**:

**`clauses`**:
```cpp
// Member variable: std::vector<JoinOnClause>
// Each JoinOnClause represents one OR branch
// Example:
//   (t1.a = t2.a) OR (t1.b = t2.b)
//   clauses[0] for first OR branch
//   clauses[1] for second OR branch
```

**`.back()`**:
```cpp
// Returns reference to last element in vector
// Equivalent to clauses[clauses.size() - 1]
// Why .back()? We're adding to the current (last) clause
```

**`.addArrayJoinKey(...)`**:
```cpp
// Method we added in TableJoin.h (see previous doc)
// Adds the key to the clause's internal arrays
// Updates array_join_key_indexes map
```

**Full execution trace**:
```cpp
// Initial state:
clauses.size() = 1
clauses[0].key_names_left = []
clauses[0].key_names_right = []
clauses[0].array_join_key_indexes = {}

// Call:
clauses.back().addArrayJoinKey("t1.id", "t2.arr", false);

// Inside addArrayJoinKey:
size_t index = key_names_left.size();  // = 0
key_names_left.push_back("t1.id");
key_names_right.push_back("t2.arr");
array_join_key_indexes[0] = false;

// Final state:
clauses[0].key_names_left = ["t1.id"]
clauses[0].key_names_right = ["t2.arr"]
clauses[0].array_join_key_indexes = {0: false}
```

---

### Line 292: Store Right Key Alias
```cpp
right_key_aliases[right_table_ast->getColumnName()] = right_name;
```

**Purpose**: Map original column name to its alias

**Data structure**:
```cpp
class TableJoin {
    std::unordered_map<String, String> right_key_aliases;
    // Key: Original column name
    // Value: Alias (or same as key if no alias)
};
```

**Why is this needed?**

**Problem scenario**: StorageJoin (persistent join table)
```sql
-- Create persistent join table:
CREATE TABLE join_table ENGINE = Join(ANY, LEFT, id) AS
  SELECT id as user_id, name FROM users;

-- Later, use it:
SELECT * FROM orders ANY LEFT JOIN join_table USING (user_id);
--                                            Problem: ↑
-- join_table was created with column "id"
-- But query uses alias "user_id"
-- Need mapping: "id" → "user_id"
```

**How it works**:
```cpp
// For: has(t2.arr AS my_array, t1.id)

getColumnName() = "t2.arr"        // Original name
right_name = "my_array"           // Alias from getAliasOrColumnName()

right_key_aliases["t2.arr"] = "my_array";

// Later, when accessing join table:
String original_name = "t2.arr";
String actual_name = right_key_aliases[original_name];  // "my_array"
// Use actual_name to fetch column
```

**Example**:
```sql
SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id)
-- No alias:
right_key_aliases["t2.arr"] = "t2.arr"  (maps to itself)

SELECT * FROM t1 JOIN t2 ON has(t2.arr AS array_col, t1.id)
-- With alias:
right_key_aliases["t2.arr"] = "array_col"
```

**Why only right side?**

Because join execution builds from right table:
```cpp
// Build phase (processes right table):
for (each row in right_table)
{
    String col_name = getActualColumnName("t2.arr", right_key_aliases);
    // Need alias mapping for right table columns
}

// Probe phase (processes left table):
// Left table columns used as-is (no alias mapping needed)
```

---

## Relationship to `addOnKeys()` Method

**Comparison of similar methods**:

```cpp
// Regular equality: t1.col = t2.col
void TableJoin::addOnKeys(ASTPtr & left_table_ast, ASTPtr & right_table_ast, bool null_safe_comparison)
{
    assertHasOneOnExpr();

    String left_name = left_table_ast->getColumnName();
    String right_name = right_table_ast->getAliasOrColumnName();

    key_asts_left.push_back(left_table_ast);
    key_asts_right.push_back(right_table_ast);

    addKey(left_name, right_name, left_table_ast, right_table_ast, null_safe_comparison);
    //  ↑ Calls a different internal method

    right_key_aliases[right_table_ast->getColumnName()] = right_name;
}

// Array equality: has(t2.arr, t1.col)
void TableJoin::addOnArrayJoinKeys(ASTPtr & left_table_ast, ASTPtr & right_table_ast, bool left_is_array)
{
    assertHasOneOnExpr();

    String left_name = left_table_ast->getColumnName();
    String right_name = right_table_ast->getAliasOrColumnName();

    key_asts_left.push_back(left_table_ast);
    key_asts_right.push_back(right_table_ast);

    clauses.back().addArrayJoinKey(left_name, right_name, left_is_array);
    //             ↑ Calls our new method in JoinOnClause

    right_key_aliases[right_table_ast->getColumnName()] = right_name;
}
```

**Similarities** (90% identical):
1. Same assertion check
2. Same name extraction
3. Same AST storage
4. Same alias mapping

**Only difference**:
```cpp
addOnKeys:           addKey(..., null_safe_comparison)
addOnArrayJoinKeys:  clauses.back().addArrayJoinKey(..., left_is_array)
```

**Why not merge into one method?**

**Option A (current approach)**: Separate methods
```cpp
✅ Pros:
- Clear intent (regular vs array join)
- Type safety (can't mix up parameters)
- Easy to add validation specific to each type
- Matches ClickHouse code style

❌ Cons:
- Code duplication (but minimal)
```

**Option B (unified method)**: Single method with enum
```cpp
enum class JoinKeyType { Regular, Array, Asof };

void addOnKeys(ASTPtr & left, ASTPtr & right, JoinKeyType type, ...)
{
    // ... common code ...
    switch (type) {
        case Regular: addKey(...); break;
        case Array: addArrayJoinKey(...); break;
    }
}

❌ Cons:
- Less clear at call site
- Parameters vary by type (awkward)
- Not matching ClickHouse conventions
```

**Decision**: Separate methods (option A) for clarity and consistency.

---

## Call Flow Example

**Complete trace from SQL to execution**:

```sql
SELECT * FROM t1 INNER JOIN t2 ON has(t2.arr, t1.id);
```

**Step 1: Parsing**
```cpp
// Parser creates AST:
ASTSelectQuery
  ├─ tables
  │   └─ ASTTablesInSelectQuery
  │       └─ JOIN
  │           ├─ left: ASTTableIdentifier("t1")
  │           ├─ right: ASTTableIdentifier("t2")
  │           └─ on: ASTFunction("has")
  │               ├─ arg0: ASTIdentifier("t2.arr")
  │               └─ arg1: ASTIdentifier("t1.id")
```

**Step 2: Analysis (CollectJoinOnKeysVisitor)**
```cpp
// Visitor traverses AST, finds has() function
CollectJoinOnKeysVisitor::visit(const ASTFunction & func, ...)
{
    if (func.name == "has")
    {
        ASTPtr array_arg = func.arguments[0];  // t2.arr
        ASTPtr element_arg = func.arguments[1]; // t1.id

        // Determine table ownership
        auto table_numbers = getTableNumbers(array_arg, element_arg);
        // Result: first is Right, second is Left

        // Call our method! ← YOU ARE HERE
        data.addArrayJoinKeys(element_arg, array_arg, table_numbers);
    }
}
```

**Step 3: addArrayJoinKeys (in CollectJoinOnKeysVisitor.cpp)**
```cpp
void addArrayJoinKeys(const ASTPtr & array_ast, const ASTPtr & element_ast, ...)
{
    // Swap if needed to get correct left/right order
    bool left_is_array = (array is on left);

    // Call TableJoin method ← ENTERS OUR METHOD
    analyzed_join.addOnArrayJoinKeys(left_ast, right_ast, left_is_array);
}
```

**Step 4: addOnArrayJoinKeys (TableJoin.cpp - our code)**
```cpp
void TableJoin::addOnArrayJoinKeys(...)
{
    assertHasOneOnExpr();  // ✓ Pass (one clause)

    String left_name = "t1.id";
    String right_name = "t2.arr";

    key_asts_left.push_back(/* AST for t1.id */);
    key_asts_right.push_back(/* AST for t2.arr */);

    clauses.back().addArrayJoinKey("t1.id", "t2.arr", false);
    // Stores: array_join_key_indexes[0] = false

    right_key_aliases["t2.arr"] = "t2.arr";
}
```

**Step 5: Execution (HashJoin)**
```cpp
// Build phase:
for (size_t i = 0; i < key_columns.size(); ++i)
{
    if (table_join->getClauses()[0].isArrayJoinKey(i))
    {
        // ✓ True for i=0
        bool right_is_array = clauses[0].rightIsArray(i);  // true

        // Expand array at position i
        expandArrayKey(i, key_columns[i]);
    }
}
```

---

## Error Handling

### Potential Errors

**1. Multiple clauses (OR conditions)**:
```cpp
assertHasOneOnExpr();
// Throws: Exception(ErrorCodes::LOGICAL_ERROR, "Expected exactly one JOIN ON clause")
```

**When**: `SELECT * FROM t1 JOIN t2 ON has(t2.arr, t1.id) OR t1.x = t2.x`

**Why**: Array join with OR not yet supported

**Solution**: Split into separate queries or use UNION

---

**2. Invalid AST (null pointer)**:
```cpp
String left_name = left_table_ast->getColumnName();
// Could crash if left_table_ast is nullptr
```

**When**: Internal error in parser/analyzer

**Protection**:
```cpp
// Analyzer ensures ASTs are valid before calling this method
// If nullptr, that's a bug in analyzer, not this method
```

---

**3. Column name extraction fails**:
```cpp
String right_name = right_table_ast->getAliasOrColumnName();
// Could return empty string or throw
```

**When**: AST node isn't an identifier (e.g., literal constant)

**Example invalid**:
```sql
JOIN ON has(t2.arr, 123)  -- Can't join on constant!
```

**Protection**: Analyzer validates before calling this method

---

## Testing Considerations

### What to Test

**1. Basic functionality**:
```cpp
TEST(TableJoin, AddArrayJoinKeys)
{
    TableJoin table_join;
    table_join.addDisjunct();  // Create initial clause

    ASTPtr left_ast = std::make_shared<ASTIdentifier>("t1.id");
    ASTPtr right_ast = std::make_shared<ASTIdentifier>("t2.arr");

    table_join.addOnArrayJoinKeys(left_ast, right_ast, false);

    auto & clause = table_join.getOnlyClause();
    EXPECT_EQ(clause.key_names_left.size(), 1);
    EXPECT_EQ(clause.key_names_left[0], "t1.id");
    EXPECT_TRUE(clause.isArrayJoinKey(0));
}
```

**2. AST storage**:
```cpp
TEST(TableJoin, StoresASTs)
{
    TableJoin table_join;
    table_join.addDisjunct();

    ASTPtr left = /* ... */;
    ASTPtr right = /* ... */;

    table_join.addOnArrayJoinKeys(left, right, false);

    // Verify ASTs stored
    EXPECT_EQ(table_join.leftKeysList()->children.size(), 1);
    EXPECT_EQ(table_join.rightKeysList()->children.size(), 1);
}
```

**3. Alias mapping**:
```cpp
TEST(TableJoin, RightKeyAliases)
{
    // Create AST with alias: t2.arr AS my_arr
    ASTPtr right_with_alias = /* ... */;

    table_join.addOnArrayJoinKeys(left, right_with_alias, false);

    // Should map original name to alias
    auto aliases = table_join.rightKeyAliases();
    EXPECT_EQ(aliases["t2.arr"], "my_arr");
}
```

**4. Multiple keys**:
```cpp
TEST(TableJoin, MixedKeys)
{
    // Add regular key
    table_join.addOnKeys(ast1, ast2, false);

    // Add array join key
    table_join.addOnArrayJoinKeys(ast3, ast4, false);

    auto & clause = table_join.getOnlyClause();
    EXPECT_EQ(clause.keysCount(), 2);
    EXPECT_FALSE(clause.isArrayJoinKey(0));  // Regular
    EXPECT_TRUE(clause.isArrayJoinKey(1));   // Array
}
```

---

## Memory Management

### Object Lifetimes

```cpp
void TableJoin::addOnArrayJoinKeys(ASTPtr & left_table_ast, ...)
```

**ASTPtr reference counting**:
```
Caller holds: shared_ptr<IAST> left_ast (ref_count = 1)
    ↓ Pass as reference
Method receives: ASTPtr & left_table_ast (no copy, ref_count still 1)
    ↓ Store in vector
key_asts_left.push_back(left_table_ast) (copy shared_ptr, ref_count = 2)
    ↓ Method returns
Caller's left_ast goes out of scope (ref_count = 1)
    ↓ TableJoin destroyed
key_asts_left destroyed (ref_count = 0)
    ↓ AST deleted
```

**Key points**:
1. Passing by reference avoids copy (performance)
2. push_back creates copy (increments ref count)
3. AST stays alive as long as TableJoin exists
4. Automatic cleanup when TableJoin destroyed

---

## Integration Points

### Where This Method is Called

**1. Old Analyzer**:
```cpp
// CollectJoinOnKeysVisitor.cpp
void Data::addArrayJoinKeys(...)
{
    analyzed_join.addOnArrayJoinKeys(element, array, false);
    //            ↑ Calls our method
}
```

**2. New Analyzer**:
```cpp
// PlannerJoins.cpp
// Does NOT call this method directly!
// Instead calls JoinClause::addArrayJoinKey() directly
// Different architecture in new analyzer
```

**Why the difference?**

**Old analyzer** uses `TableJoin` throughout:
```
Parser → CollectJoinOnKeysVisitor → TableJoin → Executor
```

**New analyzer** builds `JoinClause` first:
```
Parser → PlannerJoins → JoinClause → Convert to TableJoin → Executor
```

---

## Performance Considerations

### Time Complexity

```cpp
void TableJoin::addOnArrayJoinKeys(...)
{
    assertHasOneOnExpr();                  // O(1) - just check size
    String left_name = ...->getColumnName();  // O(1) - field access
    String right_name = ...->getAliasOrColumnName();  // O(1) - field access
    key_asts_left.push_back(...);         // O(1) amortized - vector append
    key_asts_right.push_back(...);        // O(1) amortized - vector append
    clauses.back().addArrayJoinKey(...);  // O(1) - map insert
    right_key_aliases[...] = ...;         // O(1) - hash map insert
}
// Total: O(1)
```

### Space Complexity

**Per call overhead**:
- 2 x `ASTPtr` in vectors: 16 bytes each = 32 bytes
- 1 map entry in `array_join_key_indexes`: ~40 bytes
- 1 map entry in `right_key_aliases`: ~50-100 bytes (depends on string lengths)
- **Total**: ~120-170 bytes per array join key

**Comparison**:
- Regular join key: ~100 bytes
- Array join key: ~150 bytes
- Overhead: 50% more (acceptable for new feature)

---

## Summary for Boss

**What does this method do?**
Registers an array join key with the TableJoin object, storing all metadata needed for later execution.

**Why is it needed?**
Provides the API for analyzers to inform TableJoin that a specific key uses array semantics (has function), not regular equality.

**How complex is it?**
- 13 lines of code
- Mirrors existing `addOnKeys()` method (90% similar)
- Single method implementation

**What could go wrong?**
- Very low risk: Simple data storage
- All inputs validated by caller (analyzer)
- Follows existing patterns in codebase

**Performance impact?**
- O(1) time complexity
- ~50 bytes additional memory per array key
- Zero impact on regular joins

---

## Next Steps

After reviewing this file, look at:
1. **CollectJoinOnKeysVisitor.cpp** - See how analyzer calls this method
2. **HashJoinMethodsImpl.h** - See how execution reads the stored data

**Questions to consider**:
- Should we add input validation (null checks, type checks)?
- Should we merge with addOnKeys() or keep separate?
- Do we need to support multiple clauses (OR conditions) in the future?
