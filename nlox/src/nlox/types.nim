

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
    objStr, objFun, objNative

  Obj* = ref object of RootObj
    objType*: ObjectType

  ObjString* = ref object of Obj
    str*: string

  ObjFunction* = ref object of Obj
    arity*: int
    chunk*: Chunk
    name*: string

  ObjNative* = ref object of Obj
    function*: NativeFn

  NativeFn* = proc(argCount: int, args: ptr Value): Value

  Chunk* = ref object
    code*: seq[byte]
    lines*: seq[int]
    constants*: seq[Value]
