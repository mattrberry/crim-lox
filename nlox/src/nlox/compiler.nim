import std/[strformat, strutils]
import scanner, chunk, value
when defined(debugPrintCode): import debug

type
  Compiler = ref object
    scanner: Scanner
    parser: Parser
    compilingChunk: Chunk

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

  ParseFn = proc(c: Compiler)

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

proc makeConstant(c; value: Value): byte =
  let constant = c.compilingChunk.addConstant(value)
  if constant > 255: c.error("Too many constants in one chunk.")
  else: result = constant.byte

proc emitBytes(c; bytes: varargs[byte]) =
  for b in bytes: writeChunk(c.compilingChunk, b, c.parser.previous.line)

proc emitConstant(c; value: Value) =
  c.emitBytes(opConstant, c.makeConstant(value))

proc endCompiler(c) =
  c.emitBytes(opReturn)
  when defined(debugPrintCode):
    if not c.parser.hadError:
      disassembleChunk(c.compilingChunk, "code")

proc getRule(tokType: TokType): ParseRule
proc parsePrecedence(c; precedence: Precedence)

proc expression(c) = c.parsePrecedence(precAssignment)

proc number(c) =
  let value = parseFloat(c.parser.previous.lit)
  c.emitConstant(value)

proc grouping(c) =
  c.expression()
  c.consume(tkRightParen, "Expect ')' after expression.")

proc unary(c) =
  let opType = c.parser.previous.tokType
  c.parsePrecedence(precUnary) # compile the operand
  case opType
  of tkMinus: c.emitBytes(opNegate) # emit the operator instruction
  else: discard # unreachable

proc binary(c) =
  let opType = c.parser.previous.tokType
  let rule = getRule(opType)
  c.parsePrecedence(succ(rule.precedence))
  case opType
  of tkPlus: c.emitBytes(opAdd)
  of tkMinus: c.emitBytes(opSubtract)
  of tkStar: c.emitBytes(opMultiply)
  of tkSlash: c.emitBytes(opDivide)
  else: discard

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
  tkBang:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkBangEqual:    ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkEqual:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkEqualEqual:   ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkGreater:      ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkGreaterEqual: ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkLess:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkLessEqual:    ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkIdent:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkString:       ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkNumber:       ParseRule(prefix: number,   infix: nil,    precedence: precNone),
  tkAnd:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkClass:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkElse:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkFalse:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkFor:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkFun:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkIf:           ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkNil:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkOr:           ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkPrint:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkReturn:       ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkSuper:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkThis:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkTrue:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
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
  c.prefixRule()
  while precedence <= getRule(c.parser.current.tokType).precedence:
    c.advance()
    let infixRule = getRule(c.parser.previous.tokType).infix
    c.infixRule()

proc compile*(source: string, chunk: Chunk): bool =
  let scanner = newScanner(source)
  let compiler = Compiler(scanner: scanner, parser: new Parser, compilingChunk: chunk)
  compiler.advance()
  compiler.expression()
  compiler.consume(tkEof, "Expect end of expression.")
  result = not compiler.parser.hadError
  compiler.endCompiler()
