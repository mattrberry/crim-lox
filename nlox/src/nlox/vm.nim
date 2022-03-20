import std/[strformat, tables, decls]
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

proc newVM*(): VM =
  new result
  result.resetStack()
  result.globals = initTable[string, Value]()

proc runtimeError(vm: VM, message: string): InterpretResult =
  stderr.writeLine(message)
  for i in countdown(high(vm.frames), 0):
    let
      frame = vm.frames[i]
      function = frame.function
      instruction = frame.ip - addr(function.chunk.code[0]) - 1
      line = function.chunk.lines[instruction]
      funName = if function.name == "": "script"
                else: fmt"{function.name}()"
    stderr.writeLine(fmt"[line {line}] in {funName}")
  vm.resetStack()
  interpRuntimeError

proc readByte(frame: var CallFrame): byte =
  result = frame.ip[]
  frame.ip = frame.ip + 1

proc readShort(frame: var CallFrame): uint16 =
  result = frame.ip[].uint16 shl 8
  result = result or (frame.ip + 1)[]
  frame.ip = frame.ip + 2

proc readConstant(frame: var CallFrame): Value = frame.function.chunk.constants[frame.readByte()]

proc push(vm: VM, value: Value) =
  vm.stackTop[] = value
  vm.stackTop = vm.stackTop + 1

proc pop(vm: VM): Value =
  vm.stackTop = vm.stackTop - 1
  result = vm.stackTop[]

proc peek(vm: VM, distance: SomeInteger): Value = (vm.stackTop - 1 - distance)[]

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

proc call(vm: VM, function: ObjFunction, argCount: SomeInteger): bool =
  if argCount.int != function.arity:
    discard vm.runtimeError(fmt"Expected {function.arity} arguments but got {argCount}.")
  elif len(vm.frames) == framesMax:
    discard vm.runtimeError("Stack overflow.")
  else:
    result = true
    vm.frames.add(
      CallFrame(
        function: function,
        ip: addr(function.chunk.code[0]),
        slots: vm.stackTop - argCount - 1
      )
    )

proc callValue(vm: VM, callee: Value, argCount: SomeInteger): bool =
  if isObj(callee):
    case callee.obj.objType
    of objFun: return vm.call(ObjFunction(callee.obj), argCount)
    else: discard # non-callable object
  discard vm.runtimeError("Can only call functions and classes.")

proc run(vm: VM): InterpretResult =
  while true:
    var frame {.byAddr.} = vm.frames[^1]
    when defined(debugTraceExecution):
      stdout.write("          ")
      for idx, value in vm.stack:
        if vm.stackBase() + idx >= vm.stackTop: break
        stdout.write(fmt"[ {value} ]")
      echo ""
      discard disassembleInstruction(frame.function.chunk, frame.ip - addr(frame.function.chunk.code[0]))
    let instruction = OpCode(frame.readByte())
    case instruction
      of opConstant: vm.push(frame.readConstant())
      of opNil: vm.push(nilValue)
      of opTrue: vm.push(true.toValue())
      of opFalse: vm.push(false.toValue())
      of opPop: discard vm.pop()
      of opGetLocal: vm.push(frame.slots[frame.readByte()])
      of opSetLocal: frame.slots[frame.readByte()] = vm.peek(0)
      of opGetGlobal:
        let name = ObjString(frame.readConstant().obj).str
        if name in vm.globals: vm.push(vm.globals[name])
        else: return vm.runtimeError(fmt"Undefined variable '{name}'.")
      of opDefineGlobal:
        let name = ObjString(frame.readConstant().obj).str
        vm.globals[name] = vm.peek(0)
        discard vm.pop()
      of opSetGlobal:
        let name = ObjString(frame.readConstant().obj).str
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
      of opJump: frame.ip = frame.ip + frame.readShort()
      of opJumpIfFalse:
        let jumpDistance = frame.readShort()
        if isFalsey(vm.peek(0)): frame.ip = frame.ip + jumpDistance
      of opLoop: frame.ip = frame.ip - frame.readShort()
      of opCall:
        let argCount = frame.readByte()
        if not vm.callValue(vm.peek(argCount), argCount):
          return interpRuntimeError
      of opReturn:
        let resultValue = vm.pop() # capture return value
        let frame = vm.frames.pop() # drop last call frame
        if len(vm.frames) == 0: # exit vm loop if returning from top-level script
          discard vm.pop()
          return interpOk
        vm.stackTop = frame.slots # pop all slots used by caller
        vm.push(resultValue) # push return value back to stack

proc interpret*(vm: VM, source: string): InterpretResult =
  let function = compile(source)
  if function == nil: return interpCompileError
  vm.push(function)
  discard vm.call(function, 0) # set up stack frame for top-level script
  vm.run()
