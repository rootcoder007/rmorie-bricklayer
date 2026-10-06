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
/* non-jumping test for a pending user interrupt */
int rmbl_interrupt_pending(void);
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
namespace rmbl {
struct Interrupt {};
inline void check_interrupt() {
    if (rmbl_interrupt_pending()) throw Interrupt();
}
}  // namespace rmbl
#endif

#endif
