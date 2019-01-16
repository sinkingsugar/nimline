{.experimental.}

import macros, tables, strutils, ospaths

type
  CppProxy* {.nodecl.} = object
  CppObject* = concept type T
    T.isCppObject

when defined(js):
  type WasmPtr* = distinct int
else:
  # linux gprof utility define
  when defined(linux) and defined(gprof):
    {.passC: "-pg".}
    {.passL: "-pg".}

  # compiler utilities
  macro cppdefines*(defines: varargs[string]): untyped =
    result = nnkStmtList.newTree()
    
    for adefine in defines:
      var str: string
      when defined(windows) and defined(vcc):
        str = "/D" & $adefine
      else:
        str = "-D" & $adefine
        
      result.add nnkPragma.newTree(nnkExprColonExpr.newTree(newIdentNode("passC"), newLit(str)))
      
  macro cppincludes*(includes: varargs[string]): untyped =
    result = nnkStmtList.newTree()
    
    for incl in includes:
      var str: string
      when defined windows:
        let win_incl = ($incl).replace("/", "\\").quoteShell
        when defined vcc:
          str = "/I" & win_incl
        else:
          str = "-I" & win_incl
      else:
        str = "-I" & $incl
      
      result.add nnkPragma.newTree(nnkExprColonExpr.newTree(newIdentNode("passC"), newLit(str)))
      
  macro cppfiles*(files: varargs[string]): untyped =
    result = nnkStmtList.newTree()
    
    for file in files:
      var str: string
      when defined windows:
        let win_incl = ($file).replace("/", "\\") .quoteShell
        str = win_incl
      else:
        str = $file
      
      result.add nnkPragma.newTree(nnkExprColonExpr.newTree(newIdentNode("compile"), newLit(str)))
      
  macro cpplibpaths*(paths: varargs[string]): untyped =
    result = nnkStmtList.newTree()
    
    for path in paths:
      var str: string
      when defined windows:
        let win_path = ($path).replace("/", "\\").quoteShell
        when defined vcc:
          str = "/LIBPATH:" & win_path
        else:
          str = "-L" & win_path
      else:
        str = "-L" & $path
      
      result.add nnkPragma.newTree(nnkExprColonExpr.newTree(newIdentNode("passL"), newLit(str)))
      
  macro cpplibs*(libs: varargs[string]): untyped =
    result = nnkStmtList.newTree()
    
    for lib in libs:
      var str: string
      when defined windows:
        let win_incl = ($lib).replace("/", "\\").quoteShell
        when defined vcc:
          str = win_incl
        else:
          str = "-l" & win_incl
      else:
        str = "-l" & $lib
      
      result.add nnkPragma.newTree(nnkExprColonExpr.newTree(newIdentNode("passL"), newLit(str)))

type CppGlobalType* = object
proc isCppObject*(T: typedesc[CppGlobalType]): bool = true
var global* {.nodecl.}: CppGlobalType
const CppGlobalName = "global"

const
  setImpl = "#[#] = #"
  getImpl = "#[#]"

macro defineCppType*(name: untyped, importCppStr: string, headerStr: string = ""): untyped =
  result = nnkStmtList.newTree()

  result.add quote do:
    type `name`* {.header: "", importcpp: "", inheritable.} = object

  if headerStr != nil:
    # replace empty string with proper values
    result[0][0][0][1][0][1] = newStrLitNode($headerStr)
    result[0][0][0][1][1][1] = newStrLitNode($importCppStr)
  else:
    # remove header pragma
    result[0][0][0][1].del(0)
    # replace empty string with proper values
    result[0][0][0][1][0][1] = newStrLitNode($importCppStr)

  var converterName = newIdentNode("to" & $name)
  result.add quote do:
    converter `converterName`*(co: CppProxy): `name` {.used, importcpp:"(#)".}
    proc isCppObject*(T: typedesc[`name`]): bool = true

# constructor call
proc cppinit*(T: typedesc[CppObject]): T {.importcpp:"'0(@)", varargs, constructor.}

