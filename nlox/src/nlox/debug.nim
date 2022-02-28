import std/strformat
import chunk

proc constantInstruction(name: string, chunk: Chunk, offset: int): int =
  let constant_idx = chunk.code[offset + 1]
  echo fmt"{name:16} {constant_idx:4} '{chunk.constants[constant_idx]}'"
  result = offset + 2

proc simpleInstruction(name: string, offset: int): int =
  echo name
  result = offset + 1

proc disassembleInstruction*(chunk: Chunk, offset: int): int =
  stdout.write(fmt"{offset:04} ")
  if offset > 0 and chunk.lines[offset] == chunk.lines[offset - 1]:
    stdout.write("   | ")
  else:
    stdout.write(fmt"{chunk.lines[offset]:4} ")
  let instr = chunk.code[offset]
  result = case OpCode(instr): # note: this assumes a valid opcode
    of opConstant: constantInstruction("OP_CONSTANT", chunk, offset)
    of opAdd: simpleInstruction("OP_ADD", offset)
    of opSubtract: simpleInstruction("OP_SUBTRACT", offset)
    of opMultiply: simpleInstruction("OP_MULTIPLY", offset)
    of opDivide: simpleInstruction("OP_DIVIDE", offset)
    of opNegate: simpleInstruction("OP_NEGATE", offset)
    of opReturn: simpleInstruction("OP_RETURN", offset)

proc disassembleChunk*(chunk: Chunk, name: string) =
  echo fmt"== {name} =="
  var offset = 0
  while offset < len(chunk.code):
    offset = disassembleInstruction(chunk, offset)
