//
//  Interpreter.swift
//  SwiftPascalInterpreter
//
//  Created by Igor Kulman on 06/12/2017.
//  Copyright © 2017 Igor Kulman. All rights reserved.
//

import Foundation

public class Interpreter {
    private var callStack = Stack<Frame>()
    private let tree: AST
    private let scopes: [String: ScopedSymbolTable]

    public init(_ text: String) {
        let parser = Parser(text)
        tree = parser.parse()
        let semanticAnalyzer = SemanticAnalyzer()
        scopes = semanticAnalyzer.analyze(node: tree)
    }

    @discardableResult private func eval(node: AST) -> Value? {
        switch node {
        case let number as Number:
            return eval(number: number)
        case let unaryOperation as UnaryOperation:
            return eval(unaryOperation: unaryOperation)
        case let binaryOperation as BinaryOperation:
            return eval(binaryOperation: binaryOperation)
        case let compound as Compound:
            return eval(compound: compound)
        case let assignment as Assignment:
            return eval(assignment: assignment)
        case let variable as Variable:
            return eval(variable: variable)
        case let block as Block:
            return eval(block: block)
        case let program as Program:
            return eval(program: program)
        case let call as ProcedureCall:
            return eval(call: call)
        default:
            return nil
        }
    }

    func eval(number: Number) -> Value? {
        return .number(number)
    }

    func eval(unaryOperation: UnaryOperation) -> Value? {
        guard let value = eval(node: unaryOperation.operand), case let .number(result) = value else {
            fatalError("Cannot use unary \(unaryOperation.operation) on non number")
        }

        switch unaryOperation.operation {
        case .plus:
            return  .number(+result)
        case .minus:
            return  .number(-result)
        }
    }
    func eval(binaryOperation: BinaryOperation) -> Value? {
        guard let leftValue = eval(node: binaryOperation.left), case let  .number(leftResult) = leftValue,
            let rightValue = eval(node: binaryOperation.right), case let .number(rightResult) = rightValue else {
            fatalError("Cannot use binary \(binaryOperation.operation) on non numbers")
        }

        switch binaryOperation.operation {
        case .plus:
            return  .number(leftResult + rightResult)
        case .minus:
            return  .number(leftResult - rightResult)
        case .mult:
            return  .number(leftResult * rightResult)
        case .integerDiv:
            return  .number(leftResult ‖ rightResult)
        case .floatDiv:
            return  .number(leftResult / rightResult)
        }
    }

    func eval(compound: Compound) -> Value? {
        for child in compound.children {
            eval(node: child)
        }
        return nil
    }

    func eval(assignment: Assignment) -> Value? {
        guard let currentFrame = callStack.peek() else {
            fatalError("No call stack frame")
        }

        currentFrame.set(variable: assignment.left.name, value: eval(node: assignment.right)!)
        return nil
    }

    func eval(variable: Variable) -> Value? {
        guard let currentFrame = callStack.peek() else {
            fatalError("No call stack frame")
        }

        return currentFrame.get(variable: variable.name)
    }

    func eval(block: Block) -> Value? {
        for declaration in block.declarations {
            eval(node: declaration)
        }

        return eval(node: block.compound)
    }

    func eval(program: Program) -> Value? {
        let frame = Frame(scope: scopes["global"]!, previousFrame: nil)
        callStack.push(frame)
        return eval(node: program.block)
    }

    func eval(call: ProcedureCall) -> Value? {
        let current = callStack.peek()!
        let frame = Frame(scope: scopes[call.name]!, previousFrame: current)
        callStack.push(frame)
        callProcedure(procedure: call.name, params: call.actualParameters, frame: frame)
        callStack.pop()
        return nil
    }

    private func callProcedure(procedure: String, params: [AST], frame: Frame) {
        guard let symbol = frame.scope.lookup(procedure), let procedureSymbol = symbol as? ProcedureSymbol else {
            fatalError("Symbol(procedure) not found '\(procedure)'")
        }

        if procedureSymbol.params.count > 0 {

            for i in 0 ... procedureSymbol.params.count - 1 {
                guard let evaluated = eval(node: params[i]) else {
                    fatalError("Cannot assing empty value")
                }
                frame.set(variable: procedureSymbol.params[i].name, value: evaluated)
            }
        }

        eval(node: procedureSymbol.body.block)
    }

    public func interpret() {
        eval(node: tree)
    }

    func getState() -> ([String: Int], [String: Double]) {
        return (callStack.peek()!.integerMemory, callStack.peek()!.realMemory)
    }

    public func printState() {
        print("Final interpreter memory state (\(callStack.peek()!.scope.name)):")
        print("Int: \(callStack.peek()!.integerMemory)")
        print("Real: \(callStack.peek()!.realMemory)")
    }
}
