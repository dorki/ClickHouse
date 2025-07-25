#include <Analyzer/ColumnNode.h>
#include <Analyzer/ConstantNode.h>
#include <Analyzer/FunctionNode.h>
#include <Analyzer/InDepthQueryTreeVisitor.h>
#include <Analyzer/Passes/RewriteHasConstArrayPass.h>
#include <DataTypes/DataTypeArray.h>
#include "Common/logger_useful.h"
#include <Common/typeid_cast.h>
#include "Functions/FunctionFactory.h"

namespace DB
{

namespace
{

class RewriteHasConstArrayVisitor : public InDepthQueryTreeVisitorWithContext<RewriteHasConstArrayVisitor>
{
public:
    using Base = InDepthQueryTreeVisitorWithContext<RewriteHasConstArrayVisitor>;
    using Base::Base;

    void enterImpl(QueryTreeNodePtr & node)
    {
        LOG_DEBUG(getLogger("dorki"), "---------------- node {}", node->getOriginalAST()->getID());
        auto * function_node = node->as<FunctionNode>();
        if (!function_node || function_node->getFunctionName() != "has")
            return;

        LOG_DEBUG(getLogger("dorki"), "---------------- found has {}", node->getOriginalAST()->getID());
        const auto & arguments = function_node->getArguments().getNodes();
        if  (arguments.size() != 2)
            return;

        LOG_DEBUG(getLogger("dorki"), "---------------- found has with 2 args {}", node->getOriginalAST()->getID());
        const auto * first_arg_literal = arguments[0]->as<ConstantNode>();
        const auto * second_arg_identifier = arguments[1]->as<ColumnNode>();
        if (!first_arg_literal || !second_arg_identifier)
            return;

        LOG_DEBUG(getLogger("dorki"), "---------------- found has const and column {}", node->getOriginalAST()->getID());
        if (first_arg_literal->getResultType()->getTypeId() != TypeIndex::Array)
            return;

        LOG_DEBUG(getLogger("dorki"), "---------------- found has const array {}", node->getOriginalAST()->getID());
        auto in_function = std::make_shared<FunctionNode>("in");
        auto & new_arguments = in_function->getArguments().getNodes();
        new_arguments.push_back(arguments[1]);
        new_arguments.push_back(arguments[0]);
        in_function->resolveAsFunction(FunctionFactory::instance().get("in", getContext()));
        node = std::move(in_function);
    }
};

}

void RewriteHasConstArrayPass::run(QueryTreeNodePtr & query_tree_node, ContextPtr context)
{
    RewriteHasConstArrayVisitor visitor(context);
    visitor.visit(query_tree_node);
}

}
