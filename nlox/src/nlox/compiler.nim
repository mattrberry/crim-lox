import std/[strformat, strutils, tables]
import scanner, chunk, value
when defined(debugPrintCode): import debug

type
  Compiler = ref object
    scanner: Scanner
    parser: Parser
    compilingChunk: Chunk
    globals: Table[string, byte]

  Parser = ref object
    current, previous: Token
    hadError, panicMode: bool

  Precedence = enum
    precNone,
    precAssignment,
    precOr,
    precAnd,
    precEquality,
    precComparison,
    precTerm,
    precFactor,
    precUnary,
    precCall,
    precPrimary

  ParseRule = object
    prefix, infix: ParseFn
    precedence: Precedence

  ParseFn = proc(c: Compiler, canAssign: bool)

using c: Compiler

converter toByte(tokType: TokType): byte = byte(ord(tokType))

proc errorAt(c; token: Token, message: string) =
  if c.parser.panicMode: return
  c.parser.panicMode = true
  stderr.write(fmt"[line {token.line}] Error")
  case token.tokType
    of tkEof: stderr.write(" at end")
    of tkError: discard
    else: stderr.write(fmt" at '{token.lit}'")
  stderr.writeLine(fmt": {message}")
  c.parser.hadError = true

proc error(c; message: string) =
  c.errorAt(c.parser.previous, message)

proc errorAtCurrent(c; message: string) =
  c.errorAt(c.parser.current, message)

proc advance(c) =
  c.parser.previous = c.parser.current
  while true:
    c.parser.current = c.scanner.scanToken()
    if c.parser.current.tokType != tkError: break
    c.errorAtCurrent(c.parser.current.lit)

proc consume(c; tokType: TokType, message: string) =
  if c.parser.current.tokType == tokType:
    c.advance()
  else:
    c.errorAtCurrent(message)

proc check(c; tokType: TokType): bool = c.parser.current.tokType == tokType

proc match(c; tokType: TokType): bool =
  result = c.check(tokType)
  if result: c.advance()

proc makeConstant(c; value: Value): byte =
  let constant = c.compilingChunk.addConstant(value)
  if constant > 255: c.error("Too many constants in one chunk.")
  else: result = constant.byte

proc emitBytes(c; bytes: varargs[byte]) =
  for b in bytes: writeChunk(c.compilingChunk, b, c.parser.previous.line)

proc emitConstant(c; value: Value) = c.emitBytes(opConstant, c.makeConstant(value))

proc identifierConstant(c; name: Token): byte =
  if name.lit notin c.globals:
    c.globals[name.lit] = c.makeConstant(name.lit)
  c.globals[name.lit]

proc parseVariable(c; errorMessage: string): byte =
  c.consume(tkIdent, errorMessage)
  c.identifierConstant(c.parser.previous)

proc defineVariable(c; global: byte) = c.emitBytes(opDefineGlobal, global)

proc endCompiler(c) =
  c.emitBytes(opReturn)
  when defined(debugPrintCode):
    if not c.parser.hadError:
      disassembleChunk(c.compilingChunk, "code")

proc expression(c)
proc statement(c)
proc declaration(c)
proc getRule(tokType: TokType): ParseRule
proc parsePrecedence(c; precedence: Precedence)

proc number(c; canAssign: bool) =
  let value = parseFloat(c.parser.previous.lit)
  c.emitConstant(value)

proc grouping(c; canAssign: bool) =
  c.expression()
  c.consume(tkRightParen, "Expect ')' after expression.")

proc unary(c; canAssign: bool) =
  let opType = c.parser.previous.tokType
  c.parsePrecedence(precUnary) # compile the operand
  case opType
    of tkBang: c.emitBytes(opNot)
    of tkMinus: c.emitBytes(opNegate)
    else: discard # unreachable

proc binary(c; canAssign: bool) =
  let opType = c.parser.previous.tokType
  let rule = getRule(opType)
  c.parsePrecedence(succ(rule.precedence))
  case opType
    of tkBangEqual: c.emitBytes(opEqual, opNot)
    of tkEqualEqual: c.emitBytes(opEqual)
    of tkGreater: c.emitBytes(opGreater)
    of tkGreaterEqual: c.emitBytes(opLess, opNot)
    of tkLess: c.emitBytes(opLess)
    of tkLessEqual: c.emitBytes(opGreater, opNot)
    of tkPlus: c.emitBytes(opAdd)
    of tkMinus: c.emitBytes(opSubtract)
    of tkStar: c.emitBytes(opMultiply)
    of tkSlash: c.emitBytes(opDivide)
    else: discard

proc literal(c; canAssign: bool) =
  case c.parser.previous.tokType
    of tkFalse: c.emitBytes(opFalse)
    of tkNil: c.emitBytes(opNil)
    of tkTrue: c.emitBytes(opTrue)
    else: discard

