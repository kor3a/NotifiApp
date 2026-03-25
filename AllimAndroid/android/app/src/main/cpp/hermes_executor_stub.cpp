#include <jni.h>

// Stub: In React Native 0.76.x, libhermes_executor.so was merged into
// libreactnative.so. HermesExecutor.java still calls
// System.loadLibrary("hermes_executor") via SoLoader, which requires the
// file to exist. This stub satisfies that requirement; the actual Hermes
// executor JNI symbols are registered by libreactnative.so's JNI_OnLoad.
JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* reserved) {
    return JNI_VERSION_1_6;
}
