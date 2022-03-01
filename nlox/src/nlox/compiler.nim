import std/strformat
import scanner

proc compile*(source: string) =
  let scanner = newScanner(source)
  var line = -1
  while true:
    let token = scanner.scanToken()
    if token.line != line:
      stdout.write(fmt"{token.line:4} ")
      line = token.line
    else:
      stdout.write("   | ")
    echo fmt"{token.tokType:14} '{token.lit}'"
    if token.tokType == tkEof: break
