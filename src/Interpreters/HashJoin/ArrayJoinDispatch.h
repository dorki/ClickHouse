#pragma once

#include <Columns/ColumnArray.h>
#include <Columns/ColumnNullable.h>
#include <Columns/IColumn.h>
#include <Interpreters/TableJoin.h>
#include <Common/Arena.h>
#include <set>

namespace DB
{

namespace ArrayJoinDispatch
{

/// Result of array-aware selector creation
/// For non-array joins: selector.size() == source_row_mapping.size() == block.rows()
/// For array joins: selector.size() == source_row_mapping.size() > block.rows() (due to duplication)
struct SelectorWithMapping
{
    IColumn::Selector selector;              /// Which shard each "output row" goes to
    std::vector<size_t> source_row_mapping;  /// Which source row each "output row" comes from
};

/// Helper to find the array join key column index in a list of key columns
/// Returns -1 if no array join key is found
inline ssize_t findArrayKeyColumnIndex(const ColumnRawPtrs & key_columns, const TableJoin::JoinOnClause & clause)
{
    for (size_t i = 0; i < key_columns.size(); ++i)
    {
        if (clause.isArrayJoinKey(i) && clause.rightIsArray(i))
        {
            return static_cast<ssize_t>(i);
        }
    }
    return -1;
}

/// Check if the given key column names contain array join keys
inline bool hasArrayJoinKeys(const Strings & key_column_names, const TableJoin & table_join, JoinTableSide side)
{
    const auto & clauses = table_join.getClauses();
    if (clauses.empty())
        return false;

    const auto & clause = clauses[0];
    const auto & clause_key_names = (side == JoinTableSide::Left) ? clause.key_names_left : clause.key_names_right;

    for (size_t i = 0; i < key_column_names.size() && i < clause_key_names.size(); ++i)
    {
        if (clause.isArrayJoinKey(i))
        {
            bool is_array_on_this_side = (side == JoinTableSide::Left) ? clause.leftIsArray(i) : clause.rightIsArray(i);
            if (is_array_on_this_side)
                return true;
        }
    }
    return false;
}

/// Structure to hold information about array elements and their bucket assignments
struct ArrayElementInfo
{
    const ColumnArray * array_column = nullptr;
    size_t array_key_index = 0;
    const IColumn * element_column = nullptr;
    const NullMap * element_null_map = nullptr;
};

/// Extract array column information for dispatching
inline ArrayElementInfo extractArrayElementInfo(const ColumnRawPtrs & key_columns, ssize_t array_key_index)
{
    ArrayElementInfo info;

    if (array_key_index < 0 || static_cast<size_t>(array_key_index) >= key_columns.size())
        return info;

    info.array_key_index = static_cast<size_t>(array_key_index);
    info.array_column = typeid_cast<const ColumnArray *>(key_columns[array_key_index]);

    if (!info.array_column)
        return info;

    const IColumn & array_data = info.array_column->getData();
    const ColumnNullable * nullable_array_data = typeid_cast<const ColumnNullable *>(&array_data);

    info.element_column = nullable_array_data ? &nullable_array_data->getNestedColumn() : &array_data;
    info.element_null_map = nullable_array_data ? &nullable_array_data->getNullMapData() : nullptr;

    return info;
}

/// Calculate element selector for array elements using a shard function
/// ShardFunction should be: size_t shard_func(const ColumnRawPtrs & key_columns, size_t row_index) -> size_t
/// The function should return the final shard/bucket number (already masked/calculated)
template <typename ShardFunction>
IColumn::Selector calculateElementSelector(
    const ColumnRawPtrs & key_columns,
    const ArrayElementInfo & array_info,
    size_t /* num_shards */,
    ShardFunction shard_func)
{
    if (!array_info.element_column)
        return {};

    /// Create temporary key columns with element column substituted for array column
    ColumnRawPtrs expanded_key_columns = key_columns;
    expanded_key_columns[array_info.array_key_index] = array_info.element_column;

    /// Calculate shard for each element
    const size_t num_elements = array_info.element_column->size();
    IColumn::Selector element_selector;
    element_selector.reserve(num_elements);

    for (size_t elem_idx = 0; elem_idx < num_elements; ++elem_idx)
    {
        size_t shard = shard_func(expanded_key_columns, elem_idx);
        element_selector.push_back(shard);
    }

    return element_selector;
}

/// Create row selector for array join dispatch WITH source row mapping
/// Each row may be duplicated if its array elements belong to different shards
/// Returns a selector where each entry is a shard index, and the size may be > num_rows
/// Also returns source_row_mapping: which source row each selector entry came from
template <typename ShardFunction>
SelectorWithMapping createArrayAwareRowSelectorWithMapping(
    const Block & block,
    const ColumnRawPtrs & key_columns,
    const ArrayElementInfo & array_info,
    size_t num_shards,
    ShardFunction shard_func)
{
    const size_t num_rows = block.rows();
    SelectorWithMapping result;
    result.selector.reserve(num_rows);          // At least one entry per row
    result.source_row_mapping.reserve(num_rows);

    if (!array_info.array_column)
    {
        /// No array keys, use simple shard-based dispatch
        for (size_t row = 0; row < num_rows; ++row)
        {
            size_t shard = shard_func(key_columns, row);
            result.selector.push_back(shard);
            result.source_row_mapping.push_back(row);
        }
        return result;
    }

    /// Calculate element selector first
    IColumn::Selector element_selector = calculateElementSelector(key_columns, array_info, num_shards, shard_func);
    const auto & offsets = array_info.array_column->getOffsets();

    /// For each row, collect unique shards needed
    for (size_t row = 0; row < num_rows; ++row)
    {
        size_t array_start = row == 0 ? 0 : offsets[row - 1];
        size_t array_end = offsets[row];

        /// Collect unique shards for this row's non-NULL elements
        std::set<size_t> shards_for_row;
        for (size_t elem_idx = array_start; elem_idx < array_end; ++elem_idx)
        {
            /// Skip NULL elements
            if (array_info.element_null_map && (*array_info.element_null_map)[elem_idx])
                continue;

            shards_for_row.insert(element_selector[elem_idx]);
        }

        if (shards_for_row.empty())
        {
            /// All NULL elements - send to shard 0 (will be filtered during build)
            result.selector.push_back(0);
            result.source_row_mapping.push_back(row);
        }
        else
        {
            /// Add one selector entry per shard (duplicates the row)
            for (size_t shard : shards_for_row)
            {
                result.selector.push_back(shard);
                result.source_row_mapping.push_back(row);  // Track source row
            }
        }
    }

    return result;
}

/// Backward-compatible version that returns only the selector
template <typename ShardFunction>
IColumn::Selector createArrayAwareRowSelector(
    const Block & block,
    const ColumnRawPtrs & key_columns,
    const ArrayElementInfo & array_info,
    size_t num_shards,
    ShardFunction shard_func)
{
    return createArrayAwareRowSelectorWithMapping(block, key_columns, array_info, num_shards, shard_func).selector;
}

/// Overload that accepts pre-extracted key columns (useful when columns have been preprocessed)
template <typename ShardFunction>
SelectorWithMapping createArrayAwareSelectorWithMapping(
    const Block & block,
    const ColumnRawPtrs & key_columns,
    const TableJoin & table_join,
    JoinTableSide /* side */,  // Currently unused, may be needed for future left-side array support
    size_t num_shards,
    ShardFunction shard_func)
{
    /// Check if we have array join keys
    const auto & clauses = table_join.getClauses();
    if (clauses.empty())
    {
        /// No clauses, simple dispatch
        SelectorWithMapping result;
        result.selector.reserve(block.rows());
        result.source_row_mapping.reserve(block.rows());
        for (size_t row = 0; row < block.rows(); ++row)
        {
            size_t shard = shard_func(key_columns, row);
            result.selector.push_back(shard);
            result.source_row_mapping.push_back(row);
        }
        return result;
    }

    const auto & clause = clauses[0];
    ssize_t array_key_index = findArrayKeyColumnIndex(key_columns, clause);

    if (array_key_index < 0)
    {
        /// No array keys, simple dispatch
        SelectorWithMapping result;
        result.selector.reserve(block.rows());
        result.source_row_mapping.reserve(block.rows());
        for (size_t row = 0; row < block.rows(); ++row)
        {
            size_t shard = shard_func(key_columns, row);
            result.selector.push_back(shard);
            result.source_row_mapping.push_back(row);
        }
        return result;
    }

    /// Extract array element info
    ArrayElementInfo array_info = extractArrayElementInfo(key_columns, array_key_index);

    /// Create array-aware row selector with mapping
    return createArrayAwareRowSelectorWithMapping(block, key_columns, array_info, num_shards, shard_func);
}

/// Main function to create array-aware selector for block dispatch WITH mapping
/// ShardFunction should be: size_t shard_func(const ColumnRawPtrs & key_columns, size_t row_index) -> size_t
/// The function should return the final shard/bucket number (already masked/calculated)
template <typename ShardFunction>
SelectorWithMapping createArrayAwareSelectorWithMapping(
    const Block & block,
    const Strings & key_column_names,
    const TableJoin & table_join,
    JoinTableSide side,
    size_t num_shards,
    ShardFunction shard_func)
{
    /// Extract key columns
    ColumnRawPtrs key_columns;
    key_columns.reserve(key_column_names.size());
    for (const auto & key_name : key_column_names)
    {
        const auto & column = block.getByName(key_name).column;
        key_columns.push_back(column.get());
    }

    /// Call the overload that accepts pre-extracted columns
    return createArrayAwareSelectorWithMapping(block, key_columns, table_join, side, num_shards, shard_func);
}

/// Backward-compatible version that returns only the selector
template <typename ShardFunction>
IColumn::Selector createArrayAwareSelector(
    const Block & block,
    const Strings & key_column_names,
    const TableJoin & table_join,
    JoinTableSide side,
    size_t num_shards,
    ShardFunction shard_func)
{
    return createArrayAwareSelectorWithMapping(block, key_column_names, table_join, side, num_shards, shard_func).selector;
}

} // namespace ArrayJoinDispatch
} // namespace DB