proc str(c; canAssign: bool) =
  c.emitConstant(c.parser.previous.lit[1..^2])

proc namedVariable(c; name: Token, canAssign: bool) =
  let arg = c.identifierConstant(name)
  if canAssign and c.match(tkEqual):
    c.expression()
    c.emitBytes(opSetGlobal, arg)
  else:
    c.emitBytes(opGetGlobal, arg)

proc variable(c; canAssign: bool) = c.namedVariable(c.parser.previous, canAssign)

const rules: array[TokType, ParseRule] = [
  tkLeftParen:    ParseRule(prefix: grouping, infix: nil,    precedence: precNone),
  tkRightParen:   ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkLeftBrace:    ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkRightBrace:   ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkComma:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkDot:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkMinus:        ParseRule(prefix: unary,    infix: binary, precedence: precTerm),
  tkPlus:         ParseRule(prefix: nil,      infix: binary, precedence: precTerm),
  tkSemicolon:    ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkSlash:        ParseRule(prefix: nil,      infix: binary, precedence: precFactor),
  tkStar:         ParseRule(prefix: nil,      infix: binary, precedence: precFactor),
  tkBang:         ParseRule(prefix: unary,    infix: nil,    precedence: precNone),
  tkBangEqual:    ParseRule(prefix: nil,      infix: binary, precedence: precEquality),
  tkEqual:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkEqualEqual:   ParseRule(prefix: nil,      infix: binary, precedence: precEquality),
  tkGreater:      ParseRule(prefix: nil,      infix: binary, precedence: precComparison),
  tkGreaterEqual: ParseRule(prefix: nil,      infix: binary, precedence: precComparison),
  tkLess:         ParseRule(prefix: nil,      infix: binary, precedence: precComparison),
  tkLessEqual:    ParseRule(prefix: nil,      infix: binary, precedence: precComparison),
  tkIdent:        ParseRule(prefix: variable, infix: nil,    precedence: precNone),
  tkString:       ParseRule(prefix: str,      infix: nil,    precedence: precNone),
  tkNumber:       ParseRule(prefix: number,   infix: nil,    precedence: precNone),
  tkAnd:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkClass:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkElse:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkFalse:        ParseRule(prefix: literal,  infix: nil,    precedence: precNone),
  tkFor:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkFun:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkIf:           ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkNil:          ParseRule(prefix: literal,  infix: nil,    precedence: precNone),
  tkOr:           ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkPrint:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkReturn:       ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkSuper:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkThis:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkTrue:         ParseRule(prefix: literal,  infix: nil,    precedence: precNone),
  tkVar:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkWhile:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkError:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkEof:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
]

proc getRule(tokType: TokType): ParseRule = rules[tokType]

proc parsePrecedence(c; precedence: Precedence) =
  c.advance()
  let prefixRule = getRule(c.parser.previous.tokType).prefix
  if prefixRule == nil:
    c.error("Expect expression.")
    return
  let canAssign = precedence <= precAssignment
  c.prefixRule(canAssign)
  while precedence <= getRule(c.parser.current.tokType).precedence:
    c.advance()
    let infixRule = getRule(c.parser.previous.tokType).infix
    c.infixRule(canAssign)
  if canAssign and c.match(tkEqual): c.error("Invalid assignment target.")

proc expression(c) = c.parsePrecedence(precAssignment)

proc expressionStatement(c) =
  c.expression()
  c.consume(tkSemicolon, "Expect ';' after expression.")
  c.emitBytes(opPop)

proc printStatement(c) =
  c.expression()
  c.consume(tkSemicolon, "Expect ';' after value.")
  c.emitBytes(opPrint)

proc synchronize(c) =
  c.parser.panicMode = false
  while c.parser.current.tokType != tkEof:
    if c.parser.previous.tokType == tkSemicolon or c.parser.current.tokType in {
        tkClass, tkFun, tkVar, tkFor,
        tkIf, tkWhile, tkPrint, tkReturn
      }: return
    c.advance()

proc statement(c) =
  if c.match(tkPrint): c.printStatement()
  else: c.expressionStatement()

proc varDeclaration(c) =
  let global = c.parseVariable("Expect variable name.")
  if c.match(tkEqual): c.expression()
  else: c.emitBytes(opNil)
  c.consume(tkSemicolon, "Expect ';' after variable declaration.")
  c.defineVariable(global)

proc declaration(c) =
  if c.match(tkVar): c.varDeclaration()
  else: c.statement()
  if c.parser.panicMode: c.synchronize()

proc compile*(source: string, chunk: Chunk): bool =
  let scanner = newScanner(source)
  let compiler = Compiler(scanner: scanner, parser: new Parser, compilingChunk: chunk)
  compiler.advance()
  while not compiler.match(tkEof): compiler.declaration()
  result = not compiler.parser.hadError
  compiler.endCompiler()
