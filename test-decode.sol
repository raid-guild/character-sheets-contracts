pragma solidity ^0.8.0;

contract ExpressionContract {
    enum Operator {
        AND,
        OR,
        NOT
    }

    struct Expression {
        Operator operator;
        bytes data;
        Expression[] subExpressions;
    }

    Expression expression;

    function deserializeExpression(bytes memory data) public returns (bool) {
        require(data.length > 0, "Empty data");
        (uint8 operator, bytes memory expressionData, Expression[] memory subExpressions) = abi.decode(data, (uint8, bytes, Expression[]));
        expression =  Expression(Operator(operator), expressionData, subExpressions);
        return true;
    }
}

