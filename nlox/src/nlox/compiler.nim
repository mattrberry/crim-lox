import std/[strformat, strutils]
import scanner, chunk, value, types
when defined(debugPrintCode): import debug

type
  Compiler = ref object
    scanner: Scanner
    parser: Parser
    functionCompiler: FunctionCompiler

  FunctionCompiler = ref object
    enclosing: FunctionCompiler
    function: ObjFunction
    functionType: FunctionType
    compilingChunk: Chunk
    locals: seq[Local]
    scopeDepth: int

  FunctionType = enum
    typeFunction, typeScript

  Parser = ref object
    current, previous: Token
    hadError, panicMode: bool

  Local = object
    name: string
    depth: int

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

proc emitBytes(c; bytes: varargs[byte])

proc current(c): FunctionCompiler = c.functionCompiler
proc currentChunk(c): Chunk = c.functionCompiler.function.chunk

proc addLocal(c; local: Local) = c.current().locals.add(local)
# add a new local variable, but mark it as uninitialized
proc addLocal(c; name: string) = c.addLocal(Local(name: name, depth: -1))

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

proc newFunctionCompiler(current: FunctionCompiler, functionType: FunctionType, functionName: string): FunctionCompiler =
  FunctionCompiler(
    enclosing: current,
    function: newFunction(0, functionName),
    functionType: functionType,
    compilingChunk: newChunk(),
    locals: @[Local(name: "", depth: 0)] # slot reserved for the function object
  )

proc newCompiler(source: string): Compiler =
  result = Compiler(
    scanner: newScanner(source),
    parser: new Parser,
    functionCompiler: newFunctionCompiler(nil, typeScript, "")
  )

proc endCompiler(c): ObjFunction =
  c.emitBytes(opNil, opReturn)
  result = c.current().function
  when defined(debugPrintCode):
    if not c.parser.hadError:
      disassembleChunk(c.currentChunk(), if result.name == "": "<script>" else: result.name)
  c.functionCompiler = c.current().enclosing

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
  let constant = c.currentChunk().addConstant(value)
  if constant > 255: c.error("Too many constants in one chunk.")
  else: result = constant.byte

proc emitBytes(c; bytes: varargs[byte]) =
  for b in bytes: writeChunk(c.currentChunk(), b, c.parser.previous.line)

proc emitConstant(c; value: Value) = c.emitBytes(opConstant, c.makeConstant(value))

proc emitLoop(c; loopStart: int) =
  c.emitBytes(opLoop)
  let offset = c.currentChunk().code.len() - loopStart + 2 # +2 for the jump's operands
  if offset > high(uint16).int: c.error("Loop body too large.")
  c.emitBytes(((offset shr 8) and 0xff).byte, (offset and 0xff).byte)

# emit the instruction w/ by two placeholder bytes, and return the index of the instruction
proc emitJump(c; instruction: byte): int =
  c.emitBytes(instruction, 0xff, 0xff)
  c.currentChunk().code.len - 2

# patch the distance for the jump at the given offset into the code chunk
proc patchJump(c; offset: int) =
  let jumpDistance = c.currentChunk().code.len - offset - 2
  if jumpDistance > high(uint16).int: c.error("Too much code to jump over.")
  c.currentChunk().code[offset] = ((jumpDistance shr 8) and 0xff).byte
  c.currentChunk().code[offset + 1] = (jumpDistance and 0xff).byte

proc identifierConstant(c; name: Token): byte = c.makeConstant(name.lit)

proc markInitialized(c) =
  let current = c.current()
  if current.scopeDepth == 0: return
  current.locals[^1].depth = current.scopeDepth

# declare but don't define a local variable in the current scope
proc declareVariable(c) =
  let current = c.current()
  if c.current().scopeDepth == 0: return # vars in global scope are added to constants table
  let name = c.parser.previous.lit
  # don't allow multiple variable declarations of the same name in the same scope
  for idx in countdown(current.locals.high, 0):
    let local = current.locals[idx]
    if local.depth != -1 and local.depth < current.scopeDepth: break
    if name == local.name: c.error("Already a variable with this name in this scope.")
  c.addLocal(name)

# consume identifier and add it to the constants table, then return its index
proc parseVariable(c; errorMessage: string): byte =
  c.consume(tkIdent, errorMessage)
  c.declareVariable()
  if c.current().scopeDepth > 0: 0'u8 # local scope, don't add to constant's table
  else: c.identifierConstant(c.parser.previous) # add to constants table

