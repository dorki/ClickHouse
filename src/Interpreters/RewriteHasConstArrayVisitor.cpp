#include <Interpreters/RewriteHasConstArrayVisitor.h>
#include <Parsers/ASTFunction.h>
#include <Parsers/ASTIdentifier.h>
#include <Parsers/ASTLiteral.h>
#include <Parsers/ASTExpressionList.h>
#include <Common/typeid_cast.h>

namespace DB
{

void RewriteHasConstArrayMatcher::visit(ASTPtr & ast, Data &)
{
    auto * function = ast->as<ASTFunction>();
    if (!function)
        return;

    if (function->name != "has" || !function->arguments || function->arguments->children.size() != 2)
        return;

    const auto * first_arg_literal = function->arguments->children[0]->as<ASTLiteral>();
    const auto * second_arg_identifier = function->arguments->children[1]->as<ASTIdentifier>();

    // We are looking for the specific pattern: has(Literal, Identifier)
    if (!first_arg_literal || !second_arg_identifier)
        return;

    // The literal must be of type Array.
    if (first_arg_literal->value.getType() != Field::Types::Array)
        return;

    // Pattern matched. Rewrite has(const_array, column) into `column IN const_array`.
    // The AST for `IN` is slightly different from a normal function call.
    // It's an ASTFunction with the column identifier and the array literal as arguments.
    auto new_function = std::make_shared<ASTFunction>();
    new_function->name = "in";
    new_function->arguments = std::make_shared<ASTExpressionList>();
    new_function->children.push_back(new_function->arguments);

    // The column identifier becomes the first argument of the 'in' function.
    new_function->arguments->children.push_back(function->arguments->children[1]);
    // The array literal becomes the second argument.
    new_function->arguments->children.push_back(function->arguments->children[0]);

    // Replace the old 'has' function AST node with the new 'in' function AST node.
    ast = new_function;
}

bool RewriteHasConstArrayMatcher::needChildVisit(const ASTPtr & node, const ASTPtr &)
{
    if (node->as<ASTFunction>()) // Don't visit children of functions
        return false;
    return true;
}

}
