# Native toolchain, don't set CMAKE_SYSTEM_NAME
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER /usr/bin/gcc)
set(CMAKE_CXX_COMPILER /usr/bin/g++)
set(CMAKE_INSTALL_PREFIX "/usr/local" CACHE PATH "Installation prefix" FORCE)