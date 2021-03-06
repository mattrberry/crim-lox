import types

type
  OpCode* {.size: 1.} = enum
    opConstant, # byte2: constant index
    opNil,
    opTrue,
    opFalse,
    opPop,
    opGetLocal,
    opSetLocal,
    opGetGlobal,
    opDefineGlobal,
    opSetGlobal,
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
    opJump,
    opJumpIfFalse,
    opLoop,
    opCall,
    opReturn

converter toByte*(opcode: OpCode): byte = cast[byte](opcode)

proc newChunk*(): Chunk =
  new result

proc writeChunk*(chunk: Chunk, value: byte, line: int) =
  chunk.code.add(value)
  chunk.lines.add(line)

proc addConstant*(chunk: Chunk, value: Value): int =
  result = len(chunk.constants)
  chunk.constants.add(value)
