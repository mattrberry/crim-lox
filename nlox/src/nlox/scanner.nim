type
  Scanner = ref object
    source: string
    start, current: int
    line: int

  Token* = object
    tokType*: TokType
    lit*: string
    line*: int

  TokType* = enum
    # single-character tokens
    tkLeftParen, tkRightParen,
    tkLeftBrace, tkRightBrace,
    tkComma, tkDot, tkMinus, tkPlus,
    tkSemicolon, tkSlash, tkStar,
    # one or two character tokens
    tkBang, tkBangEqual,
    tkEqual, tkEqualEqual,
    tkGreater, tkGreaterEqual,
    tkLess, tkLessEqual,
    # literals
    tkIdent, tkString, tkNumber,
    # keywords
    tkAnd, tkClass, tkElse, tkFalse,
    tkFor, tkFun, tkIf, tkNil, tkOr,
    tkPrint, tkReturn, tkSuper, tkThis,
    tkTrue, tkVar, tkWhile
    # others
    tkError, tkEof

using s: Scanner

proc newScanner*(source: string): Scanner =
  new result
  result.source = source
  result.line = 1

proc isAtEnd(s; offset: int = 0): bool = s.current + offset >= len(s.source)

proc makeToken(s; tokType: TokType): Token =
  result.tokType = tokType
  result.lit = s.source[s.start ..< s.current]
  result.line = s.line

proc errorToken(s; message: string): Token =
  result.tokType = tkError
  result.lit = message
  result.line = s.line

proc peek(s; offset: int = 0): char =
  if s.isAtEnd(offset): '\0'
  else: s.source[s.current + offset]

proc advance(s): char =
  result = s.source[s.current]
  s.current += 1

proc skipWhitespace(s) =
  while true:
    case s.peek():
      of ' ', '\r', '\t': discard s.advance()
      of '\n':
        s.line += 1
        discard s.advance()
      of '/':
        if s.peek(1) == '/':
          while s.peek() != '\n' and not s.isAtEnd(): # a comment goes until the end of the line
            discard s.advance()
        else: return
      else: return

proc match(s; expected: char): bool =
  if s.isAtEnd(): return false
  if s.source[s.current] != expected: return false
  s.current += 1
  true

proc str(s): Token =
  while s.peek() != '"' and not s.isAtEnd():
    if s.peek() == '\n': s.line += 1
    discard s.advance()
  if s.isAtEnd(): return s.errorToken("Unterminated string.")
  discard s.advance() # closing quote
  s.makeToken(tkString)

proc isAlpha(c: char): bool = c in 'a'..'z' or c in 'A'..'Z' or c == '_'

proc isDigit(c: char): bool = c in '0'..'9'

proc identifierType(s): TokType = # not using a trie as the book does
  case s.source[s.start ..< s.current]:
  of "and": tkAnd
  of "class": tkClass
  of "else": tkElse
  of "if": tkIf
  of "nil": tkNil
  of "or": tkOr
  of "print": tkPrint
  of "return": tkReturn
  of "super": tkSuper
  of "var": tkVar
  of "while": tkWhile
  of "false": tkFalse
  of "for": tkFor
  of "fun": tkFun
  of "this": tkThis
  of "true": tkTrue
  else: tkIdent

proc identifier(s): Token =
  while isAlpha(s.peek()) or isDigit(s.peek()): discard s.advance()
  s.makeToken(s.identifierType())

proc number(s): Token =
  while isDigit(s.peek()): discard s.advance()
  if s.peek() == '.' and isDigit(s.peek(1)): # look for fractional part
    discard s.advance()
    while isDigit(s.peek()): discard s.advance()
  s.makeToken(tkNumber)

proc scanToken*(s): Token =
  skipWhitespace(s)
  s.start = s.current
  if s.isAtEnd(): return s.makeToken(tkEof)
  let c = s.advance()
  if isAlpha(c): return s.identifier()
  if isDigit(c): return s.number()
  case c:
    of '(': return s.makeToken(tkLeftParen)
    of ')': return s.makeToken(tkRightParen)
    of '{': return s.makeToken(tkLeftBrace)
    of '}': return s.makeToken(tkRightBrace)
    of ';': return s.makeToken(tkSemicolon)
    of ',': return s.makeToken(tkComma)
    of '.': return s.makeToken(tkDot)
    of '-': return s.makeToken(tkMinus)
    of '+': return s.makeToken(tkPlus)
    of '/': return s.makeToken(tkSlash)
    of '*': return s.makeToken(tkStar)
    of '!': return s.makeToken(if s.match('='): tkBangEqual else: tkBang)
    of '=': return s.makeToken(if s.match('='): tkEqualEqual else: tkEqual)
    of '<': return s.makeToken(if s.match('='): tkLessEqual else: tkLess)
    of '>': return s.makeToken(if s.match('='): tkGreaterEqual else: tkGreater)
    of '"': return s.str()
    else: discard
  return s.errorToken("Unexpected character.")
