import std/[strformat, tables]
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
    globals: Table[string, Value]

  InterpretResult* = enum
    interpOk, interpCompileError, interpRuntimeError

proc stackBase(vm: VM): ptr Value = cast[ptr Value](addr(vm.stack))

proc resetStack(vm: VM) =
  vm.stackTop = vm.stackBase

proc newVM(): VM =
  new result
  result.resetStack()
  result.globals = initTable[string, Value]()

let vm = newVM()

proc runtimeError(message: string): InterpretResult =
  stderr.writeLine(message)
  let instruction = vm.ip - addr(vm.chunk.code[0]) - 1
  let line = vm.chunk.lines[instruction]
  stderr.writeLine(fmt"[line {line}] in script")
  vm.resetStack()
  interpRuntimeError

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
    return runtimeError("Operands must be numbers.")
  let b = pop().number
  let a = pop().number
  push(operator(a, b))

proc concatenate() =
  let b = pop().obj.str
  let a = pop().obj.str
  push(a & b)

proc isFalsey(val: Value): bool =
  val.valType == valNil or (val.valType == valBool and not val.boolean)

proc valuesEqual(a, b: Value): bool =
  if a.valType != b.valType: return false
  case a.valType
    of valBool: a.boolean == b.boolean
    of valNil: true
    of valNum: a.number == b.number
    of valObj: a.obj.str == b.obj.str

proc run(): InterpretResult =
  while true:
    when defined(debugTraceExecution):
      stdout.write("          ")
      for idx, value in vm.stack:
        if vm.stackBase() + idx >= vm.stackTop: break
        stdout.write(fmt"[ {value} ]")
      echo ""
      discard disassembleInstruction(vm.chunk, vm.ip - addr(vm.chunk.code[0]))
    let instruction = OpCode(readByte())
    case instruction
      of opConstant: push(readConstant())
      of opNil: push(nilValue)
      of opTrue: push(true.toValue())
      of opFalse: push(false.toValue())
      of opPop: discard pop()
      of opGetGlobal:
        let name = readConstant().obj.str
        if name in vm.globals: push(vm.globals[name])
        else: return runtimeError(fmt"Undefined variable '{name}'.")
      of opDefineGlobal:
        let name = readConstant().obj.str
        vm.globals[name] = peek(0)
        discard pop()
      of opSetGlobal:
        let name = readConstant().obj.str
        if name in vm.globals: vm.globals[name] = peek(0)
        else: return runtimeError(fmt"Undefined variable '{name}'.")
      of opEqual:
        let b = pop()
        let a = pop()
        push(valuesEqual(a, b))
      of opGreater: binaryOp(`>`)
      of opLess: binaryOp(`<`)
      of opAdd:
        if isStr(peek(0)) and isStr(peek(1)): concatenate()
        elif isNum(peek(0)) and isNum(peek(1)): binaryOp(`+`)
        else: return runtimeError("Operands must be two numbers or two strings.")
      of opSubtract: binaryOp(`-`)
      of opMultiply: binaryOp(`*`)
      of opDivide: binaryOp(`/`)
      of opNot: push(pop().isFalsey())
      of opNegate:
        if not isNum(peek(0)): return runtimeError("Operand must be a number.")
        push(-pop().number)
      of opPrint: echo pop()
      of opReturn: return interpOk

proc interpret*(chunk: Chunk): InterpretResult =
  vm.chunk = chunk
  vm.ip = addr(vm.chunk.code[0])
  run()

proc interpret*(source: string): InterpretResult =
  let chunk = newChunk()
  if not compile(source, chunk): return interpCompileError
  interpret(chunk)
