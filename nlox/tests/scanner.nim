import unittest

import ../src/nlox/scanner

suite "scanner":
  test "scans empty files":
    let s = newScanner("")
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "scans unrecognized tokens":
    let s = newScanner(r"?\|")
    check(s.scanToken() == Token(tokType: tkError, lit: "Unexpected character.", line: 1))
    check(s.scanToken() == Token(tokType: tkError, lit: "Unexpected character.", line: 1))
    check(s.scanToken() == Token(tokType: tkError, lit: "Unexpected character.", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "scans single-character tokens":
    let s = newScanner("(){},.-+;/*")
    check(s.scanToken() == Token(tokType: tkLeftParen, lit: "(", line: 1))
    check(s.scanToken() == Token(tokType: tkRightParen, lit: ")", line: 1))
    check(s.scanToken() == Token(tokType: tkLeftBrace, lit: "{", line: 1))
    check(s.scanToken() == Token(tokType: tkRightBrace, lit: "}", line: 1))
    check(s.scanToken() == Token(tokType: tkComma, lit: ",", line: 1))
    check(s.scanToken() == Token(tokType: tkDot, lit: ".", line: 1))
    check(s.scanToken() == Token(tokType: tkMinus, lit: "-", line: 1))
    check(s.scanToken() == Token(tokType: tkPlus, lit: "+", line: 1))
    check(s.scanToken() == Token(tokType: tkSemicolon, lit: ";", line: 1))
    check(s.scanToken() == Token(tokType: tkSlash, lit: "/", line: 1))
    check(s.scanToken() == Token(tokType: tkStar, lit: "*", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "scans comments":
    var s = newScanner("// comment here")
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))
    s = newScanner("(// comment here")
    check(s.scanToken() == Token(tokType: tkLeftParen, lit: "(", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "ignores whitespace":
    let s = newScanner(" \r\t + \t\r ")
    check(s.scanToken() == Token(tokType: tkPlus, lit: "+", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "increments line on newlines":
    var s = newScanner("\n")
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 2))
    s = newScanner("\n.\n")
    check(s.scanToken() == Token(tokType: tkDot, lit: ".", line: 2))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 3))

  test "scans one or two character tokens":
    let s = newScanner("! != = == > >= < <=")
    check(s.scanToken() == Token(tokType: tkBang, lit: "!", line: 1))
    check(s.scanToken() == Token(tokType: tkBangEqual, lit: "!=", line: 1))
    check(s.scanToken() == Token(tokType: tkEqual, lit: "=", line: 1))
    check(s.scanToken() == Token(tokType: tkEqualEqual, lit: "==", line: 1))
    check(s.scanToken() == Token(tokType: tkGreater, lit: ">", line: 1))
    check(s.scanToken() == Token(tokType: tkGreaterEqual, lit: ">=", line: 1))
    check(s.scanToken() == Token(tokType: tkLess, lit: "<", line: 1))
    check(s.scanToken() == Token(tokType: tkLessEqual, lit: "<=", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "scans strings":
    let s = newScanner("\"this is a string\" \"\n multiline \n string \n\"")
    check(s.scanToken() == Token(tokType: tkString, lit: "\"this is a string\"", line: 1))
    check(s.scanToken() == Token(tokType: tkString, lit: "\"\n multiline \n string \n\"", line: 4))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 4))
  
  test "scans numbers":
    let s = newScanner("1 12 1.2 11.22")
    check(s.scanToken() == Token(tokType: tkNumber, lit: "1", line: 1))
    check(s.scanToken() == Token(tokType: tkNumber, lit: "12", line: 1))
    check(s.scanToken() == Token(tokType: tkNumber, lit: "1.2", line: 1))
    check(s.scanToken() == Token(tokType: tkNumber, lit: "11.22", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "scans identifiers":
    let s = newScanner("id foo bar Class And")
    check(s.scanToken() == Token(tokType: tkIdent, lit: "id", line: 1))
    check(s.scanToken() == Token(tokType: tkIdent, lit: "foo", line: 1))
    check(s.scanToken() == Token(tokType: tkIdent, lit: "bar", line: 1))
    check(s.scanToken() == Token(tokType: tkIdent, lit: "Class", line: 1))
    check(s.scanToken() == Token(tokType: tkIdent, lit: "And", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "scans keywords":
    let s = newScanner("and class else false fun for if nil or print return super this true var while")
    check(s.scanToken() == Token(tokType: tkAnd, lit: "and", line: 1))
    check(s.scanToken() == Token(tokType: tkClass, lit: "class", line: 1))
    check(s.scanToken() == Token(tokType: tkElse, lit: "else", line: 1))
    check(s.scanToken() == Token(tokType: tkFalse, lit: "false", line: 1))
    check(s.scanToken() == Token(tokType: tkFun, lit: "fun", line: 1))
    check(s.scanToken() == Token(tokType: tkFor, lit: "for", line: 1))
    check(s.scanToken() == Token(tokType: tkIf, lit: "if", line: 1))
    check(s.scanToken() == Token(tokType: tkNil, lit: "nil", line: 1))
    check(s.scanToken() == Token(tokType: tkOr, lit: "or", line: 1))
    check(s.scanToken() == Token(tokType: tkPrint, lit: "print", line: 1))
    check(s.scanToken() == Token(tokType: tkReturn, lit: "return", line: 1))
    check(s.scanToken() == Token(tokType: tkSuper, lit: "super", line: 1))
    check(s.scanToken() == Token(tokType: tkThis, lit: "this", line: 1))
    check(s.scanToken() == Token(tokType: tkTrue, lit: "true", line: 1))
    check(s.scanToken() == Token(tokType: tkVar, lit: "var", line: 1))
    check(s.scanToken() == Token(tokType: tkWhile, lit: "while", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))

  test "matches maximal characters on keywords":
    let s = newScanner("_and and_ anda aand")
    check(s.scanToken() == Token(tokType: tkIdent, lit: "_and", line: 1))
    check(s.scanToken() == Token(tokType: tkIdent, lit: "and_", line: 1))
    check(s.scanToken() == Token(tokType: tkIdent, lit: "anda", line: 1))
    check(s.scanToken() == Token(tokType: tkIdent, lit: "aand", line: 1))
    check(s.scanToken() == Token(tokType: tkEof, lit: "", line: 1))
