# Nimline

previously known as [`fragments/ffi/cpp`](https://github.com/fragcolor-xyz/fragments/blob/master/fragments/ffi/cpp.nim)

please star and support [*fragments*](https://github.com/fragcolor-xyz/fragments) as well!

[![Build Status](https://travis-ci.com/fragcolor-xyz/nimline.svg?branch=master)  ](https://travis-ci.com/fragcolor-xyz/nimline)

Write C/C++ straight from Nim, without the need to generate wrappers. Inspired by `std/jsffi` and using the magic of `importcpp`, `macros` and many other awesome Nim features.

> Note: Since imported C++ methods and types are not known to the Nim-compiler, errors will be reported by the C++ compiler instead. They will also not be caught by the linter.

## Code-generation example

Nim:
```nimrod
var obj = cppinit(MyClass, 1)
obj.someField = 42
let res = obj.someMethod(1, 2.0).to(cint)

# or for an internal pointer, which is more flexible due to lack of constructors in nim
var
  myx = MyClass.new()
  myxref = MyClass.newref()
myx.test3().to(void)
myx.number = 99
myxref.test3().to(void)
myxref.number = 100
```
Generated C++:
```cpp
MyClass obj(((NI) 1));
obj.someField = (((NI) 42));
int res = (int)(obj.someMethod((((NI) 1)), (2.0000000000000000e+00)));
```

## Usage

### Importing C++ types

If a C++ type needs to be used as a variable, it first has to be declared using `defineCppType`. This will import the type and enable interop on it.

```nimrod
defineCppType(MyNimType, "MyCppClass", "MyHeader.h")
var obj: MyNimType
obj.someField = 42
```

### Accessing members

Nimline allows you to access C++ members and functions of Nim objects using the dot-operators `.`, `.=` and `.()`, and other operations that mimic C++.

```nimrod
obj.someField = 42 # Translates to `obj.someField = 42`
discard obj.someField.to(cint) # Translates to `obj.someField`
obj.someMethod(1).to(void) # Translates to `obj.someMethod(1)`
```

Return types have to be explicitly specified using `to`, if they need to be stored in variables, or passed to Nim-procs, even for `void` retruns.
This is because the Nim-compiler is not aware of these function signatures. They can however be used in further C++ calls.
Function arguments are automatically reinterpreted as C++ types.

If a member name collides with a Nim-keyword, the more explicit notation `invoke` can be used:
```
obj.invoke("someMethod", 1).to(void)
```

Even types that were not declared with `defineCppType` can be used in this way, by first reinterpreting them using `toCpp`.
```nimrod
type MyClass {.importcpp.} = object
var obj: MyClass
obj.toCpp.someField = 42
```

> Note: `toCpp()`, `invoke()` and member-function calls return a `CppProxy`. This is a non-concrete type only enables member access, and does not appear in the generated C++.

### Globals

Global variables and free function can be used from the special `global` object, just like data members and member functions.

```nimrod
global.globalNumber = 42
echo global.globalNumber.to(cint)
global.printf("Hello World\n".cstring).to(void)
```

Free functions can alternatively be called with `invokeFunction`.
```nimrod
invokeFunction("printf", "Hello World\n".cstring).to(void)
```

### Constructors and destructors

To initialize an object on the stack, use `cppinit()`:

```nimrod
# Translates to `MyType obj(1)`
let obj = cppinit(MyType, 1)
```

Objects can also be constructed on the heap, either through a `ptr` or `ref` using `cppctor()`.
This translates to a placement-new in C++ and needs to be followed by `cppdtor` for cleanup.
```nimrod
# Allocate storage
let
  tracked: ref MyClass = new MyClass
  untracked: ptr MyClass = cast[ptr MyClass](alloc0(sizeof(MyClass)))

# Call placement-new, e.g. `new (tracked) MyClass(1)`
cppctor(tracked, 1)
cppctor(untracked, 2)

# Call destructor, e.g. `tracked->~MyClass()`
cppdtor(tracked)
cppdtor(untracked)
```

For convenience, `cppnewref()` creates a new reference, constructs the object and calls it's destructor on finalization.
```nimrod
cppnewref(tracked, 1)
```

### Adding C++ compiler options

The folloing helpers are available to set C++ compiler/linker options in a platform independent way.

```nimrod
cppdefines("MYDEFINE", "MYDEFINE2=10") # e.g. -DMYDEFINE -DMYDEFINE2=10
cppincludes(".") # e.g. -I.
cppfiles("MyClass.cpp")
cpplibpaths(".") # e.g. -L.
cpplibs("libMyModule.so") # e.g. -llibMyModule.so
```

### Standard library helpers

For convenience, the following standard library types are supported out of the box.

- `StdString` (`std::string`)
  ```nimrod
  let str: StdString = "HelloWorld"
  ```

- `StdArray` (`std::array`)
  ```nimrod
  var cppArray: StdArray[cint, 4]
  cppArray[0] = 42
  echo cppArray[0]
  ```

- `StdTuple` (`std::tuple`)
  ```nimrod
  var cppTyple = makeCppTuple(1, 1.0, obj)
  cppTupleSet(0, cppTuple.toCpp, 42.toCpp)
  echo cppTupleGet[int](0, cppTuple.toCpp)
  let nimTuple = cppTuple.toNimTyple()
  ```

- `StdException` (`std::exception`)
  ```nimrod
  try: someNativeFunction()
  except StdException as e: raiseAssert($e.what())
  ```
## Known issues

- `cppinit` does not work in the global scope. This is a Nim issue (https://github.com/nim-lang/Nim/issues/6198).
- Nim always memsets to 0 value types, this might have serious bad effects on most cpp classes. Workaround with refs and pointers.
