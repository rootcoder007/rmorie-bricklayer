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
#include <cstdio>

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

/* An argument error. Under the barrier (C++) it is thrown and raised by the barrier once the body's
 * C++ objects are destroyed: Rf_error() jumped over live std::vectors and strings and leaked them
 * (merkle chunks, an NA url with headers set, blake2b with an NA element; LSan, CRAN stress test of
 * 0.5.14). Outside any barrier, and in C, it is Rf_error(). */
#ifdef __cplusplus
extern "C" int rmbl_barrier_active(void);
[[noreturn]] void rmbl_arg_error(const char *fmt, ...);
#define RMBL_ARG_ERROR rmbl_arg_error
#else
#define RMBL_ARG_ERROR Rf_error
#endif

static inline const char *rmbl_str0(SEXP x, const char *name) {
    if (TYPEOF(x) != STRSXP || XLENGTH(x) < 1 || STRING_ELT(x, 0) == NA_STRING) {
        RMBL_ARG_ERROR("`%s` must be a non-missing string", name);
    }
    return CHAR(STRING_ELT(x, 0));
}

/* the byte length R stores for the first string (no strlen() over bytes
 * that may be secret); the type check is rmbl_str0()'s */
static inline size_t rmbl_str0_len(SEXP x, const char *name) {
    (void)rmbl_str0(x, name);
    return (size_t)LENGTH(STRING_ELT(x, 0));
}

/* every caller coerces to a character vector and stays in its range first, so `bad` is never set
 * there: it is refused with the missing string, by the check the tests reach, and named as what
 * it is (STRING_ELT() is not read when `bad`) */
static inline const char *rmbl_str_at(SEXP x, R_xlen_t i, const char *name) {
    const int bad = TYPEOF(x) != STRSXP || i < 0 || i >= XLENGTH(x);
    if (bad || STRING_ELT(x, i) == NA_STRING) {
        char what[64];
        snprintf(what, sizeof what, "contains a missing string (element %d)", (int)(i + 1));
        RMBL_ARG_ERROR("`%s` %s", name, bad ? "must be a character vector" : what);
    }
    return CHAR(STRING_ELT(x, i));
}

#ifdef __cplusplus
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <new>
#include <stdexcept>
#include <type_traits>
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
}  // namespace rmbl

[[noreturn]] inline void rmbl_arg_error(const char *fmt, ...) {
    char buf[8192];
    va_list ap;
    va_start(ap, fmt);
    std::vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (rmbl_barrier_active()) throw rmbl::Fail(buf);
    Rf_error("%s", buf);
}

namespace rmbl {

/* The plain-C kernels published with R_RegisterCCallable run with no barrier when another package
 * calls them: a std::vector that cannot be sized, or a pending interrupt the body raises with
 * check_interrupt(), reached the extern "C" boundary as std::terminate() (review of 1.0.0, M12).
 * kernel_call() runs the body in a try block and, once it has closed and the body's objects are
 * gone, raises what it caught: an R error (thrown instead when a barrier is active, as every
 * argument error is) or R's interrupt. A value-returning body gives NaN (or T()) when it did not
 * finish. */
inline void kernel_raise(const char *msg, bool intr) {
    if (intr) {
        rmbl_kernel_interrupted = 1;
        rmbl_interrupt_raise_unbarriered();   /* returns under a barrier, which raises it */
    } else if (msg[0]) {
        rmbl_arg_error("%s", msg);
    }
}
#define RMBL_KERNEL_CATCH(msg, intr)                                                         \
    catch (const rmbl::Interrupt &) { intr = true; }                                         \
    catch (const std::bad_alloc &) { std::snprintf(msg, sizeof msg, "out of memory"); }      \
    catch (const std::exception &e) { std::snprintf(msg, sizeof msg, "%s", e.what()); }      \
    catch (...) { std::snprintf(msg, sizeof msg, "a C++ exception in a native kernel"); }
template <class F>
auto kernel_call(F &&f) -> decltype(f()) {
    using T = decltype(f());
    char msg[512] = "";
    bool intr = false;
    if constexpr (std::is_void<T>::value) {
        try { f(); } RMBL_KERNEL_CATCH(msg, intr)
        kernel_raise(msg, intr);
    } else {
        T r = T();
        bool done = false;
        try { r = f(); done = true; } RMBL_KERNEL_CATCH(msg, intr)
        kernel_raise(msg, intr);
        if constexpr (std::is_floating_point<T>::value) {
            if (!done) r = static_cast<T>(NAN);
        }
        return r;
    }
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
