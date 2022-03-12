import std/strformat
import types, chunk

let nilValue* = Value(valType: valNil)
converter toValue*(b: bool): Value = Value(valType: valBool, boolean: b)
converter toValue*(f: float): Value = Value(valType: valNum, number: f)
converter toValue*(o: Obj): Value = Value(valType: valObj, obj: o)
converter toValue*(s: string): Value = ObjString(objType: objStr, str: s)

proc newFunction*(arity: int, name: string): Obj =
  ObjFunction(objType: objFun, arity: arity, chunk: newChunk(), name: name)

proc isBool*(value: Value): bool = value.valType == valBool
proc isNil*(value: Value): bool = value.valType == valNil
proc isNum*(value: Value): bool = value.valType == valNum
proc isObj*(value: Value): bool = value.valType == valObj
proc isObjType(value: Value, objType: ObjectType): bool = isObj(value) and value.obj.objType == objType
proc isStr*(value: Value): bool = isObjType(value, objStr)
proc isFun*(value: Value): bool = isObjType(value, objFun)

proc `$`*(value: Value): string =
  case value.valType
    of valBool: $value.boolean
    of valNil: "nil"
    of valNum: fmt"{value.number:g}"
    of valObj:
      case value.obj.objType
        of objStr: ObjString(value.obj).str
        of objFun:
          let fun = ObjFunction(value.obj)
          fmt"<fn {fun.name}:{fun.arity}>"

proc printValue*(value: Value) =
  stdout.write(value)
