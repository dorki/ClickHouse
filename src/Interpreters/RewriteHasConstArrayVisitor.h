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
 */
class RewriteHasConstArrayMatcher
{
public:
    struct Data {};
    static void visit(ASTPtr & ast, Data &);
    static bool needChildVisit(const ASTPtr & node, const ASTPtr & child);
};

using RewriteHasConstArrayVisitor = InDepthNodeVisitor<RewriteHasConstArrayMatcher, true>;
}