# mark variable as initialized by setting local scope depth or emitting global define
proc defineVariable(c; global: byte) =
  if c.current().scopeDepth > 0: c.markInitialized()
  else: c.emitBytes(opDefineGlobal, global)

proc beginScope(c) = inc(c.current().scopeDepth)
proc endScope(c) =
  let current = c.current()
  dec(current.scopeDepth)
  while len(current.locals) > 0 and current.locals[^1].depth > current.scopeDepth:
    c.emitBytes(opPop)
    discard current.locals.pop()

proc expression(c)
proc statement(c)
proc declaration(c)
proc varDeclaration(c)
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

proc `and`(c; canAssign: bool) =
  let endJump = c.emitJump(opJumpIfFalse)
  c.emitBytes(opPop)
  c.parsePrecedence(precAnd)
  c.patchJump(endJump)

proc `or`(c; canAssign: bool) =
  let elseJump = c.emitJump(opJumpIfFalse)
  let endJump = c.emitJump(opJump)
  c.patchJump(elseJump)
  c.emitBytes(opPop)
  c.parsePrecedence(precOr)
  c.patchJump(endJump)

proc str(c; canAssign: bool) =
  c.emitConstant(c.parser.previous.lit[1..^2])

# determine how many bytes back in the stack the local is
proc resolveLocal(c; name: string): int =
  let current = c.current()
  for idx in countdown(current.locals.high, 0):
    let local = current.locals[idx]
    if name == local.name:
      if local.depth == -1: c.error("Can't read local variable in its own initializer.")
      return idx
  return -1 # local not found

# emit instructions to access variable with the given name
proc namedVariable(c; name: Token, canAssign: bool) =
  var arg = c.resolveLocal(name.lit) # attempt to resolve local
  var getOp, setOp: OpCode # operations can be get or set on locals or globals
  if arg != -1:
    getOp = opGetLocal
    setOp = opSetLocal
  else: # resolve global if local cannot be resolved
    arg = c.identifierConstant(name).int
    getOp = opGetGlobal
    setOp = opSetGlobal
  if canAssign and c.match(tkEqual):
    c.expression()
    c.emitBytes(setOp, arg.byte)
  else:
    c.emitBytes(getOp, arg.byte)

proc variable(c; canAssign: bool) = c.namedVariable(c.parser.previous, canAssign)

proc argumentList(c): byte =
  if not c.check(tkRightParen):
    while true:
      c.expression()
      if result == 255: c.error("Can't have more than 255 arguments.")
      result += 1
      if not c.match(tkComma): break
  c.consume(tkRightParen, "Expect ')' after arguments.")

proc call(c; canAssign: bool) =
  let argCount = c.argumentList()
  c.emitBytes(opCall, argCount)

