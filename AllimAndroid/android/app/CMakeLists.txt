cmake_minimum_required(VERSION 3.22.1)
project(allimandroid)

# Align ELF LOAD segments to 16 KB so the app is compatible with Android 15+
# devices that use 16 KB page sizes (Pixel 8+, future devices). Without this
# the runtime falls back to "page size compatible mode" and logs a warning.
add_link_options("-Wl,-z,max-page-size=16384")

# In RN 0.76.x several libraries were merged into libreactnative.so but their
# Java/Kotlin callers still invoke SoLoader.loadLibrary() by the old names,
# which falls back to System.loadLibrary() → dlopen → "library not found".
# These stubs satisfy the dlopen check; actual symbols come from libreactnative.so.

function(add_stub name)
    add_library(${name} SHARED src/main/cpp/stub.cpp)
    target_link_libraries(${name} android log)
endfunction()

add_stub(hermes_executor)
add_stub(react_devsupportjni)
add_stub(reactnativejni)
add_stub(react_nativemodule_core)
