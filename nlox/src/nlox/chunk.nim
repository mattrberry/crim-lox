import value

type
  OpCode* {.size: 1.} = enum
    opConstant, # byte2: constant index
    opNil,
    opTrue,
    opFalse,
    opPop,
    opGetGlobal,
    opDefineGlobal,
    opEqual,
    opGreater,
    opLess,
    opAdd,
    opSubtract,
    opMultiply,
    opDivide,
    opNot,
    opNegate,
    opPrint,
    opReturn

  Chunk* = ref object
    code*: seq[byte]
    lines*: seq[int]
    constants*: seq[Value]

converter toByte(opcode: OpCode): byte = cast[byte](opcode)

proc newChunk*(): Chunk =
  new result

proc writeChunk*(chunk: Chunk, value: byte, line: int) =
  chunk.code.add(value)
  chunk.lines.add(line)

proc addConstant*(chunk: Chunk, value: Value): int =
  result = len(chunk.constants)
  chunk.constants.add(value)
