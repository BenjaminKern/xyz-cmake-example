#include "bar/bar.h"
#include "foo_c/foo_c.h"
#include <iostream>

void bar(xyz arg) {
  foo();
  foo_c();
  std::cout << arg.x << std::endl;
};
