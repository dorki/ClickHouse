#pragma once

#include <Interpreters/InDepthNodeVisitor.h>

namespace DB
{

class ASTFunction;

/**
 * This visitor rewrites a specific pattern of the 'has' function into a more canonical 'IN' function call.
 * It is intended to fix a query planning ambiguity for distributed queries.
 *
 * Pattern sought: has(literal_array, column_identifier)
 * Example before: SELECT * FROM table WHERE has(['a', 'b'], s)
 *
 * Resulting pattern: column_identifier IN literal_array
 * Example after:  SELECT * FROM table WHERE s IN (['a', 'b'])
 *
 * This allows the replica-side planner to unambiguously use an index on the column `s`,
 * as the `IN` operator is a primary, well-understood pattern for index usage.
 */
class RewriteHasConstArrayVisitor
{
public:
    void visit(ASTPtr & ast);

private:
    struct Data {};
    using Visitor = InDepthNodeVisitor<RewriteHasConstArrayVisitor, true>;

    void visit(ASTFunction & function, ASTPtr & ast, Data &);
};

}
