#include "pocketsphinx_ffi_wrapper.h"
#include <pocketsphinx/err.h>

FFI_PLUGIN_EXPORT ps_decoder_t* initialize_recognizer(const char* hmm_path, const char* dict_path, const char* kws_path) {
    ps_config_t *config = ps_config_init(NULL);
    if (config == NULL) {
        E_ERROR("Failed to initialize config object.\n");
        return NULL;
    }

    // Set parameters
    if (hmm_path) {
        ps_config_set_str(config, "hmm", hmm_path);
    }
    if (dict_path) {
        ps_config_set_str(config, "dict", dict_path);
    }
    if (kws_path) {
        ps_config_set_str(config, "kws", kws_path);
    }
    
    ps_config_set_int(config, "samprate", 16000);

    // Initialize the decoder
    ps_decoder_t *ps = ps_init(config);
    if (ps == NULL) {
        E_ERROR("PocketSphinx decoder init failed! Check model paths and file integrity.\n");
        ps_config_free(config);
        return NULL;
    } else {
        E_INFO("PocketSphinx decoder initialized successfully.\n");
    }
    
    return ps;
}

FFI_PLUGIN_EXPORT void free_recognizer(ps_decoder_t* ps) {
    if (ps != NULL) {
        ps_free(ps);
    }
}

FFI_PLUGIN_EXPORT int start_processing(ps_decoder_t* ps) {
    if (ps == NULL) return -1;
    return ps_start_utt(ps);
}

FFI_PLUGIN_EXPORT int process_audio_chunk(ps_decoder_t* ps, const int16_t* data, int n_samples) {
    if (ps == NULL) return -1;
    return ps_process_raw(ps, data, n_samples, 0, 0);
}

FFI_PLUGIN_EXPORT int stop_processing(ps_decoder_t* ps) {
    if (ps == NULL) return -1;
    return ps_end_utt(ps);
}

FFI_PLUGIN_EXPORT const char* get_hypothesis(ps_decoder_t* ps) {
    if (ps == NULL) return NULL;
    return ps_get_hyp(ps, NULL);
}
