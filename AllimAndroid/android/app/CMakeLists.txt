cmake_minimum_required(VERSION 3.22.1)
project(allimandroid)

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
