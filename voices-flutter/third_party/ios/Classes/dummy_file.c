// Keep at least one source file so CocoaPods creates a framework target.
//
// iOS simulator builds may miss the C++ symbol below when ORT is linked in a
// CPU-only configuration. Provide a no-op fallback symbol so linking succeeds.
// This path is safe for this app because execution providers are not appended
// dynamically at runtime; CPU EP is used.

#include <stddef.h>

void* ort_session_options_append_execution_provider_shim(
    void* self,
    void* session_options,
    const char* provider_name,
    const char* const* provider_options_keys,
    const char* const* provider_options_values,
    size_t num_provider_options) __asm__(
    "__ZN7OrtApis37SessionOptionsAppendExecutionProviderEP17OrtSessionOptionsPKcPKS3_S5_m");

void* ort_session_options_append_execution_provider_shim(
    void* self,
    void* session_options,
    const char* provider_name,
    const char* const* provider_options_keys,
    const char* const* provider_options_values,
    size_t num_provider_options) {
  (void)self;
  (void)session_options;
  (void)provider_name;
  (void)provider_options_keys;
  (void)provider_options_values;
  (void)num_provider_options;
  return NULL;
}
