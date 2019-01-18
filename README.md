# Nimline

Write C++ straight from Nim, without the need to generate wrappers. Inspired by `std/jsffi` and using the magic of `importcpp`, `macros` and many other awesome Nim features.
   
### Accessing members

Nimline allows you to access C++ members and functions of Nim objects using the dot-operators `.`, `.=` and `.()`, and other operations that mimic C++.
Any Nim value can be used this way, by first reinterpreting it using `toCpp()`.

```
obj.toCpp().someField = 42 # Translates to `obj.someField = 42`
discard obj.toCpp().someField.to(int) # Translates to `obj.someField`
obj.toCpp().someMethod(1).to(void) # Translates to `obj.someMethod(1)`
```

Return types have to be explicitly specified using `to()`, if they need to be stored in variables, or passed to Nim-procs, even for `void` retruns.
They can however be used in further C++ calls.

If a member name collides with a Nim-keyword, the more explicit notation `dynamicCppCall` can be used:
```
obj.toCpp().dynamicCppCall("someMethod", 1).to(void)
```

### Importing C++
To use a C++ type, first declare it:

```
defineCppType(MyClass, "MyClass", "MyHeader.h")
```

## Globals

```
# Accessing global variables and functions
echo global.globalNumber.to(cint)
global.globalNumber = 102
echo global.globalNumber.to(cint)
global.printf("Hello World\n".cstring).to(void)
```

### Constructors and destructors

To initialize an object on the stack, use `cppinit()`:

```nim
# Translates to `MyType obj(1)`
let obj = cppinit(MyType, 1)
```

Objects can also be constructed on the heap, either through a `ptr` or `ref` using `cppctor()`.
This translates to a placement-new in C++ and needs to be followed by `cppdtor` for cleanup.
```
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

For convenience, `cppnewref()` creates a new reference, constructs the object and calls it's constructor on finalization.
```
cppnewref(tracked, 1)
```

### Adding C++ compiler options

```
cppdefines("MYDEFINE", "MYDEFINE2=10")
cppincludes(".")
cppfiles("MyClass.cpp")
cpplibpaths(".")
```

### Standard libary helpers

...