# magic placement new constructor for ptrs
proc cppctor*[T](x: ptr T): ptr T {.header:"new", importcpp: "(new (#) '*0(@))", varargs, nodecl, discardable.}

# magic placement new constructor for refs
proc cppctor*[T](x: ref T): ref T {.header:"new", importcpp: "(new (#) '*0(@))", varargs, nodecl, discardable.}

when not defined(js):
  {.emit:["""/*TYPESECTION*/
  #ifdef __cplusplus
  template<typename T>
  static inline void callCppPtrDestructor(T* instance) { instance->~T(); }
  
  template<typename T>
  static inline void callCppPtrDestructor(T& instance) { instance.~T(); }
  #endif
    """].}

# normal destructor for value types
proc internalCppdtor[T: CppObject](x: var T) {.importcpp:"callCppPtrDestructor(#)".}

# magic placement new compatible destructor for ptrs
proc internalCppdtor[T: CppObject](x: ptr T) {.importcpp:"callCppPtrDestructor(#)".}

# magic placement new compatible destructor for refs
proc internalCppdtor[T: CppObject](x: ref T) {.importcpp:"callCppPtrDestructor(#)".}

# normal destructor for value types
proc internalCppdtor[T: not CppObject](x: T) {.importcpp:"#.~'1()".}

# magic placement new compatible destructor for ptrs
proc internalCppdtor[T: not CppObject](x: ptr T) = x[].internalCppdtor()

# magic placement new compatible destructor for refs
proc internalCppdtor[T: not CppObject](x: ref T) = x[].internalCppdtor()

proc cppdelptr*[T](x: ptr T) =
  x.internalCppdtor()
  dealloc(x)

proc cppdtor*[T](x: ptr T) =
  x.internalCppdtor()

proc cppmove*[T](x: T): T {.importcpp:"std::move(#)".}

# refs

proc cppnewref*(myRef: var ref) =
  new(myRef, proc(self: type(myRef)) = self.internalCppdtor())
  myRef.cppctor()

# I could not find a way to avoid generating one of the following per each arg yet (so far varargs, typed, untyped didn't work)

proc cppnewref*(myRef: var ref, arg0: auto) =
  new(myRef, proc(self: type(myRef)) = self.internalCppdtor())
  myRef.cppctor(arg0)

proc cppnewref*(myRef: var ref, arg0, arg1: auto) =
  new(myRef, proc(self: type(myRef)) = self.internalCppdtor())
  myRef.cppctor(arg0, arg1)

# ptr

template cppnewptr*(myPtr: ptr): untyped =
  myPtr = cast[type(myPtr)](alloc0(sizeof(type(myPtr[]))))
  myPtr.cppctor()

# I could not find a way to avoid generating one of the following per each arg yet (so far varargs, typed, untyped didn't work)

template cppnewptr*(myPtr: ptr, arg0: typed): untyped =
  myPtr = cast[type(myPtr)](alloc0(sizeof(type(myPtr[]))))
  myPtr.cppctor(arg0)

template cppnewptr*(myPtr: ptr, arg0, arg1: typed): untyped =
  myPtr = cast[type(myPtr)](alloc0(sizeof(type(myPtr[]))))
  myPtr.cppctor(arg0, arg1)

template cppnewptr*(myPtr: ptr, arg0, arg1, arg2: typed): untyped =
  myPtr = cast[type(myPtr)](alloc0(sizeof(type(myPtr[]))))
  myPtr.cppctor(arg0, arg1, arg2)

