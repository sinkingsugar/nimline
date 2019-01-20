# Nimline

[![Build Status](https://travis-ci.com/fragcolor-xyz/nimline.svg?branch=master)  ](https://travis-ci.com/fragcolor-xyz/nimline)

Write C++ straight from Nim, without the need to generate wrappers. Inspired by `std/jsffi` and using the magic of `importcpp`, `macros` and many other awesome Nim features.
   
## Usage

### Accessing members

Nimline allows you to access C++ members and functions of Nim objects using the dot-operators `.`, `.=` and `.()`, and other operations that mimic C++.
Any Nim value can be used this way, by first reinterpreting it using `toCpp`.

```nimrod
obj.toCpp().someField = 42 # Translates to `obj.someField = 42`
discard obj.toCpp().someField.to(int) # Translates to `obj.someField`
obj.toCpp().someMethod(1).to(void) # Translates to `obj.someMethod(1)`
```

Return types have to be explicitly specified using `to`, if they need to be stored in variables, or passed to Nim-procs, even for `void` retruns.
They can however be used in further C++ calls.

If a member name collides with a Nim-keyword, the more explicit notation `invoke` can be used:
```
obj.toCpp().invoke("someMethod", 1).to(void)
```
Function arguments are automatically reinterpreted as C++ types.

> Note: `toCpp()`, `invoke()` and member-function calls return a `CppProxy`. This is a non-concrete type only enables member access, and does not appear in the generated C++.

### Importing C++ types

If a C++ type needs to be used as a variable, it should be imported first using `defineCppType`.
This will declare the type and enable interop on it, similar to `CppProxy`. `toCpp` is not needed on it's instances.

```nimrod
defineCppType(MyNimType, "MyCppClass", "MyHeader.h")
var obj: MyNimType
obj.someField = 42
```

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

```nimrod
cppdefines("MYDEFINE", "MYDEFINE2=10")
cppincludes(".")
cppfiles("MyClass.cpp")
cpplibpaths(".")
```

### Standard library helpers

TODO

