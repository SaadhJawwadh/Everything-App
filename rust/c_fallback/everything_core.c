#include <stddef.h>
#include <stdint.h>
#include <string.h>

#if defined(__APPLE__)
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonKeyDerivation.h>

int everything_sha256(const unsigned char *data, size_t len, unsigned char *out) {
    if ((!data && len > 0) || !out) return -1;
    CC_SHA256(data, (CC_LONG)len, out);
    return 0;
}

int everything_pbkdf2_hmac_sha256(const unsigned char *pass, size_t pass_len,
                                  const unsigned char *salt, size_t salt_len,
                                  unsigned int rounds, unsigned char *out) {
    if ((!pass && pass_len > 0) || (!salt && salt_len > 0) || !out || rounds == 0) return -1;
    return CCKeyDerivationPBKDF(kCCPBKDF2, (const char *)pass, pass_len,
                                salt, salt_len, kCCPRFHmacAlgSHA256,
                                rounds, out, 32);
}

#else

/* Portable C implementation of SHA-256 and PBKDF2-HMAC-SHA256 for Android / Linux */

static inline uint32_t ev_rotr32(uint32_t v, unsigned int n) {
    return (v >> n) | (v << (32U - n));
}

static const uint32_t EV_SHA256_RC[64] = {
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U,
    0x3956c25bU, 0x59f111f1U, 0x923f82a4U, 0xab1c5ed5U,
    0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U,
    0xe49b69c1U, 0xefbe4786U, 0x0fc19dc6U, 0x240ca1ccU,
    0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U,
    0xc6e00bf3U, 0xd5a79147U, 0x06ca6351U, 0x14292967U,
    0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U,
    0xa2bfe8a1U, 0xa81a664bU, 0xc24b8b70U, 0xc76c51a3U,
    0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U,
    0x391c0cb3U, 0x4ed8aa4aU, 0x5b9cca4fU, 0x682e6ff3U,
    0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U
};

typedef struct {
    uint32_t h[8];
    uint64_t total_bits;
    uint8_t buf[64];
    size_t buf_used;
} ev_sha256_state_t;

static void ev_sha256_init(ev_sha256_state_t *st) {
    st->h[0] = 0x6a09e667U;
    st->h[1] = 0xbb67ae85U;
    st->h[2] = 0x3c6ef372U;
    st->h[3] = 0xa54ff53aU;
    st->h[4] = 0x510e527fU;
    st->h[5] = 0x9b05688cU;
    st->h[6] = 0x1f83d9abU;
    st->h[7] = 0x5be0cd19U;
    st->total_bits = 0;
    st->buf_used = 0;
}

static void ev_sha256_compress_block(ev_sha256_state_t *st, const uint8_t blk[64]) {
    uint32_t w[64];
    for (int i = 0; i < 16; i++) {
        w[i] = ((uint32_t)blk[i * 4] << 24)
             | ((uint32_t)blk[i * 4 + 1] << 16)
             | ((uint32_t)blk[i * 4 + 2] << 8)
             | ((uint32_t)blk[i * 4 + 3]);
    }
    for (int i = 16; i < 64; i++) {
        uint32_t g0 = ev_rotr32(w[i - 15], 7) ^ ev_rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint32_t g1 = ev_rotr32(w[i - 2], 17) ^ ev_rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + g0 + w[i - 7] + g1;
    }

    uint32_t v0 = st->h[0], v1 = st->h[1], v2 = st->h[2], v3 = st->h[3];
    uint32_t v4 = st->h[4], v5 = st->h[5], v6 = st->h[6], v7 = st->h[7];

    for (int i = 0; i < 64; i++) {
        uint32_t sig1 = ev_rotr32(v4, 6) ^ ev_rotr32(v4, 11) ^ ev_rotr32(v4, 25);
        uint32_t choose = (v4 & v5) ^ ((~v4) & v6);
        uint32_t t1 = v7 + sig1 + choose + EV_SHA256_RC[i] + w[i];
        uint32_t sig0 = ev_rotr32(v0, 2) ^ ev_rotr32(v0, 13) ^ ev_rotr32(v0, 22);
        uint32_t major = (v0 & v1) ^ (v0 & v2) ^ (v1 & v2);
        uint32_t t2 = sig0 + major;

        v7 = v6;
        v6 = v5;
        v5 = v4;
        v4 = v3 + t1;
        v3 = v2;
        v2 = v1;
        v1 = v0;
        v0 = t1 + t2;
    }

    st->h[0] += v0; st->h[1] += v1; st->h[2] += v2; st->h[3] += v3;
    st->h[4] += v4; st->h[5] += v5; st->h[6] += v6; st->h[7] += v7;
}

