cmake_minimum_required(VERSION 3.22.1)
project(allimandroid)

# Stub shared library to satisfy SoLoader's System.loadLibrary("hermes_executor")
# call from HermesExecutor.java. In RN 0.76.x the executor was merged into
# libreactnative.so; this stub provides the missing file so the dlopen succeeds.
add_library(hermes_executor SHARED
    src/main/cpp/hermes_executor_stub.cpp
)

target_link_libraries(hermes_executor
    android
    log
)
