import os
import nlox/vm

proc repl() =
  while true:
    stdout.write("> ")
    let line = stdin.readLine()
    discard interpret(line)

proc runFile(file: string) =
  let
    source = readFile(file) # assumes file exists and can be read
    result = interpret(source)
  if result == InterpretResult.interpCompileError: quit(65)
  if result == InterpretResult.interpRuntimeError: quit(70)

when isMainModule:
  case paramCount():
  of 0: repl()
  of 1: runFile(paramStr(1))
  else: quit("Usage: nlox [path]", 42)
