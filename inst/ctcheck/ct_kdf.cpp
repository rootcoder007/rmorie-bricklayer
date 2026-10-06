#include "ct_common.h"

extern "C" {
void rmbl_hmac_sha256_hex(const unsigned char *key, size_t keylen, const unsigned char *msg, size_t msglen, char out[65]);
void rmbl_pbkdf2_sha256(const unsigned char *pass, size_t passlen, const unsigned char *salt, size_t saltlen, int iterations, int dklen, unsigned char *out);
int rmbl_blake2b(const unsigned char *msg, size_t msglen, const unsigned char *key, size_t keylen, int outlen, unsigned char *out);
void rmbl_sha256_raw(const unsigned char *data, size_t len, unsigned char out[32]);
void rmbl_sha512_raw(const unsigned char *data, size_t len, unsigned char out[64]);
void rmbl_sha3_256(unsigned char out[32], const unsigned char *in, size_t len);
void rmbl_shake256(unsigned char *out, size_t outlen, const unsigned char *in, size_t len);
int rmbl_digest_equal(const char *a, const char *b, size_t n);
}

int ct_hmac_sha256() {
    unsigned char key[77], msg[200];
    char out[65];
    ct_fill(key, sizeof key, 61);
    ct_fill(msg, sizeof msg, 62);
    ct_secret(key, sizeof key);
    rmbl_hmac_sha256_hex(key, sizeof key, msg, sizeof msg, out);
    const int rem = ct_stack_remnants(key, sizeof key, "HMAC key");
    ct_public(out, sizeof out);
    return rem ? 3 : 0;
}

int ct_pbkdf2() {
    unsigned char pass[19], salt[16], out[48];
    ct_fill(pass, sizeof pass, 63);
    ct_fill(salt, sizeof salt, 64);
    ct_secret(pass, sizeof pass);
    rmbl_pbkdf2_sha256(pass, sizeof pass, salt, sizeof salt, 3, sizeof out, out);
    const int rem = ct_stack_remnants(pass, sizeof pass, "PBKDF2 password");
    ct_public(out, sizeof out);
    return rem ? 3 : 0;
}

int ct_blake2b_keyed() {
    unsigned char key[32], msg[300], out[64];
    ct_fill(key, sizeof key, 65);
    ct_fill(msg, sizeof msg, 66);
    ct_secret(key, sizeof key);
    if (rmbl_blake2b(msg, sizeof msg, key, sizeof key, 64, out) != 0) return 1;
    const int rem = ct_stack_remnants(key, sizeof key, "BLAKE2b key");
    ct_public(out, sizeof out);
    return rem ? 3 : 0;
}

int ct_sha2() {
    unsigned char msg[333], o32[32], o64[64];
    ct_fill(msg, sizeof msg, 67);
    ct_secret(msg, sizeof msg);
    rmbl_sha256_raw(msg, sizeof msg, o32);
    rmbl_sha512_raw(msg, sizeof msg, o64);
    ct_public(o32, 32);
    ct_public(o64, 64);
    return 0;
}

int ct_sha3() {
    unsigned char msg[333], o32[32], o[100];
    ct_fill(msg, sizeof msg, 68);
    ct_secret(msg, sizeof msg);
    rmbl_sha3_256(o32, msg, sizeof msg);
    rmbl_shake256(o, sizeof o, msg, sizeof msg);
    ct_public(o32, 32);
    ct_public(o, sizeof o);
    return 0;
}

int ct_digest_equal() {
    char a[65], b[65];
    ct_fill(reinterpret_cast<unsigned char *>(a), 64, 69);
    std::memcpy(b, a, 65);
    a[64] = b[64] = 0;
    b[7] ^= 1;
    ct_secret(a, 64);
    ct_secret(b, 64);
    int r1 = rmbl_digest_equal(a, a, 64);
    int r2 = rmbl_digest_equal(a, b, 64);
    ct_public(&r1, sizeof r1);
    ct_public(&r2, sizeof r2);
    return (r1 == 1 && r2 == 0) ? 0 : 1;
}
