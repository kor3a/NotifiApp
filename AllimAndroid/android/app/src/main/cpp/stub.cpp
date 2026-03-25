#include <jni.h>

// Stub for libraries merged into libreactnative.so in React Native 0.76.x.
// SoLoader falls back to System.loadLibrary() which requires the .so file to
// exist on disk. These stubs satisfy that requirement; actual JNI symbols are
// registered by libreactnative.so's JNI_OnLoad.
JNIEXPORT jint JNI_OnLoad(JavaVM* vm, void* reserved) {
    return JNI_VERSION_1_6;
}