proc `+`  *(x, y: CppProxy): CppProxy {.importcpp:"(# + #)".}
proc `-`  *(x, y: CppProxy): CppProxy {.importcpp:"(# - #)".}
proc `*`  *(x, y: CppProxy): CppProxy {.importcpp:"(# * #)".}
proc `/`  *(x, y: CppProxy): CppProxy {.importcpp:"(# / #)".}
proc `%`  *(x, y: CppProxy): CppProxy {.importcpp:"(# % #)".}
proc `+=` *(x, y: CppProxy): CppProxy {.importcpp:"(# += #)", discardable.}
proc `-=` *(x, y: CppProxy): CppProxy {.importcpp:"(# -= #)", discardable.}
proc `*=` *(x, y: CppProxy): CppProxy {.importcpp:"(# *= #)", discardable.}
proc `/=` *(x, y: CppProxy): CppProxy {.importcpp:"(# /= #)", discardable.}
proc `%=` *(x, y: CppProxy): CppProxy {.importcpp:"(# %= #)", discardable.}
proc `++` *(x: CppProxy): CppProxy {.importcpp:"(++#)".}
proc `--` *(x: CppProxy): CppProxy {.importcpp:"(--#)".}
proc `==` *(x, y: CppProxy): CppProxy {.importcpp:"(# == #)".}
proc `>`  *(x, y: CppProxy): CppProxy {.importcpp:"(# > #)".}
proc `<`  *(x, y: CppProxy): CppProxy {.importcpp:"(# < #)".}
proc `>=` *(x, y: CppProxy): CppProxy {.importcpp:"(# >= #)".}
proc `<=` *(x, y: CppProxy): CppProxy {.importcpp:"(# <= #)".}
proc `<<` *(x, y: CppProxy): CppProxy {.importcpp:"(# << #)".}
proc `>>` *(x, y: CppProxy): CppProxy {.importcpp:"(# >> #)".}
proc `and`*(x, y: CppProxy): CppProxy {.importcpp:"(# && #)".}
proc `or` *(x, y: CppProxy): CppProxy {.importcpp:"(# || #)".}
proc `not`*(x: CppProxy): CppProxy {.importcpp:"(!#)".}
proc `-`  *(x: CppProxy): CppProxy {.importcpp:"(-#)".}
proc `in` *(x, y: CppProxy): CppProxy {.importcpp:"(# in #)".}

proc `[]`*(obj: CppProxy, field: auto): CppProxy {.importcpp:getImpl.}
  ## Return the value of a property of name `field` from a JsObject `obj`.

proc `[]=`*[T](obj: CppProxy, field: auto, val: T) {.importcpp:setImpl.}
  ## Set the value of a property of name `field` in a JsObject `obj` to `v`.

proc `[]`*(obj: CppObject, field: auto): CppProxy {.importcpp:getImpl.}
  ## Return the value of a property of name `field` from a JsObject `obj`.

proc `[]=`*[T](obj: CppObject, field: auto, val: T) {.importcpp:setImpl.}
  ## Set the value of a property of name `field` in a JsObject `obj` to `v`.

when defined(js):
  # Conversion to and from CppProxy
  proc to*(x: CppProxy, T: typedesc): T {. importcpp: "(#)" .}
    ## Converts a CppProxy `x` to type `T`.

  # Conversion to and from CppProxy
  proc to*[T](x: CppProxy): T {. importcpp: "(#)" .}
    ## Converts a CppProxy `x` to type `T`.
else:
  # Conversion to and from CppProxy
  proc to*(x: CppProxy, T: typedesc[void]): T {. importcpp: "(#)" .}
    ## Converts a CppProxy `x` to type `T`.

  # Conversion to and from CppProxy
  proc to*(x: CppProxy, T: typedesc): T {. importcpp: "('0)(#)" .}
    ## Converts a CppProxy `x` to type `T`.

  # Conversion to and from CppProxy
  proc to*[T](x: CppProxy): T {. importcpp: "('0)(#)" .}
    ## Converts a CppProxy `x` to type `T`.

proc toCpp*[T](val: T): CppProxy {. importcpp: "(#)" .}
  ## Converts a value of any type to type CppProxy

template toCpp*(s: string): CppProxy = cstring(s).toCpp

converter toByte*(co: CppProxy): int8 {.used, importcpp:"(#)".}
converter toUByte*(co: CppProxy): uint8 {.used, importcpp:"(#)".}

converter toShort*(co: CppProxy): int16 {.used, importcpp:"(#)".}
converter toUShort*(co: CppProxy): uint16 {.used, importcpp:"(#)".}

converter toInt*(co: CppProxy): int {.used, importcpp:"(#)".}
converter toUInt*(co: CppProxy): uint {.used, importcpp:"(#)".}

