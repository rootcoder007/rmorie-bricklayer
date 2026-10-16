/* Shared by every .Call entry point.
 *
 *   rmbl_str0() / rmbl_str_at()   a string argument, or an R error that
 *                                 names it -- never CHAR(STRING_ELT()) on
 *                                 something that is not a string
 *   rmbl::check_interrupt()       a pending Ctrl-C, raised as a C++
 *                                 exception so the destructors of every
 *                                 live object run before R sees it
 *   rmbl_interrupt_pending()      the same test for the extern "C" kernels
 *                                 LinkingTo packages call: they must not
 *                                 throw, so they stop and set a flag the
 *                                 entry point raises afterwards
 *
 * rmbl_barrier.cpp wraps each registered entry point in a try/catch that
 * turns any C++ exception (a std::vector that cannot be sized, bad_alloc,
 * a length_error from an NA argument) into an R error instead of
 * std::terminate(). The wrapper raises only after the try block has
 * closed, so no R longjmp passes over a live C++ object there.
 */
#ifndef RMBL_ENTRY_H
#define RMBL_ENTRY_H

#include <R.h>
#include <Rinternals.h>
#include <cstddef>

#ifdef __cplusplus
extern "C" {
#endif
/* set by a kernel that stopped early on a pending interrupt; the entry
 * point's barrier clears it and raises the interrupt */
extern int rmbl_kernel_interrupted;
/* non-jumping test for a pending user interrupt (never raises) */
int rmbl_interrupt_pending(void);
/* an exported kernel that stopped on a pending interrupt calls this AFTER
 * its buffers are released: with no barrier on the stack it raises R's
 * interrupt from a frame with no C++ object; under a barrier it is a no-op */
void rmbl_interrupt_raise_unbarriered(void);
#ifdef __cplusplus
}
#endif

static inline const char *rmbl_str0(SEXP x, const char *name) {
    if (TYPEOF(x) != STRSXP || XLENGTH(x) < 1 || STRING_ELT(x, 0) == NA_STRING) {
        Rf_error("`%s` must be a non-missing string", name);
    }
    return CHAR(STRING_ELT(x, 0));
}

/* the byte length R stores for the first string (no strlen() over bytes
 * that may be secret); the type check is rmbl_str0()'s */
static inline size_t rmbl_str0_len(SEXP x, const char *name) {
    (void)rmbl_str0(x, name);
    return (size_t)LENGTH(STRING_ELT(x, 0));
}

static inline const char *rmbl_str_at(SEXP x, R_xlen_t i, const char *name) {
    if (TYPEOF(x) != STRSXP || i < 0 || i >= XLENGTH(x)) {
        Rf_error("`%s` must be a character vector", name);
    }
    if (STRING_ELT(x, i) == NA_STRING) {
        Rf_error("`%s` contains a missing string (element %d)", name, (int)(i + 1));
    }
    return CHAR(STRING_ELT(x, i));
}

#ifdef __cplusplus
#include <cstdarg>
#include <cstdio>
#include <new>
#include <stdexcept>
namespace rmbl {
struct Interrupt {};
inline void check_interrupt() {
    if (rmbl_interrupt_pending()) throw Interrupt();
}

/* An argument error from inside an entry point's body, said as Rf_error() says it but raised by the
 * barrier after the body's C++ objects are destroyed: Rf_error() jumped over live std::vectors and
 * strings and leaked them (a header with a line break, a negative value for gini(); CRAN stress
 * test of b617a3f, LSan). Only for code that runs under the barrier (the _impl bodies). */
struct Fail : std::runtime_error {
    explicit Fail(const char *m) : std::runtime_error(m) {}
};
[[noreturn]] inline void fail(const char *fmt, ...) {
    char buf[8192];
    va_list ap;
    va_start(ap, fmt);
    std::vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    throw Fail(buf);
}

/* Rf_allocVector() for a large result, with an allocation failure thrown as std::bad_alloc instead of
 * R's longjmp, so the C++ buffers that hold the result's contents are freed (sen_slopes() leaked 858 MB
 * at each failed allocation; CRAN stress test of b617a3f). A small vector is allocated directly: the
 * catch costs an R call. */
struct AllocArgs { SEXPTYPE type; R_xlen_t n; };
inline SEXP alloc_body(void *d) {
    const AllocArgs *a = static_cast<const AllocArgs *>(d);
    return Rf_allocVector(a->type, a->n);
}
inline SEXP alloc_failed(SEXP, void *flag) {
    *static_cast<int *>(flag) = 1;
    return R_NilValue;
}
inline SEXP alloc_vector(SEXPTYPE type, R_xlen_t n) {
    if (n < 65536) return Rf_allocVector(type, n);
    AllocArgs a = {type, n};
    int failed = 0;
    SEXP r = R_tryCatchError(alloc_body, &a, alloc_failed, &failed);
    if (failed) throw std::bad_alloc();
    return r;
}
}  // namespace rmbl
#endif

#endif
