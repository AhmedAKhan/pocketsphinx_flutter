// Relative import to be able to reuse the C sources.
// See the comment in ../pocketsphinx_flutter.podspec for more information.

#include "TargetConditionals.h"

#if TARGET_OS_SIMULATOR

// Dummy implementation for Simulator to avoid linking errors with libpocketsphinx.a (arm64 only)
// This allows the app to build and run on Simulator, but speech recognition will not function.

#include "../../src/pocketsphinx_flutter.h"

// Define the opaque struct so we can return a valid pointer
struct ps_decoder_s {
    int _dummy;
};

static struct ps_decoder_s _dummy_decoder = { 0 };

FFI_PLUGIN_EXPORT ps_decoder_t* initialize_recognizer(const char* hmm_path, const char* dict_path, const char* kws_path) {
    printf("[Pocketsphinx] Warning: Running on Simulator. Speech recognition is disabled.\n");
    return &_dummy_decoder;
}

FFI_PLUGIN_EXPORT void free_recognizer(ps_decoder_t* ps) {
    // No-op
}

FFI_PLUGIN_EXPORT int start_processing(ps_decoder_t* ps) {
    return 0;
}

FFI_PLUGIN_EXPORT int process_audio_chunk(ps_decoder_t* ps, const int16_t* data, int n_samples) {
    return 0;
}

FFI_PLUGIN_EXPORT int stop_processing(ps_decoder_t* ps) {
    return 0;
}

FFI_PLUGIN_EXPORT const char* get_hypothesis(ps_decoder_t* ps) {
    return NULL;
}

#else

// Real implementation
#include "../../src/pocketsphinx_flutter.c"

#endif
