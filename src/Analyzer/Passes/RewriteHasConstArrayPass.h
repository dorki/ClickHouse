#pragma once

#include <Analyzer/IQueryTreePass.h>

namespace DB
{

/**
 * This pass rewrites a specific pattern of the 'has' function into a more canonical 'IN' function call.
 * It is intended to fix a query planning ambiguity for distributed queries.
 *
 * Pattern sought: has(literal_array, column_identifier)
 * Example before: SELECT * FROM table WHERE has(['a', 'b'], s)
 *
 * Resulting pattern: column_identifier IN literal_array
 * Example after:  SELECT * FROM table WHERE s IN (['a', 'b'])
 */
class RewriteHasConstArrayPass final : public IQueryTreePass
{
public:
    String getName() override { return "RewriteHasConstArray"; }

    String getDescription() override
    {
        return "Rewrite has(const_array, column) to column IN const_array";
    }

    void run(QueryTreeNodePtr & query_tree_node, ContextPtr context) override;
};

}
