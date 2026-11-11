#include <stddef.h>

#if defined(__APPLE__)
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonKeyDerivation.h>

int everything_sha256(const unsigned char *data, size_t len, unsigned char *out) {
    if (!data || !out) return -1;
    CC_SHA256(data, (CC_LONG)len, out);
    return 0;
}

int everything_pbkdf2_hmac_sha256(const unsigned char *pass, size_t pass_len,
                                  const unsigned char *salt, size_t salt_len,
                                  unsigned int rounds, unsigned char *out) {
    if (!pass || !salt || !out) return -1;
    return CCKeyDerivationPBKDF(kCCPBKDF2, (const char *)pass, pass_len,
                                salt, salt_len, kCCPRFHmacAlgSHA256,
                                rounds, out, 32);
}

#else

// Generic non-Apple fallback stubs (Android/Linux builds use Rust cdylib via Cargo)
int everything_sha256(const unsigned char *data, size_t len, unsigned char *out) {
    (void)data; (void)len; (void)out;
    return -1;
}

int everything_pbkdf2_hmac_sha256(const unsigned char *pass, size_t pass_len,
                                  const unsigned char *salt, size_t salt_len,
                                  unsigned int rounds, unsigned char *out) {
    (void)pass; (void)pass_len; (void)salt; (void)salt_len; (void)rounds; (void)out;
    return -1;
}

#endif

int everything_fast_digit_scan(const unsigned char *bytes, size_t len) {
    if (!bytes || len == 0) return 0;
    for (size_t i = 0; i < len; i++) {
        if (bytes[i] >= '0' && bytes[i] <= '9') return 1;
    }
    return 0;
}
