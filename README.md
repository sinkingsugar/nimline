# Cppffi

Write C++ straight from Nim. Inspired by `std/jsffi` and using the magic of `importcpp`, `macros` and many other cool nim features. Wrappers are a thing of the past!
  
## Example

```nimrod
# Build configuration
cppdefines("MYDEFINE", "MYDEFINE2=10")
cppincludes(".")
cppfiles("MyClass.cpp")
cpplibpaths(".")

# Define nim types for C++ types will be used directly
defineCppType(MyClass, "MyClass", "MyClass.hpp")
defineCppType(MyClass2, "MyClass2", "MyClass.hpp")

# Construct an object
var x = cppinit(MyClass, 1)
var y = cast[ptr MyClass](alloc0(sizeof(MyClass)))

# Create a C++ object tracked by the Nim GC
var j: ref MyClass
cppnewref(j, 1)
j.number = 22
echo j.number.to(cint)

# Create an untracked C++ object
var k: ptr MyClass 
cppnewptr(k, 2)
k.number = 55
echo k.number.to(cint)
k.cppdelptr

# Accessing global variables and functions
echo global.globalNumber.to(cint)
global.globalNumber = 102
echo global.globalNumber.to(cint)
global.printf("Hello World\n".cstring).to(void)

# Accessing members
y.test3().to(void)
y.test4(7, 8).to(void)
```
