

type
  ValueType* = enum
    valBool, valNil, valNum, valObj

  Value* = object
    case valType*: ValueType
    of valBool: boolean*: bool
    of valNil: discard
    of valNum: number*: float
    of valObj: obj*: Obj

  ObjectType* = enum
    objStr, objFun

  Obj* = ref object of RootObj
    objType*: ObjectType

  ObjString* = ref object of Obj
    str*: string

  ObjFunction* = ref object of Obj
    arity*: int
    chunk*: Chunk
    name*: string

  Chunk* = ref object
    code*: seq[byte]
    lines*: seq[int]
    constants*: seq[Value]