converter toLong*(co: CppProxy): int64 {.used, importcpp:"(#)".}
converter toULong*(co: CppProxy): uint64 {.used, importcpp:"(#)".}

converter toFloat*(co: CppProxy): float {.used, importcpp:"(#)".}
converter toFloat32*(co: CppProxy): float32 {.used, importcpp:"(#)".}

converter toDouble*(co: CppProxy): float64 {.used, importcpp:"(#)".}

converter toCString*(co: CppProxy): cstring {.used, importcpp:"(#)".}

when defined(js):
  converter toWasmPtr*(co: CppProxy): WasmPtr {.used, importcpp:"(#)".}

macro CppFromAst*(n: untyped): untyped =
  result = n
  if n.kind == nnkStmtList:
    result = newProc(procType = nnkDo, body = result)
  return quote: toCpp(`result`)

macro dynamicCppGet*(obj: CppObject, field: untyped): CppProxy =
  ## Experimental dot accessor (get) for type JsObject.
  ## Returns the value of a property of name `field` from a CppObject `x`.
  if obj.len == 0 and $obj == CppGlobalName:
    let importString = "(" & $field & ")"
    result = quote do:
      proc helper(): CppProxy {.importcpp:`importString`, gensym.}
      helper()
  else:
    let importString = "#." & $field
    result = quote do:
      proc helper(o: CppObject): CppProxy {.importcpp:`importString`, gensym.}
      helper(`obj`)

template `.`*(obj: CppObject, field: untyped): CppProxy =
  ## Experimental dot accessor (get) for type JsObject.
  ## Returns the value of a property of name `field` from a CppObject `x`.
  dynamicCppGet(obj, field)

macro dynamicCppSet*(obj: CppObject, field, value: untyped): untyped =
  ## Experimental dot accessor (set) for type JsObject.
  ## Sets the value of a property of name `field` in a CppObject `x` to `value`.
  if obj.len == 0 and $obj == CppGlobalName:
    let importString = $field & " = #"
    result = quote do:
      proc helper(v: auto) {.importcpp:`importString`, gensym.}
      helper(`value`.toCpp)
  else:
    let importString = "#." & $field & " = #"
    result = quote do:
      proc helper(o: CppObject, v: auto) {.importcpp:`importString`, gensym.}
      helper(`obj`, `value`.toCpp)

template `.=`*(obj: CppObject, field, value: untyped): untyped =
  ## Experimental dot accessor (set) for type JsObject.
  ## Sets the value of a property of name `field` in a CppObject `x` to `value`.
  dynamicCppSet(obj, field, value)
  
macro dynamicCCall*(field: untyped, args: varargs[CppProxy, CppFromAst]): CppProxy =
  ## Experimental "method call" operator for type CppProxy.
  ## Takes the name of a method of the JavaScript object (`field`) and calls
  ## it with `args` as arguments, returning a CppProxy 
  ## return types have to be casted unless the type is known using `to(T)`, void returns need `to(void)`
  var importString: string
  importString = $field & "(@)"

  result = quote:
    proc helper(): CppProxy {.importcpp:`importString`, gensym.}
    helper()

  for idx in 0 ..< args.len:
    let paramName = ident("param" & $idx)
    result[0][3].add newIdentDefs(paramName, ident("CppProxy"))
    result[1].add args[idx].copyNimTree

macro dynamicCppCall*(obj: CppObject, field: untyped, args: varargs[CppProxy, CppFromAst]): CppProxy =
  ## Experimental "method call" operator for type CppProxy.
  ## Takes the name of a method of the JavaScript object (`field`) and calls
  ## it with `args` as arguments, returning a CppProxy 
  ## return types have to be casted unless the type is known using `to(T)`, void returns need `to(void)`
  var importString: string
  if obj.len == 0 and $obj == CppGlobalName:
    importString = $field & "(@)"
    
    result = quote:
      proc helper(): CppProxy {.importcpp:`importString`, gensym.}
      helper()
  else:
    when defined(js):
      importString = "#." & "_" & $field & "(@)"
    else:
      importString = "#." & $field & "(@)"
    
    result = quote:
      proc helper(o: CppObject): CppProxy {.importcpp:`importString`, gensym.}
      helper(`obj`)
  
  for idx in 0 ..< args.len:
    let paramName = ident("param" & $idx)
    result[0][3].add newIdentDefs(paramName, ident("CppProxy"))
    result[1].add args[idx].copyNimTree

