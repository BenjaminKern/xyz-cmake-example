#include "greatest_suite.h"
#include "foo_c/foo_c.h"

TEST test_1(void) {
  foo_c();
  ASSERT_EQ(1, 1);
  PASS();
}

SUITE(test_suite) {
  RUN_TEST(test_1);
}
