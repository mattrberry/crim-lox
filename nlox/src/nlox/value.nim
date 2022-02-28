import std/strformat

type
  Value* = float

proc printValue*(value: Value) =
  stdout.write(fmt"{value:g}")