template `.()`*(obj: CppObject, field: untyped, args: varargs[CppProxy, CppFromAst]): CppProxy =
  ## Experimental "method call" operator for type CppProxy.
  ## Takes the name of a method of the JavaScript object (`field`) and calls
  ## it with `args` as arguments, returning a CppProxy 
  ## return types have to be casted unless the type is known using `to(T)`, void returns need `to(void)`
  dynamicCppCall(obj, field, args)
    
# iterator utils
type CppIterator* {.importcpp: "'0::iterator".} [T] = object
proc itBegin [T] (cset: T): CppIterator[T] {.importcpp:"(#.begin())".}
proc itEnd [T] (cset: T): CppIterator[T] {.importcpp:"(#.end())".}
proc itPlusPlus [T] (csetIt: var CppIterator[T]): CppIterator[T] {.importcpp:"(++#)".}
proc itValue [T, R] (csetIt: var CppIterator[T]): R {.importcpp:"(*#)".}
proc itEqual [T] (csetIt: var CppIterator[T], csetIt2: var CppIterator[T]): bool {.importcpp:"(operator==(#, #))".}
iterator cppItems*[T, R](cset: var T): R =
  var it = cset.itBegin()
  var itend =  cset.itEnd()
  while not itEqual(it, itend):
    yield itValue[T, R](it)
    it = it.itPlusPlus

# std string utils
defineCppType(StdString, "std::string", "string")
converter toStdString*(s: string): StdString {.inline, noinit.} = cppinit(StdString, s.cstring)

## TUPLEs

# this could be avoided using templates I guess
# defineCppType(StdTuple, "auto", "tuple") # hackish but works fine, altho cannot be used inside a type!
type
  StdTuple2* {.importcpp: "std::tuple", header: "tuple".} [T1, T2] = object
  StdTuple3* {.importcpp: "std::tuple", header: "tuple".} [T1, T2, T3] = object
  StdTuple4* {.importcpp: "std::tuple", header: "tuple".} [T1, T2, T3, T4] = object
  StdTuple5* {.importcpp: "std::tuple", header: "tuple".} [T1, T2, T3, T4, T5] = object
  StdTuple = StdTuple2 | StdTuple3 | StdTuple4 | StdTuple5

proc makeCppTuple*(arg1, arg2: auto): StdTuple2[type(arg1), type(arg2)] {.importcpp: "std::make_tuple(@)", header: "tuple".}
proc makeCppTuple*(arg1, arg2, arg3: auto): StdTuple3[type(arg1), type(arg2), type(arg3)] {.importcpp: "std::make_tuple(@)", header: "tuple".}
proc makeCppTuple*(arg1, arg2, arg3, arg4: auto): StdTuple4[type(arg1), type(arg2), type(arg3), type(arg4)] {.importcpp: "std::make_tuple(@)", header: "tuple".}
proc makeCppTuple*(arg1, arg2, arg3, arg4, arg5: auto): StdTuple5[type(arg1), type(arg2), type(arg3), type(arg4), type(arg5)] {.importcpp: "std::make_tuple(@)", header: "tuple".}

# std tuple utils
proc cppTupleGet*[T](index: int; obj: CppProxy): T {.importcpp: "std::get<#>(#)", header: "tuple".}
proc cppTupleSet*(index: int; obj: CppProxy, value: CppObject) {.importcpp: "std::get<#>(#) = #", header: "tuple".}
proc cppTupleSize*(obj: CppProxy): int {.importcpp: "std::tuple_size<decltype(#)>::value", header: "tuple".}

# proc len(T: typedesc[tuple|object]): static[int] =
#   var f: T
#   for _ in fields(f):
#     inc result

