#include <doctest.h>
#include <duh/duh.h>

TEST_CASE("check foo function") {
  duh("12345");
  CHECK(true);
}
