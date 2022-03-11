import std/strformat
import types

let nilValue* = Value(valType: valNil)
converter toValue*(b: bool): Value = Value(valType: valBool, boolean: b)
converter toValue*(f: float): Value = Value(valType: valNum, number: f)
converter toValue*(o: Obj): Value = Value(valType: valObj, obj: o)
converter toValue*(s: string): Value = Obj(objType: objStr, str: s)

proc isBool*(value: Value): bool = value.valType == valBool
proc isNil*(value: Value): bool = value.valType == valNil
proc isNum*(value: Value): bool = value.valType == valNum
proc isObj*(value: Value): bool = value.valType == valObj
proc isObjType(value: Value, objType: ObjectType): bool = isObj(value) and value.obj.objType == objType
proc isStr*(value: Value): bool = isObjType(value, objStr)

proc `$`*(value: Value): string =
  case value.valType
    of valBool: $value.boolean
    of valNil: "nil"
    of valNum: fmt"{value.number:g}"
    of valObj:
      case value.obj.objType
        of objStr: value.obj.str

proc printValue*(value: Value) =
  stdout.write(value)
