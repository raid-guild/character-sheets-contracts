import { encodeAbiParameters } from 'viem';

class Expression {
    constructor(type) {
        this.type = type;
    }

    serialize() {
        throw new Error("Serialization method must be implemented in subclasses");
    }
}

class Asset extends Expression {
    constructor(id, amount) {
        super('asset');
        this.id = id;
        this.amount = amount;
    }

    serialize() {
        return encodeAbiParameters(
            [{ name: 'type', type: 'string' }, { name: 'data', type: 'bytes' }],
            [this.type, encodeAbiParameters([{ name: 'id', type: 'string' }, { name: 'amount', type: 'string' }], [this.id, this.amount])]
        );
    }
}

class LogicalExpression extends Expression {
    constructor(operator, leftOperand, rightOperand) {
        super('logical');
        this.operator = operator;
        this.leftOperand = leftOperand;
        this.rightOperand = rightOperand;
    }

    serialize() {
        return encodeAbiParameters(
            [{ name: 'type', type: 'string' }, { name: 'data', type: 'bytes' }],
            [this.type, encodeAbiParameters(
                [
                    { name: 'operator', type: 'string' },
                    { name: 'leftOperand', type: 'bytes' },
                    { name: 'rightOperand', type: 'bytes' }
                ],
                [this.operator, this.leftOperand.serialize(), this.rightOperand.serialize()]
            )]
        );
    }
}

class NotExpression extends Expression {
    constructor(operand) {
        super('not');
        this.operand = operand;
    }

    serialize() {
        return encodeAbiParameters(
            [{ name: 'type', type: 'string' }, { name: 'data', type: 'bytes' }],
            [this.type, encodeAbiParameters([{ name: 'operand', type: 'bytes' }], [this.operand.serialize()])]
        );
    }
}

// Example usage
const assetA = new Asset("AssetA", "100");
const assetB = new Asset("AssetB", "200");

// Logical expression: (AssetA AND AssetB) OR NOT(AssetA)
const logicalExpression = new LogicalExpression(
    "OR",
    new LogicalExpression("AND", assetA, assetB),
    new NotExpression(assetA)
);

console.log("Serialized Logical Expression:", logicalExpression.serialize());

