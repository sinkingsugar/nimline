#pragma once

#include <stdio.h>

class MyClass 
{
public:
  MyClass()
  {

  }

  MyClass(int n)
  {
    number = 7;
    numbers[0] = 4;
    numbers[1] = 5;
  }

  ~MyClass()
  {
    printf("~MyClass\n");
  }

  double test(int x) 
  { 
    return (double)x; 
  }
  
  void test3()
  {
    printf("Hello mondo\n");
  }

  void test4(int x, int y)
  {
    printf("Hello mondo %d %d\n", x, y);
  }
  
  int test2(int x) 
  { 
    return x; 
  }
  
  int number = 77;
  int numbers[2];
};

class MyClass2
{
public:
  MyClass2()
  {

  }

  MyClass2(int n)
  {
  }

  int test20(int x) 
  { 
    return x; 
  }

  virtual int testVir()
  {
    return 0;
  }

  virtual int testVir2(int i)
  {
    return i;
  }

  virtual void testVir4(int i)
  {
    printf("AAAL %d\n", i);
  }

  virtual void testVir3(int i)
  {
    printf("AAAL %d\n", i);
  }

  int number = 78;
  double myDouble = 7.7;
  MyClass class1;
  const char* myCstring;
};

int globalNumber = 101;