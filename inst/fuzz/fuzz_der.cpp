/* libFuzzer target: the DER parser and the RSA big-integer arithmetic.
 * Both read bytes a signature envelope hands them; a crash, an overflow or
 * an out-of-bounds read here is what the sanitizers turn into a failure. */
#include "../../src/rmbl_asn1.cpp"

/* The kernels test for a pending interrupt through rmbl_barrier.cpp, which
 * is R's; this binary runs with no R session, so nothing is ever pending. */
extern "C" int rmbl_kernel_interrupted = 0;
extern "C" int rmbl_interrupt_pending(void) { return 0; }


extern "C" int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
    if (size == 0) return 0;
    const unsigned char mode = data[0];
    const unsigned char *p = data + 1;
    const size_t n = size - 1;
    if (mode & 1) {
        size_t pos = 0, budget = kMaxNodes;
        Node out;
        (void)parse_one(p, n, pos, out, 0, budget);
        return 0;
    }
    /* sig^e mod m over three slices of the input (the RSA recovery path) */
    if (n < 3) return 0;
    const size_t a = n / 3, b = n / 3;
    if (n - a - b > 64) return 0;   /* the entry point caps the exponent at 64 bytes */
    Big sig = from_bytes(p, a);
    Big mod = from_bytes(p + a, b);
    Big e = from_bytes(p + a + b, n - a - b);
    if (mod.empty() || (mod.size() == 1 && mod[0] == 0)) return 0;
    if (cmp(sig, mod) >= 0) return 0;
    Big r = modexp(sig, e, mod);
    (void)r;
    return 0;
}
