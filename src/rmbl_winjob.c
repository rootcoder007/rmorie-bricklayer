/*
 * rmbl_winjob.c: runs a bundle check's command line on Windows inside a
 * job object created with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE, so every
 * process the run starts (and every process those start) belongs to the
 * job, and closing the job kills them all. The wait is bounded by the
 * time limit, polls every 100 ms and honours a Ctrl-C (the non-jumping
 * interrupt test; the job is killed before the interrupt is raised).
 *
 * Windows only. Elsewhere the entry point is a stub that refuses: the R
 * side calls it only on Windows (mkbndlchk() runs the bundle in a PID
 * namespace or a process group there instead).
 */
#include <R.h>
#include <Rinternals.h>

#ifdef _WIN32
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601 /* GetTickCount64: Windows 7 and later */
#endif
#include <windows.h>
#include <string.h>

/* rmbl_barrier.cpp: the non-jumping interrupt test and the raise */
extern int rmbl_kernel_interrupted;
int rmbl_interrupt_pending(void);
void rmbl_interrupt_raise_unbarriered(void);

/* A UTF-8 R string as a writable wide string (R_alloc: freed by R). */
static wchar_t *rmbl_wjob_wide(SEXP s, const char *what) {
    const char *u = translateCharUTF8(STRING_ELT(s, 0));
    int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u, -1, NULL, 0);
    if (n <= 0) error("the %s is not valid UTF-8", what);
    wchar_t *w = (wchar_t *) R_alloc((size_t) n, sizeof(wchar_t));
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, u, -1, w, n);
    return w;
}

/* The job, set to kill every process in it when its last handle closes. */
static HANDLE rmbl_wjob_new(void) {
    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (job == NULL) return NULL;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION li;
    memset(&li, 0, sizeof li);
    li.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation,
                                 &li, sizeof li)) {
        CloseHandle(job);
        return NULL;
    }
    return job;
}

/* Waits for the process: its exit code, 124 at the time limit, -2 on an
 * interrupt, -1 when the wait fails. */
static int rmbl_wjob_wait(HANDLE proc, double limit_ms) {
    ULONGLONG start = GetTickCount64();
    for (;;) {
        DWORD w = WaitForSingleObject(proc, 100);
        if (w == WAIT_OBJECT_0) {
            DWORD ec = 1;
            if (!GetExitCodeProcess(proc, &ec)) return -1;
            return (int) ec;
        }
        if (w != WAIT_TIMEOUT) return -1;
        if (rmbl_interrupt_pending()) return -2;
        if ((double) (GetTickCount64() - start) >= limit_ms) return 124;
    }
}

SEXP C_rmbl_winjob(SEXP cmd, SEXP log, SEXP tmout) {
    if (!isString(cmd) || LENGTH(cmd) != 1 || !isString(log) ||
        LENGTH(log) != 1)
        error("the command line and the log must be single strings");
    double limit = asReal(tmout);
    if (ISNAN(limit) || limit <= 0) error("the time limit must be positive");
    wchar_t *wcmd = rmbl_wjob_wide(cmd, "command line");
    wchar_t *wlog = rmbl_wjob_wide(log, "log file name");

    SECURITY_ATTRIBUTES sa;
    memset(&sa, 0, sizeof sa);
    sa.nLength = sizeof sa;
    sa.bInheritHandle = TRUE;
    HANDLE out = CreateFileW(wlog, FILE_APPEND_DATA,
                             FILE_SHARE_READ | FILE_SHARE_WRITE, &sa,
                             OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (out == INVALID_HANDLE_VALUE) error("cannot open the log file");
    HANDLE in = CreateFileW(L"NUL", GENERIC_READ,
                            FILE_SHARE_READ | FILE_SHARE_WRITE, &sa,
                            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    HANDLE job = rmbl_wjob_new();
    if (job == NULL || in == INVALID_HANDLE_VALUE) {
        DWORD e = GetLastError();
        if (job != NULL) CloseHandle(job);
        if (in != INVALID_HANDLE_VALUE) CloseHandle(in);
        CloseHandle(out);
        error("cannot set up the job object (Windows error %lu)",
              (unsigned long) e);
    }

    STARTUPINFOW si;
    memset(&si, 0, sizeof si);
    si.cb = sizeof si;
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = in;
    si.hStdOutput = out;
    si.hStdError = out;
    PROCESS_INFORMATION pi;
    memset(&pi, 0, sizeof pi);
    /* started suspended, so it is in the job before it can start anything */
    BOOL ok = CreateProcessW(NULL, wcmd, NULL, NULL, TRUE,
                             CREATE_SUSPENDED | CREATE_NO_WINDOW, NULL, NULL,
                             &si, &pi);
    DWORD e = ok ? 0 : GetLastError();
    CloseHandle(in);
    CloseHandle(out);
    if (!ok) {
        CloseHandle(job);
        error("cannot start the run (Windows error %lu)", (unsigned long) e);
    }
    if (!AssignProcessToJobObject(job, pi.hProcess)) {
        e = GetLastError();
        TerminateProcess(pi.hProcess, 1);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        CloseHandle(job);
        error("cannot put the run in a job object (Windows error %lu)",
              (unsigned long) e);
    }
    ResumeThread(pi.hThread);
    CloseHandle(pi.hThread);

    int rc = rmbl_wjob_wait(pi.hProcess, limit * 1000.0);
    /* whatever the run left behind is in the job: kill it, then close */
    TerminateJobObject(job, 1);
    CloseHandle(pi.hProcess);
    CloseHandle(job);
    if (rc == -2) {
        rmbl_kernel_interrupted = 0;
        rmbl_interrupt_raise_unbarriered();
        rc = 130; /* reached only when the raise returns under a barrier */
    }
    return ScalarInteger(rc);
}

#else

SEXP C_rmbl_winjob(SEXP cmd, SEXP log, SEXP tmout) {
    (void) cmd;
    (void) log;
    (void) tmout;
    error("the job-object runner is for Windows only");
    return R_NilValue; /* not reached */
}

#endif
