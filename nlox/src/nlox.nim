import nlox/[chunk, debug]

when isMainModule:
  let mychunk = newChunk()
  let constant = addConstant(myChunk, 1.2)
  writeChunk(myChunk, OpCode.opConstant, 123)
  writeChunk(myChunk, constant.byte, 123)
  writeChunk(mychunk, OpCode.opReturn, 123)
  disassembleChunk(mychunk, "test chunk")