proc toNimTuple*[T1, T2](t: StdTuple2[T1, T2]): (T1, T2) =
  # we need to call cpp constructor, cos if not our tuple state will be uninitialized (if contains cpp objects that is)
  discard cppctor(addr(result[0]))
  discard cppctor(addr(result[1]))
  result = (cppTupleGet[T1](0, t.toCpp), cppTupleGet[T2](1, t.toCpp))

proc toNimTuple*[T1, T2, T3](t: StdTuple3[T1, T2, T3]): (T1, T2, T3) =
  discard cppctor(addr(result[0]))
  discard cppctor(addr(result[1]))
  discard cppctor(addr(result[2]))
  (cppTupleGet[T1](0, t.toCpp), cppTupleGet[T2](1, t.toCpp), cppTupleGet[T3](2, t.toCpp))

proc toNimTuple*[T1, T2, T3, T4](t: StdTuple4[T1, T2, T3, T4]): (T1, T2, T3, T4) =
  discard cppctor(addr(result[0]))
  discard cppctor(addr(result[1]))
  discard cppctor(addr(result[2]))
  discard cppctor(addr(result[3]))
  (cppTupleGet[T1](0, t.toCpp), cppTupleGet[T2](1, t.toCpp), cppTupleGet[T3](2, t.toCpp), cppTupleGet[T4](3, t.toCpp))

proc toNimTuple*[T1, T2, T3, T4, T5](t: StdTuple5[T1, T2, T3, T4, T5]): (T1, T2, T3, T4, T5) =
  discard cppctor(addr(result[0]))
  discard cppctor(addr(result[1]))
  discard cppctor(addr(result[2]))
  discard cppctor(addr(result[3]))
  discard cppctor(addr(result[4]))
  (cppTupleGet[T1](0, t.toCpp), cppTupleGet[T2](1, t.toCpp), cppTupleGet[T3](2, t.toCpp), cppTupleGet[T4](3, t.toCpp), cppTupleGet[T5](4, t.toCpp))

# some issues generating static[int] in cpp
type StdArray* {.importcpp: "std::array<'0, '1>", header: "array".} [T; S: static[int]] = object
proc `[]`*[T; S: static[int]](v: StdArray[T, S]; index: int): T {.inline.} = v.toCpp[index].to(T)
proc `[]=`*[T; S: static[int]](v: var StdArray[T, S]; index: int; value: T) {.inline.} = v.toCpp[index] = value

template `@`*[SIZE](a: array[SIZE, bool]): StdArray = 
  var result: StdArray[bool, a.len]
  for i in 0..a.high: 
    result[i] = a[i]
  result

type
  StdException* {.importcpp: "std::exception", header: "<exception>".} = object

proc what*(s: StdException): cstring {.importcpp: "((char *)#.what())".}

proc nimPointerDeleter(p: pointer) {.exportc.} = dealloc(p)

{.emit: """/*TYPESECTION*/
#include <functional>
""".}

type
  UniquePointer* {.importcpp: "std::unique_ptr<'*0, std::function<void('*0*)>>", header: "<memory>".} [T] = object

proc internalMakeUnique[T](): UniquePointer[T] =
  var p: ptr T
  cppnewptr(p)
  proc stdmakeptr[T](vp: ptr T): UniquePointer[T] {.importcpp:"std::unique_ptr<'*0, std::function<void('*0*)>>(@, []('*0* ptr) { callCppPtrDestructor(ptr); nimPointerDeleter(ptr); })", varargs, constructor.}
  return stdmakeptr[T](p)

proc makeUnique*[T](): UniquePointer[T] {.inline.} =  internalMakeUnique[T]()

proc getPtr*[T](up: var UniquePointer[T]): ptr T {.inline.} = up.toCpp.get().to(ptr T)

type
  SharedPointer* {.importcpp: "std::shared_ptr<'*0>", header: "<memory>".} [T] = object

proc internalMakeShared[T](): SharedPointer[T] =
  var p: ptr T
  cppnewptr(p)
  proc stdmakeptr[T](vp: ptr T): SharedPointer[T] {.importcpp:"std::shared_ptr<'*0>(@, []('*0* ptr) { callCppPtrDestructor(ptr); nimPointerDeleter(ptr); })", varargs, constructor.}
  return stdmakeptr[T](p)

