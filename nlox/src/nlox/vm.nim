import std/[strformat, tables]
import chunk, value, types, compiler
when defined(debugTraceExecution):
  import debug

# pointer arithmetic
func `+`[T](p: ptr T, offset: SomeInteger): ptr T {.inline.} = cast[ptr T](cast[int](p) + offset.int * sizeof(T))
func `-`[T](p: ptr T, offset: SomeInteger): ptr T {.inline.} = cast[ptr T](cast[int](p) - offset.int * sizeof(T))
func `-`[T](p1, p2: ptr T): int {.inline.} = cast[int](p1) - cast[int](p2)
func `[]`[T](p: ptr T, address: SomeInteger): T = (p + address)[]
func `[]=`[T](p: ptr T, address: SomeInteger, value: T) = (p + address)[] = value

const
  framesMax = 64
  stackMax = 256 * framesMax

type
  VM = ref object
    frames: seq[CallFrame]
    stack: array[stackMax, Value]
    stackTop: ptr Value
    globals: Table[string, Value]

  CallFrame = object
    function: ObjFunction
    ip: ptr byte
    slots: ptr Value

  InterpretResult* = enum
    interpOk, interpCompileError, interpRuntimeError

proc stackBase(vm: VM): ptr Value = cast[ptr Value](addr(vm.stack))

proc resetStack(vm: VM) =
  vm.stackTop = vm.stackBase
  vm.frames.setLen(0)

proc newVM(): VM =
  new result
  result.resetStack()
  result.globals = initTable[string, Value]()

proc runtimeError(vm: VM, message: string): InterpretResult =
  stderr.writeLine(message)
  let instruction = vm.frames[^1].ip - addr(vm.frames[^1].function.chunk.code[0]) - 1
  let line = vm.frames[^1].function.chunk.lines[instruction]
  stderr.writeLine(fmt"[line {line}] in script")
  vm.resetStack()
  interpRuntimeError

proc readByte(vm: VM): byte =
  result = vm.frames[^1].ip[]
  vm.frames[^1].ip = vm.frames[^1].ip + 1

proc readShort(vm: VM): uint16 =
  result = vm.frames[^1].ip[].uint16 shl 8
  result = result or (vm.frames[^1].ip + 1)[]
  vm.frames[^1].ip = vm.frames[^1].ip + 2

proc readConstant(vm: VM): Value = vm.frames[^1].function.chunk.constants[vm.readByte()]

proc push(vm: VM, value: Value) =
  vm.stackTop[] = value
  vm.stackTop = vm.stackTop + 1

proc pop(vm: VM): Value =
  vm.stackTop = vm.stackTop - 1
  result = vm.stackTop[]

proc peek(vm: VM, distance: int): Value = (vm.stackTop - 1 - distance)[]

template binaryOp(vm: VM, operator: untyped): untyped =
  if not isNum(vm.peek(0)) or not isNum(vm.peek(1)):
    return vm.runtimeError("Operands must be numbers.")
  let b = vm.pop().number
  let a = vm.pop().number
  vm.push(operator(a, b))

proc concatenate(vm: VM) =
  let b = ObjString(vm.pop().obj).str
  let a = ObjString(vm.pop().obj).str
  vm.push(a & b)

proc isFalsey(val: Value): bool =
  val.valType == valNil or (val.valType == valBool and not val.boolean)

proc valuesEqual(a, b: Value): bool =
  if a.valType != b.valType: return false
  case a.valType
    of valBool: a.boolean == b.boolean
    of valNil: true
    of valNum: a.number == b.number
    of valObj:
      if a.obj.objType != b.obj.objType: return false
      case a.obj.objType
        of objStr: ObjString(a.obj).str == ObjString(b.obj).str
        of objFun: ObjFunction(a.obj) == ObjFunction(b.obj)

proc run(vm: VM): InterpretResult =
  while true:
    when defined(debugTraceExecution):
      stdout.write("          ")
      for idx, value in vm.stack:
        if vm.stackBase() + idx >= vm.stackTop: break
        stdout.write(fmt"[ {value} ]")
      echo ""
      discard disassembleInstruction(vm.frames[^1].function.chunk, vm.frames[^1].ip - addr(vm.frames[^1].function.chunk.code[0]))
    let instruction = OpCode(vm.readByte())
    case instruction
      of opConstant: vm.push(vm.readConstant())
      of opNil: vm.push(nilValue)
      of opTrue: vm.push(true.toValue())
      of opFalse: vm.push(false.toValue())
      of opPop: discard vm.pop()
      of opGetLocal: vm.push(vm.frames[^1].slots[vm.readByte()])
      of opSetLocal: vm.frames[^1].slots[vm.readByte()] = vm.peek(0)
      of opGetGlobal:
        let name = ObjString(vm.readConstant().obj).str
        if name in vm.globals: vm.push(vm.globals[name])
        else: return vm.runtimeError(fmt"Undefined variable '{name}'.")
      of opDefineGlobal:
        let name = ObjString(vm.readConstant().obj).str
        vm.globals[name] = vm.peek(0)
        discard vm.pop()
      of opSetGlobal:
        let name = ObjString(vm.readConstant().obj).str
        if name in vm.globals: vm.globals[name] = vm.peek(0)
        else: return vm.runtimeError(fmt"Undefined variable '{name}'.")
      of opEqual:
        let b = vm.pop()
        let a = vm.pop()
        vm.push(valuesEqual(a, b))
      of opGreater: vm.binaryOp(`>`)
      of opLess: vm.binaryOp(`<`)
      of opAdd:
        if isStr(vm.peek(0)) and isStr(vm.peek(1)): vm.concatenate()
        elif isNum(vm.peek(0)) and isNum(vm.peek(1)): vm.binaryOp(`+`)
        else: return vm.runtimeError("Operands must be two numbers or two strings.")
      of opSubtract: vm.binaryOp(`-`)
      of opMultiply: vm.binaryOp(`*`)
      of opDivide: vm.binaryOp(`/`)
      of opNot: vm.push(vm.pop().isFalsey())
      of opNegate:
        if not isNum(vm.peek(0)): return vm.runtimeError("Operand must be a number.")
        vm.push(-vm.pop().number)
      of opPrint: echo vm.pop()
      of opJump: vm.frames[^1].ip = vm.frames[^1].ip + vm.readShort()
      of opJumpIfFalse:
        let jumpDistance = vm.readShort()
        if isFalsey(vm.peek(0)): vm.frames[^1].ip = vm.frames[^1].ip + jumpDistance
      of opLoop: vm.frames[^1].ip = vm.frames[^1].ip - vm.readShort()
      of opReturn: return interpOk

proc interpret*(source: string): InterpretResult =
  let fun = compile(source)
  if fun == nil: return interpCompileError
  let vm = newVM()
  vm.push(fun)
  vm.frames.add(CallFrame(function: fun, ip: unsafeAddr fun.chunk.code[0], slots: addr vm.stack[0]))
  vm.run()
