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

proc `$`*(value: Value): string =
  case value.valType
    of valBool: $value.boolean
    of valNil: "nil"
    of valNum: fmt"{value.number:g}"

proc printValue*(value: Value) =
  stdout.write(value)
