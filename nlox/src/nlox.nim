import nlox/[chunk, debug, vm]

when isMainModule:
  let mychunk = newChunk()

  var constant = addConstant(myChunk, 1.2)
  writeChunk(myChunk, OpCode.opConstant, 123)
  writeChunk(myChunk, constant.byte, 123)

  constant = addConstant(myChunk, 3.4)
  writeChunk(myChunk, OpCode.opConstant, 123)
  writeChunk(myChunk, constant.byte, 123)

  writeChunk(myChunk, OpCode.opAdd, 123)

  constant = addConstant(myChunk, 5.6)
  writeChunk(myChunk, OpCode.opConstant, 123)
  writeChunk(myChunk, constant.byte, 123)

  writeChunk(myChunk, OpCode.opDivide, 123)

  writeChunk(myChunk, OpCode.opNegate, 123)

  writeChunk(mychunk, OpCode.opReturn, 123)

  disassembleChunk(mychunk, "test chunk")

  discard interpret(myChunk)