static void ev_sha256_feed(ev_sha256_state_t *st, const uint8_t *in_bytes, size_t n_bytes) {
    for (size_t i = 0; i < n_bytes; i++) {
        st->buf[st->buf_used++] = in_bytes[i];
        if (st->buf_used == 64) {
            ev_sha256_compress_block(st, st->buf);
            st->total_bits += 512;
            st->buf_used = 0;
        }
    }
}

static void ev_sha256_finish(ev_sha256_state_t *st, uint8_t digest[32]) {
    uint64_t final_bits = st->total_bits + ((uint64_t)st->buf_used * 8ULL);
    st->buf[st->buf_used++] = 0x80U;
    if (st->buf_used > 56) {
        while (st->buf_used < 64) {
            st->buf[st->buf_used++] = 0;
        }
        ev_sha256_compress_block(st, st->buf);
        st->buf_used = 0;
    }
    while (st->buf_used < 56) {
        st->buf[st->buf_used++] = 0;
    }
    for (int i = 0; i < 8; i++) {
        st->buf[56 + i] = (uint8_t)(final_bits >> ((7 - i) * 8));
    }
    ev_sha256_compress_block(st, st->buf);
    for (int i = 0; i < 8; i++) {
        digest[i * 4]     = (uint8_t)(st->h[i] >> 24);
        digest[i * 4 + 1] = (uint8_t)(st->h[i] >> 16);
        digest[i * 4 + 2] = (uint8_t)(st->h[i] >> 8);
        digest[i * 4 + 3] = (uint8_t)(st->h[i]);
    }
}

int everything_sha256(const unsigned char *data, size_t len, unsigned char *out) {
    if ((!data && len > 0) || !out) return -1;
    ev_sha256_state_t st;
    ev_sha256_init(&st);
    if (len > 0) {
        ev_sha256_feed(&st, data, len);
    }
    ev_sha256_finish(&st, out);
    return 0;
}

int everything_pbkdf2_hmac_sha256(const unsigned char *pass, size_t pass_len,
                                  const unsigned char *salt, size_t salt_len,
                                  unsigned int rounds, unsigned char *out) {
    if ((!pass && pass_len > 0) || (!salt && salt_len > 0) || !out || rounds == 0) return -1;

    uint8_t k_pad[64];
    memset(k_pad, 0, sizeof(k_pad));
    if (pass_len > 64) {
        everything_sha256(pass, pass_len, k_pad);
    } else if (pass_len > 0) {
        memcpy(k_pad, pass, pass_len);
    }

    uint8_t ipad[64], opad[64];
    for (int i = 0; i < 64; i++) {
        ipad[i] = k_pad[i] ^ 0x36U;
        opad[i] = k_pad[i] ^ 0x5cU;
    }

    ev_sha256_state_t inner_base, outer_base;
    ev_sha256_init(&inner_base);
    ev_sha256_feed(&inner_base, ipad, 64);
    ev_sha256_init(&outer_base);
    ev_sha256_feed(&outer_base, opad, 64);

    uint8_t block_idx[4] = {0, 0, 0, 1};
    uint8_t u[32], t[32], inner_hash[32];

    ev_sha256_state_t ic = inner_base;
    if (salt_len > 0) {
        ev_sha256_feed(&ic, salt, salt_len);
    }
    ev_sha256_feed(&ic, block_idx, 4);
    ev_sha256_finish(&ic, inner_hash);

    ev_sha256_state_t oc = outer_base;
    ev_sha256_feed(&oc, inner_hash, 32);
    ev_sha256_finish(&oc, u);
    memcpy(t, u, 32);

    for (unsigned int r = 1; r < rounds; r++) {
        ic = inner_base;
        ev_sha256_feed(&ic, u, 32);
        ev_sha256_finish(&ic, inner_hash);

        oc = outer_base;
        ev_sha256_feed(&oc, inner_hash, 32);
        ev_sha256_finish(&oc, u);

        for (int j = 0; j < 32; j++) {
            t[j] ^= u[j];
        }
    }

    memcpy(out, t, 32);
    return 0;
}

#endif

int everything_fast_digit_scan(const unsigned char *bytes, size_t len) {
    if (!bytes || len == 0) return 0;
    for (size_t i = 0; i < len; i++) {
        if (bytes[i] >= '0' && bytes[i] <= '9') return 1;
    }
    return 0;
}
