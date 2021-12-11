#include <doctest.h>
#include <foo/foo.h>

TEST_CASE("check foo function") {
  foo();
  CHECK(true);
}