const rules: array[TokType, ParseRule] = [
  tkLeftParen:    ParseRule(prefix: grouping, infix: call,   precedence: precCall),
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
  tkAnd:          ParseRule(prefix: nil,      infix: `and`,  precedence: precAnd),
  tkClass:        ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkElse:         ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkFalse:        ParseRule(prefix: literal,  infix: nil,    precedence: precNone),
  tkFor:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkFun:          ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkIf:           ParseRule(prefix: nil,      infix: nil,    precedence: precNone),
  tkNil:          ParseRule(prefix: literal,  infix: nil,    precedence: precNone),
  tkOr:           ParseRule(prefix: nil,      infix: `or`,   precedence: precOr),
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

proc forStatement(c) =
  c.beginScope() # wrap a new scope in case the 'for' statement declares a new variable
  c.consume(tkLeftParen, "Expect '(' after 'for'.")

  # initializer clause
  if c.match(tkSemiColon): discard # no initializer
  elif c.match(tkVar): c.varDeclaration()
  else: c.expressionStatement()

  var loopStart = c.currentChunk().code.len()

  # condition clause
  var exitJump = -1
  if not c.match(tkSemicolon):
    c.expression()
    c.consume(tkSemicolon, "Expect ';' after loop condition.")
    exitJump = c.emitJump(opJumpIfFalse) # jump out of the loop if the cond is false
    c.emitBytes(opPop) # pop the condition off the stack

  # increment clause (occurs after the body, which requires jumps to and from the body)
  if not c.match(tkRightParen):
    let bodyJump = c.emitJump(opJump) # jump past increment clause to body
    let incrementStart = c.currentChunk().code.len()
    c.expression()
    c.emitBytes(opPop) # pop increment clause result off stack
    c.consume(tkRightParen, "Expect ')' after for clauses.")
    c.emitLoop(loopStart)
    loopStart = incrementStart # where the body will jump after execution
    c.patchJump(bodyJump)

  c.statement() # for-loop body
  c.emitLoop(loopStart)

  if exitJump != -1: # only necessary if condition exists
    c.patchJump(exitJump)
    c.emitBytes(opPop) # still need to pop condition off the stack

  c.endScope()

proc ifStatement(c) =
  c.consume(tkLeftParen, "Expect '(' after 'if'.")
  c.expression()
  c.consume(tkRightParen, "Expect ')' after condition.")
  let thenJump = c.emitJump(opJumpIfFalse)
  c.emitBytes(opPop) # clean up variable on stack from conditional expression
  c.statement()
  let elseJump = c.emitJump(opJump) # jump past the 'else' after 'then' branch completes
  c.patchJump(thenJump)
  c.emitBytes(opPop) # clean up variable on stack from conditional expression
  if c.match(tkElse): c.statement()
  c.patchJump(elseJump)

proc returnStatement(c) =
  if c.current().functionType == typeScript: c.error("Can't return from top-level code.")
  if c.match(tkSemicolon): c.emitBytes(opNil)
  else:
    c.expression()
    c.consume(tkSemicolon, "Expect ';' after return value.")
  c.emitBytes(opReturn)

proc whileStatement(c) =
  let loopStart = c.currentChunk().code.len()
  c.consume(tkLeftParen, "Expect '(' after 'while'.")
  c.expression()
  c.consume(tkRightParen, "Expect ')' after condition.")
  let exitJump = c.emitJump(opJumpIfFalse)
  c.emitBytes(opPop) # pop expression if condition is true
  c.statement()
  c.emitLoop(loopStart) # jump back to condition
  c.patchJump(exitJump) # mark exit jump point
  c.emitBytes(opPop) # pop expression if condition is false

proc blockStatement(c) =
  while not c.check(tkRightBrace) and not c.check(tkEof):
    c.declaration()
  c.consume(tkRightBrace, "Expect '}' after block.")

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
  elif c.match(tkFor): c.forStatement()
  elif c.match(tkIf): c.ifStatement()
  elif c.match(tkReturn): c.returnStatement()
  elif c.match(tkWhile): c.whileStatement()
  elif c.match(tkLeftBrace):
    c.beginScope()
    c.blockStatement()
    c.endScope()
  else: c.expressionStatement()

proc function(c; functionType: FunctionType) =
  c.functionCompiler = newFunctionCompiler(c.current(), functionType, c.parser.previous.lit)
  c.beginScope()
  c.consume(tkLeftParen, "Expect '(' after function name.")
  if not c.check(tkRightParen):
    while true:
      c.current().function.arity += 1
      if c.current().function.arity > 255:
        c.errorAtCurrent("Can't have more than 255 parameters.")
      let constant = c.parseVariable("Expect parameter name.")
      c.defineVariable(constant)
      if not c.match(tkComma): break
  c.consume(tkRightParen, "Expect ')' after parameters.")
  c.consume(tkLeftBrace, "Expect '{' before function body.")
  c.blockStatement()
  let function = c.endCompiler()
  c.emitBytes(opConstant, c.makeConstant(function))

proc funDeclaration(c) =
  let global = c.parseVariable("Expect function name.")
  c.markInitialized()
  c.function(typeFunction)
  c.defineVariable(global)

proc varDeclaration(c) =
  let global = c.parseVariable("Expect variable name.")
  if c.match(tkEqual): c.expression()
  else: c.emitBytes(opNil)
  c.consume(tkSemicolon, "Expect ';' after variable declaration.")
  c.defineVariable(global)

proc declaration(c) =
  if c.match(tkFun): c.funDeclaration()
  elif c.match(tkVar): c.varDeclaration()
  else: c.statement()
  if c.parser.panicMode: c.synchronize()

proc compile*(source: string): ObjFunction =
  let compiler = newCompiler(source)
  compiler.advance()
  while not compiler.match(tkEof): compiler.declaration()
  if not compiler.parser.hadError: result = compiler.endCompiler()
