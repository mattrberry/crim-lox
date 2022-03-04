import std/strformat
import chunk, value, compiler
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

  InterpretResult* = enum
    interpOk, interpCompileError, interpRuntimeError

proc stackBase(vm: VM): ptr Value = cast[ptr Value](addr(vm.stack))

proc resetStack(vm: VM) =
  vm.stackTop = vm.stackBase

proc newVM(): VM =
  new result
  result.resetStack()

let vm = newVM()

proc runtimeError(message: string) =
  stderr.writeLine(message)
  let instruction = vm.ip - addr(vm.chunk.code[0]) - 1
  let line = vm.chunk.lines[instruction]
  stderr.writeLine(fmt"[line {line}] in script")
  vm.resetStack()

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

proc peek(distance: int): Value = (vm.stackTop - 1 - distance)[]

template binaryOp(operator: untyped): untyped =
  if not isNum(peek(0)) or not isNum(peek(1)):
    runtimeError("Operands must be numbers.")
    return interpRuntimeError
  let b = pop().number
  let a = pop().number
  push(operator(a, b))

proc isFalsey(val: Value): bool =
  val.valType == valNil or (val.valType == valBool and not val.boolean)

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
      of opNil: push(nilValue)
      of opTrue: push(true.toValue())
      of opFalse: push(false.toValue())
      of opAdd: binaryOp(`+`)
      of opSubtract: binaryOp(`-`)
      of opMultiply: binaryOp(`*`)
      of opDivide: binaryOp(`/`)
      of opNot: push(pop().isFalsey())
      of opNegate:
        if not isNum(peek(0)):
          runtimeError("Operand must be a number.")
          return interpRuntimeError
        push(-pop().number)
      of opReturn:
        printValue(pop())
        echo ""
        return interpOk

proc interpret*(chunk: Chunk): InterpretResult =
  vm.chunk = chunk
  vm.ip = addr(vm.chunk.code[0])
  run()

proc interpret*(source: string): InterpretResult =
  let chunk = newChunk()
  if not compile(source, chunk): return interpCompileError
  interpret(chunk)
