/*
 * rmbl_reap.c: what a bundle check needs to find every process a run left
 * behind on Linux. With PR_SET_CHILD_SUBREAPER set on this R process, a
 * process whose parent dies is re-parented to it instead of to init, so a
 * process that left the run's process group and session (setsid, a double
 * fork, a cleared environment) stays a descendant of this process and is
 * found, killed and reaped by its exact PID.
 *
 * Linux only. Elsewhere C_rmbl_subreap() answers FALSE (the R side then
 * says it cannot detect escaped processes) and C_rmbl_reap() reaps what
 * it can with waitpid().
 */
#include <R.h>
#include <Rinternals.h>

#ifndef _WIN32
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#endif
#ifdef __linux__
#include <sys/prctl.h>
#endif

/* Sets (on = TRUE) or clears the child subreaper flag of this process.
 * Returns TRUE when the flag is now as asked. */
SEXP C_rmbl_subreap(SEXP on) {
    int want = asLogical(on);
    if (want == NA_LOGICAL) error("`on` must be TRUE or FALSE");
#if defined(__linux__) && defined(PR_SET_CHILD_SUBREAPER)
    int r = prctl(PR_SET_CHILD_SUBREAPER, (unsigned long) (want ? 1 : 0),
                  0UL, 0UL, 0UL);
    return ScalarLogical(r == 0);
#else
    return ScalarLogical(FALSE);
#endif
}

/* Reaps the given child processes that have exited (never waits).
 * Returns how many were reaped. */
SEXP C_rmbl_reap(SEXP pids) {
    SEXP p = PROTECT(coerceVector(pids, INTSXP));
    int n = 0;
#ifndef _WIN32
    for (R_xlen_t i = 0; i < XLENGTH(p); i++) {
        int pid = INTEGER(p)[i];
        if (pid == NA_INTEGER || pid <= 1) continue;
        int st;
        pid_t r;
        do {
            r = waitpid((pid_t) pid, &st, WNOHANG);
        } while (r < 0 && errno == EINTR);
        if (r == (pid_t) pid) n++;
    }
#endif
    UNPROTECT(1);
    return ScalarInteger(n);
}
