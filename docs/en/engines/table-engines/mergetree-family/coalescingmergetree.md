---
description: 'CoalescingMergeTree inherits from the MergeTree engine. Its key feature
  is the ability to automatically store last non-null value of each column during part merges.'
sidebar_label: 'CoalescingMergeTree'
sidebar_position: 50
slug: /engines/table-engines/mergetree-family/coalescingmergetree
title: 'CoalescingMergeTree'
keywords: ['CoalescingMergeTree']
show_related_blogs: true
---

# CoalescingMergeTree

The engine inherits from [MergeTree](/engines/table-engines/mergetree-family/versionedcollapsingmergetree). The difference is that when merging data parts for `CoalescingMergeTree` tables ClickHouse replaces all the rows with the same primary key (or more accurately, with the same [sorting key](../../../engines/table-engines/mergetree-family/mergetree.md)) with one row which contains the latest non-null values of each column. CoalescingMergeTree will use 0 instead of NULL if column is not nullable. If the sorting key is composed in a way that a single key value corresponds to large number of rows, this significantly reduces storage volume and speeds up data selection.

We recommend using the engine together with `MergeTree`. Store complete data in `MergeTree` table, and use `CoalescingMergeTree` for aggregated data storing, for example, when preparing reports. Such an approach will prevent you from losing valuable data due to an incorrectly composed primary key.

## Creating a table {#creating-a-table}

```sql
CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2],
    ...
) ENGINE = CoalescingMergeTree([columns])
[PARTITION BY expr]
[ORDER BY expr]
[SAMPLE BY expr]
[SETTINGS name=value, ...]
```

For a description of request parameters, see [request description](../../../sql-reference/statements/create/table.md).

### Parameters of CoalescingMergeTree {#parameters-of-coalescingmergetree}

#### Columns {#columns}

`columns` - a tuple with the names of columns where values will be united. Optional parameter.
    The columns must be of a numeric type and must not be in the partition or sorting key.

 If `columns` is not specified, ClickHouse unites the values in all columns that are not in the sorting key.

### Query clauses {#query-clauses}

When creating a `CoalescingMergeTree` table the same [clauses](../../../engines/table-engines/mergetree-family/mergetree.md) are required, as when creating a `MergeTree` table.

<details markdown="1">

<summary>Deprecated Method for Creating a Table</summary>

:::note
Do not use this method in new projects and, if possible, switch the old projects to the method described above.
:::

```sql
CREATE TABLE [IF NOT EXISTS] [db.]table_name [ON CLUSTER cluster]
(
    name1 [type1] [DEFAULT|MATERIALIZED|ALIAS expr1],
    name2 [type2] [DEFAULT|MATERIALIZED|ALIAS expr2],
    ...
) ENGINE [=] CoalescingMergeTree(date-column [, sampling_expression], (primary, key), index_granularity, [columns])
```

All of the parameters excepting `columns` have the same meaning as in `MergeTree`.

- `columns` — tuple with names of columns values of which will be summed. Optional parameter. For a description, see the text above.

</details>

## Usage example {#usage-example}

Consider the following table:

```sql
CREATE TABLE test_table
(
    key UInt32,
    value UInt32
)
ENGINE = CoalescingMergeTree()
ORDER BY key
```

Insert data to it:

```sql
INSERT INTO test_table VALUES(1,NULL),(1,2),(2,1)
```

The result will looks like this:

```sql
SELECT * FROM test_table;
```

```text
┌─key─┬─value─┐
│   2 │     1 │
│   1 │     2 │
└─────┴───────┘
```

Recommended query for correct and deterministic result:

```sql
SELECT * FROM test_table FINAL;
```

```text
┌─key─┬─value─┐
│   2 │     1 │
│   1 │     2 │
└─────┴───────┘
```

Using the `FINAL` modifier forces ClickHouse to apply merge logic at query time, ensuring you get the correct, coalesced "latest" value for each column. This is the safest and most accurate method when querying from a CoalescingMergeTree table.

:::note

An approach with `GROUP BY` may return incorrect results if the underlying parts have not been fully merged.

```sql
SELECT key, last_value(value) FROM test_table GROUP BY key; -- Not recommended.
```

:::
