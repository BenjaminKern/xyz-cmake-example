#include "foo/foo.h"
#include "duh/duh.h"
#include "zlib.h"
#include <iostream>

namespace {

}

void foo() {
  z_stream s;
  s.zalloc = Z_NULL;
  s.zfree = Z_NULL;
  s.opaque = Z_NULL;
  auto ret = deflateInit(&s, Z_DEFAULT_COMPRESSION);

  std::cout << "foo\n";
  duh("foo");
}