proc makeShared*[T](): SharedPointer[T] {.inline.} =  internalMakeShared[T]()

proc getPtr*[T](up: SharedPointer[T]): ptr T {.inline.} = up.toCpp.get().to(ptr T)

when defined wasm:
  template EM_ASM*(jsCode: string): untyped =
    {.emit: """/*INCLUDESECTION*/
      #include <emscripten.h>
    """.}
    proc emAsmProc() =
      {.emit: ["EM_ASM(", jsCode, ");"].}
    emAsmProc()

when isMainModule:
  {.emit:"#include <stdio.h>".}
  {.emit:"#include <string>".}
  
  cppdefines("MYDEFINE", "MYDEFINE2=10")
  cppincludes(".")
  cppfiles("MyClass.cpp")
  cpplibpaths(".")
  
  defineCppType(MyClass, "MyClass", "MyClass.hpp")
  defineCppType(MyClass2, "MyClass2", "MyClass.hpp")

  type
    MyNimType = object # my nim types still needs to use cpp ctor/dtor cos includes a cpp type inside
      x: MyClass

  # expandMacros:
  # dumpAstGen:
  when true: 
    proc run() =
      var x = cppinit(MyClass, 1)
      var nx: MyNimType
      var nxp: ptr MyNimType
      cppnewptr nxp
      var y = cast[ptr MyClass](alloc0(sizeof(MyClass)))
      var w: ref MyClass
      new(w, proc(self: ref MyClass) = self.internalCppdtor())
      var z = y.cppctor(1)
      var q = w.cppctor(1)
      
      var j: ref MyClass
      cppnewref(j, 1)
      j.number = 22
      echo j.number.to(cint)
      
      var k: ptr MyClass 
      cppnewptr(k, 2)
      k.number = 55
      echo k.number.to(cint)
      k.cppdelptr
      
      echo global.globalNumber.to(cint)
      global.globalNumber = 102
      echo global.globalNumber.to(cint)
      
      global.printf("Hello World\n".cstring).to(void)
      y.test3().to(void)
      y.test4(7, 8).to(void)

      echo q.number.to(cint)
      y.number = 80
      y.numbers[0] = 23
      var n = (x.number + y.number + y.numbers[0]).to(cint)
      var nInt: int = x.number + y.number + y.numbers[0]
      echo nInt
      echo n
      echo x.test(1).to(cdouble)
      echo x.test(x.test2(2)).to(cdouble)
      echo x.test2(3).to(cint)

      z.cppdtor()
      x.internalCppdtor()
      nx.internalCppdtor()
      cppdelptr nxp

      var x1 = cppinit(MyClass2, 1)
      echo x1.test20(1).to(cint)

      var c1 = x1.class1.to(MyClass)
      c1.test3().to(void)
      x1.class1.test3().to(void)
      var myFloat: float32 = x1.myDouble
      echo myFloat
      var myStr = "Hello Mars"
      x1.myCstring = myStr
      echo x1.myCstring.to(cstring)
      # TODO check macros -> callsite macro

      x1.testVir3(11).to(void)

      var cppTuple = makeCppTuple(x, y)
      cppTupleSet(0, cppTuple.toCpp, x.toCpp)
      var tx = cppTupleGet[MyClass](0, cppTuple.toCpp)
      echo x.test(1).to(cdouble)
      var nimTuple = cppTuple.toNimTuple()

      var
        uniqueInt = makeUnique[int]()
        uniqueIntPtr = uniqueInt.getPtr()
      uniqueIntPtr[] = 10
      assert uniqueIntPtr[] == 10

      var
        sharedInt = makeShared[int]()
        sharedIntPtr = sharedInt.getPtr()
      sharedIntPtr[] = 11
      assert sharedIntPtr[] == 11

      block:
        echo "Expect dtor"
        var sharedInt = makeShared[MyClass]()

      echo "Expect more dtors..."
    
    run()
