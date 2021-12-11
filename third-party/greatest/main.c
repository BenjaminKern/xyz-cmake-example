#include "greatest_suite.h"

GREATEST_MAIN_DEFS();

int main(int argc, char **argv) {
  GREATEST_MAIN_BEGIN();
  RUN_SUITE(test_suite);
  GREATEST_MAIN_END();
}
