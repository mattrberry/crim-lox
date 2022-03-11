

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
    objStr

  Obj* = ref object
    case objType*: ObjectType
    of objStr: str*: string

  Chunk* = ref object
    code*: seq[byte]
    lines*: seq[int]
    constants*: seq[Value]
