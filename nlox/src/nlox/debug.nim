import std/strformat
import chunk, value

proc constantInstruction(name: string, chunk: Chunk, offset: int): int =
  let constantIdx = chunk.code[offset + 1]
  echo fmt"{name:16} {constantIdx:4} '{chunk.constants[constantIdx]}'"
  result = offset + 2

proc simpleInstruction(name: string, offset: int): int =
  echo name
  result = offset + 1

proc byteInstruction(name: string, chunk: Chunk, offset: int): int =
  let slotIdx = chunk.code[offset + 1]
  echo fmt"{name:16} {slotIdx:4}"
  result = offset + 2

proc jumpInstruction(name: string, sign: int, chunk: Chunk, offset: int): int =
  let jumpDistance = (chunk.code[offset + 1].uint16 shl 8) or chunk.code[offset + 2].uint16
  echo fmt"{name:16} {offset:4} -> {offset + 3 + sign * jumpDistance.int}"
  result = offset + 3

proc disassembleInstruction*(chunk: Chunk, offset: int): int =
  stdout.write(fmt"{offset:04} ")
  if offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]:
    stdout.write("   | ")
  else:
    stdout.write(fmt"{chunk.lines[offset]:4} ")
  let instr = chunk.code[offset]
  result = case OpCode(instr) # note: this assumes a valid opcode
    of opConstant: constantInstruction("OP_CONSTANT", chunk, offset)
    of opNil: simpleInstruction("OP_NIL", offset)
    of opTrue: simpleInstruction("OP_TRUE", offset)
    of opFalse: simpleInstruction("OP_FALSE", offset)
    of opPop: simpleInstruction("OP_POP", offset)
    of opGetLocal: byteInstruction("OP_GET_LOCAL", chunk, offset)
    of opSetLocal: byteInstruction("OP_SET_LOCAL", chunk, offset)
    of opGetGlobal: constantInstruction("OP_GET_GLOBAL", chunk, offset)
    of opDefineGlobal: constantInstruction("OP_DEFINE_GLOBAL", chunk, offset)
    of opSetGlobal: constantInstruction("OP_SET_GLOBAL", chunk, offset)
    of opEqual: simpleInstruction("OP_EQUAL", offset)
    of opGreater: simpleInstruction("OP_GREATER", offset)
    of opLess: simpleInstruction("OP_LESS", offset)
    of opAdd: simpleInstruction("OP_ADD", offset)
    of opSubtract: simpleInstruction("OP_SUBTRACT", offset)
    of opMultiply: simpleInstruction("OP_MULTIPLY", offset)
    of opDivide: simpleInstruction("OP_DIVIDE", offset)
    of opNot: simpleInstruction("OP_NOT", offset)
    of opNegate: simpleInstruction("OP_NEGATE", offset)
    of opPrint: simpleInstruction("OP_PRINT", offset)
    of opJump: jumpInstruction("OP_JUMP", 1, chunk, offset)
    of opJumpIfFalse: jumpInstruction("OP_JUMP_IF_FALSE", 1, chunk, offset)
    of opLoop: jumpInstruction("OP_LOOP", -1, chunk, offset)
    of opReturn: simpleInstruction("OP_RETURN", offset)

proc disassembleChunk*(chunk: Chunk, name: string) =
  echo fmt"== {name} =="
  var offset = 0
  while offset < len(chunk.code):
    offset = disassembleInstruction(chunk, offset)
