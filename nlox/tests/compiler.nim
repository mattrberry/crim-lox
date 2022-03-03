import unittest

import ../src/nlox/[compiler, chunk]

proc compile(source: string): seq[byte] =
  let chunk = newChunk()
  discard compile(source, chunk)
  chunk.code

proc res(args : varargs[byte]): seq[byte] =
  for arg in args:
    result.add(arg)

suite "compiler":
  test "compiles empty string":
    check(compile("") == res(opReturn))

  test "compiles numbers":
    check(compile("1") == res(opConstant, 0, opReturn))
    check(compile("1.2") == res(opConstant, 0, opReturn))
  
  test "compiles unary":
    check(compile("-1") == res(opConstant, 0, opNegate, opReturn))
    check(compile("--1") == res(opConstant, 0, opNegate, opNegate, opReturn))

  test "compiles grouping":
    check(compile("(1)") == res(opConstant, 0, opReturn))
    check(compile("((1))") == res(opConstant, 0, opReturn))
    check(compile("(-(1))") == res(opConstant, 0, opNegate, opReturn))

  test "compiles binary":
    check(compile("1 + 2") == res(opConstant, 0, opConstant, 1, opAdd, opReturn))
    check(compile("1 - 2") == res(opConstant, 0, opConstant, 1, opSubtract, opReturn))
    check(compile("1 * 2") == res(opConstant, 0, opConstant, 1, opMultiply, opReturn))
    check(compile("1 / 2") == res(opConstant, 0, opConstant, 1, opDivide, opReturn))

  test "respects binary precedence":
    check(compile("1 + 2 / 3") == res(opConstant, 0, opConstant, 1, opConstant, 2, opDivide, opAdd, opReturn))
    check(compile("1 / 2 + 3") == res(opConstant, 0, opConstant, 1, opDivide, opConstant, 2, opAdd, opReturn))
    check(compile("1 + 2 + 3") == res(opConstant, 0, opConstant, 1, opAdd, opConstant, 2, opAdd, opReturn))
    check(compile("1 + -2") == res(opConstant, 0, opConstant, 1, opNegate, opAdd, opReturn))
    check(compile("-1 + 2") == res(opConstant, 0, opNegate, opConstant, 1, opAdd, opReturn))
    check(compile("(-1 + 2) * 3 - -4") == res(opConstant, 0, opNegate, opConstant, 1, opAdd, opConstant, 2, opMultiply, opConstant, 3, opNegate, opSubtract, opReturn))

# Chapter 17, Challenge 1: Produce a trace for `(-1 + 2) * 3 - -4`
# ----------
# compile()
#  advance() => prev: nil, cur: (
#  expression()
#   parsePrecedence(precAssignmenet)
#    advance() => prev: (, cur: -
#    getRule(tkLeftParen) => prefix: grouping
#    grouping()
#     expression()
#       parsePrecedence(precAssignment)
#        advance() => prev: -, cur: 1
#        getRule(tkMinus) => prefix: unary, infix: binary, prec: term
#        unary()
#         parsePrecedence(precUnary)
#          advance() => prev: 1, cur: +
#          getRule(tkNumber) => prefix: number
#          number()
#           ->emit constant 1
#         ->emit opNegate
#        # precAssignment <= getRule(tkPlus).precedence
#        advance() => prev: +, cur: 2
#        binary()
#         getRule(tkPlus) => prefix: nil, infix: binary, prec: term
#         parsePrecedence(precFactor)
#          advance() => prev: 2, cur: )
#          getRule(tkNumber) => prefix: number
#          number()
#           ->emit constant 2
#         ->emit opAdd
#     consume(tkLeftParen)
#      advance() => prev: ), cur: *
#    advance() => prev: *, cur: 3
#     binary()
#      getRule(tkStar) => prefix: nil, infix: binary, prec: factor
#      parsePrecedence(precUnary)
#       advance() => prev: 3, cur: -
#       getRule(tkNumber) => prefix: number
#       number()
#        ->emit constant 3
#      ->emit opMultiply
#    advance() => prev: -, cur: -
#     binary()
#      getRule(tkMinus) => prefix: unary, infix: binary, prec: term
#      parsePrecedence(precFactor)
#       advance() => prev: -, cur: 4
#       getRule(tkMinus) => prefix: unary, infix: binary, prec: term
#       unary()
#        parsePrecedence(precUnary)
#         advance() => prev: 4, cur: tkEof
#         getRule(tkNumber) => prefix: number
#         number()
#          ->emit constant 4
#        ->emit opNegate
#      ->emit opSubtract
#  consume(tkEof)
#   advance() => prev: tkEof, cur: tkEof
#  endCompiler()
#   ->emit opReturn
