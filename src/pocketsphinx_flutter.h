#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <pocketsphinx.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the recognizer with HMM, Dictionary, and optional Keyword list.
// Returns a pointer to the ps_decoder_t object or NULL on failure.
FFI_PLUGIN_EXPORT ps_decoder_t* initialize_recognizer(const char* hmm_path, const char* dict_path, const char* kws_path);

// Free the recognizer resources.
FFI_PLUGIN_EXPORT void free_recognizer(ps_decoder_t* ps);

// Start processing an utterance.
FFI_PLUGIN_EXPORT int start_processing(ps_decoder_t* ps);

// Process a chunk of audio data.
// data: pointer to 16-bit PCM audio samples.
// n_samples: number of samples (not bytes).
FFI_PLUGIN_EXPORT int process_audio_chunk(ps_decoder_t* ps, const int16_t* data, int n_samples);

// End processing an utterance.
FFI_PLUGIN_EXPORT int stop_processing(ps_decoder_t* ps);

// Get the hypothesis string.
// Returns a string owned by the decoder (do not free).
FFI_PLUGIN_EXPORT const char* get_hypothesis(ps_decoder_t* ps);

#ifdef __cplusplus
}
#endif
