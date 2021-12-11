#pragma once

#include <iostream>

template<typename T>
void duh(T&& arg) {
#ifdef DUH
  std::cout << "DUH MACRO: " << arg << "\n";
#else
  std::cout << "DUH: " << arg << "\n";
#endif
}
