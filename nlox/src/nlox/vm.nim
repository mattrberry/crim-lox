import chunk, value
when defined(debugTraceExecution):
  import debug

# pointer arithmetic
func `+`[T](p: ptr T, offset: int): ptr T {.inline.} = cast[ptr T](cast[int](p) + offset * sizeof(T))
func `-`[T](p: ptr T, offset: int): ptr T {.inline.} = cast[ptr T](cast[int](p) - offset * sizeof(T))
func `-`[T](p1, p2: ptr T): int {.inline.} = cast[int](p1) - cast[int](p2)

const stackMax = 256

type
  VM = ref object
    chunk: Chunk
    ip: ptr byte
    stack: array[stackMax, Value]
    stackTop: ptr Value

  InterpretResult = enum
    interpOk, interpCompileError, interpRuntimeError

proc stackBase(vm: VM): ptr Value = cast[ptr Value](addr(vm.stack))

proc newVM(): VM =
  new result
  result.stackTop = result.stackBase()

let vm = newVM()

proc readByte(): byte =
  result = vm.ip[]
  vm.ip = vm.ip + 1

proc readConstant(): Value = vm.chunk.constants[readByte()]

proc push(value: Value) =
  vm.stackTop[] = value
  vm.stackTop = vm.stackTop + 1

proc pop(): Value =
  vm.stackTop = vm.stackTop - 1
  result = vm.stackTop[]

template binaryOp(operator: untyped): untyped =
  let
    b = pop()
    a = pop()
  push(operator(a, b))

proc run(): InterpretResult =
  while true:
    when defined(debugTraceExecution):
      stdout.write("          ")
      for idx, value in vm.stack:
        if vm.stackBase() + idx >= vm.stackTop: break
        stdout.write("[ ")
        printValue(value)
        stdout.write(" ]")
      echo ""
      discard disassembleInstruction(vm.chunk, vm.ip - addr(vm.chunk.code[0]))
    let instruction = OpCode(readByte())
    case instruction
      of opConstant:
        let constant = readConstant()
        push(constant)
      of opAdd: binaryOp(`+`)
      of opSubtract: binaryOp(`-`)
      of opMultiply: binaryOp(`*`)
      of opDivide: binaryOp(`/`)
      of opNegate: push(-pop())
      of opReturn:
        printValue(pop())
        echo ""
        return Interpretresult.interpOk

proc interpret*(chunk: Chunk): InterpretResult =
  vm.chunk = chunk
  vm.ip = addr(vm.chunk.code[0])
  run()
