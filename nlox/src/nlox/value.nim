import std/strformat

type
  ValueType* = enum
    valBool, valNil, valNum

  Value* = object
    case valType*: ValueType
    of valBool: boolean*: bool
    of valNum: number*: float
    else: discard

const nilValue* = Value(valType: valNil)
converter toValue*(b: bool): Value = Value(valType: valBool, boolean: b)
converter toValue*(f: float): Value = Value(valType: valNum, number: f)

proc isBool*(value: Value): bool = value.valType == valBool
proc isNil*(value: Value): bool = value.valType == valNil
proc isNum*(value: Value): bool = value.valType == valNum

proc printValue*(value: Value) =
  case value.valType
    of valBool: stdout.write(value.boolean)
    of valNil: stdout.write("nil")
    of valNum: stdout.write(fmt"{value.number:g}")
