/*
 * An exclusive advisory lock on a file, held by an open descriptor: the kernel drops it when
 * the descriptor is closed or the process dies, so a crashed R session never leaves a lock
 * behind and no process ever has to decide that someone else's lock is stale (the lock
 * directory of 0.5.12-pre was taken over after 60 s by check-then-delete, which let two
 * signers hold it at once; review of 52a8883, B2/B4).
 *
 * POSIX: flock(2) on a regular file opened O_NOFOLLOW. Windows: LockFileEx on one byte.
 * The wait is bounded by the caller's timeout and polls every 20 ms; it draws no random
 * numbers, so lock contention never moves the session's RNG stream.
 */
#include <R.h>
#include <Rinternals.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#define RMBL_CLOSE _close
#else
#include <unistd.h>
#include <sys/file.h>
#include <time.h>
#define RMBL_CLOSE close
#endif

/* rmbl_barrier.cpp: the non-jumping interrupt test and the raise for a frame with no barrier */
extern int rmbl_kernel_interrupted;
int rmbl_interrupt_pending(void);
void rmbl_interrupt_raise_unbarriered(void);

#ifndef S_ISREG
#define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#endif
#ifndef S_ISDIR
#define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#endif
#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif
#ifndef O_NOFOLLOW
#define O_NOFOLLOW 0
#endif

static void rmbl_sleep_ms(int ms) {
#ifdef _WIN32
    Sleep((DWORD) ms);
#else
    struct timespec ts;
    ts.tv_sec = ms / 1000;
    ts.tv_nsec = (long) (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
#endif
}

/* Milliseconds on a monotonic clock: the wait is measured, not counted. Counting 20 ms per poll
 * let a "10 s" wait run past 16 s on macOS, whose sleeps overshoot (review CI, f38cfb1). */
static double rmbl_now_ms(void) {
#ifdef _WIN32
    return (double) GetTickCount64();
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double) ts.tv_sec * 1000.0 + (double) ts.tv_nsec / 1e6;
#endif
}

static const char *rmbl_path_arg(SEXP path) {
    if (!isString(path) || XLENGTH(path) != 1 || STRING_ELT(path, 0) == NA_STRING)
        error("`path` must be a single file path");
    return R_ExpandFileName(translateChar(STRING_ELT(path, 0)));
}

/* The descriptor of the held lock, or -1 when another process holds it past the timeout. */
static int rmbl_flock_try(const char *p, int tmo) {
#ifdef _WIN32
    int fd = _open(p, _O_RDWR | _O_CREAT | _O_BINARY | _O_NOINHERIT, _S_IREAD | _S_IWRITE);
#else
    int fd = open(p, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0600);
#endif
    if (fd < 0) {
        int e = errno;
        error("cannot open the lock file %s: %s", p, strerror(e));
    }
    /* one exit for every refusal: a lock file that is not a regular file, or a lock call that fails
     * for any reason but "held by another process" */
    struct stat st;
    const char *why = NULL;
    int e = 0;
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) why = "is not a regular file";
    double start = rmbl_now_ms();
    while (why == NULL) {
#ifdef _WIN32
        HANDLE h = (HANDLE) _get_osfhandle(fd);
        OVERLAPPED ov;
        memset(&ov, 0, sizeof ov);
        if (LockFileEx(h, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &ov)) return fd;
        DWORD we = GetLastError();
        if (we != ERROR_LOCK_VIOLATION && we != ERROR_IO_PENDING) { why = "cannot be locked"; e = EACCES; continue; }
#else
        if (flock(fd, LOCK_EX | LOCK_NB) == 0) return fd;
        e = errno;
        if (e != EWOULDBLOCK && e != EAGAIN && e != EINTR) { why = "cannot be locked"; continue; }
#endif
        if (rmbl_now_ms() - start >= (double) tmo) {
            RMBL_CLOSE(fd);
            return -1;
        }
        /* a Ctrl-C (or a setTimeLimit() limit) during the wait ends it: the descriptor is closed
         * first, then the interrupt is raised from this frame, which holds nothing else (the wait
         * ran its whole timeout through one; review of 1.0.0) */
        if (rmbl_interrupt_pending()) {
            RMBL_CLOSE(fd);
            rmbl_kernel_interrupted = 0;
            rmbl_interrupt_raise_unbarriered();
            return -1;
        }
        rmbl_sleep_ms(20);
    }
    RMBL_CLOSE(fd);
    if (e != 0) error("the lock file %s %s: %s", p, why, strerror(e));
    error("the lock file %s %s", p, why);
    return -1; /* not reached */
}

SEXP C_rmbl_flock_acquire(SEXP path, SEXP timeout_ms) {
    int tmo = asInteger(timeout_ms);
    if (tmo == NA_INTEGER || tmo < 0) tmo = 0;
    return ScalarInteger(rmbl_flock_try(rmbl_path_arg(path), tmo));
}

static void rmbl_flock_close(int fd) {
#ifdef _WIN32
    HANDLE h = (HANDLE) _get_osfhandle(fd);
    OVERLAPPED ov;
    memset(&ov, 0, sizeof ov);
    UnlockFileEx(h, 0, 1, 0, &ov);
#else
    flock(fd, LOCK_UN);
#endif
    RMBL_CLOSE(fd);
}

SEXP C_rmbl_flock_release(SEXP fd_) {
    int fd = asInteger(fd_);
    if (fd == NA_INTEGER || fd < 0) return R_NilValue;
    /* stdin, stdout and stderr are never a lock: closing 1 shut R's console output */
    if (fd <= 2) error("descriptor %d is not a lock this package holds", fd);
    rmbl_flock_close(fd);
    return R_NilValue;
}

/* Take the lock and run `fn()` under it in one C frame, the release registered with R as the
 * cleanup of that frame (R_ExecWithCleanup): an error or a Ctrl-C anywhere inside fn() unwinds
 * through the cleanup and the descriptor is closed. Nothing R-level runs between the lock being
 * taken and the release being registered, so no interrupt can land in the gap (an on.exit()
 * handler is itself R code that an interrupt can cut short before its .Call: 73 to 95 locks per
 * 5,000 interrupts stayed held for the rest of the session; review of 29a55d8, G6). `busy` is
 * returned as is when another process holds the lock: the caller waits in R, where Ctrl-C works,
 * and asks again. */
static SEXP rmbl_flock_call_fn(void *d) {
    SEXP call = PROTECT(lang1((SEXP) d));
    SEXP r = eval(call, R_GlobalEnv);
    UNPROTECT(1);
    return r;
}
static void rmbl_flock_cleanup(void *d) {
    rmbl_flock_close(*(int *) d);
}
SEXP C_rmbl_flock_with(SEXP path, SEXP fn, SEXP busy) {
    if (!isFunction(fn)) error("`fn` must be a function");
    int fd = rmbl_flock_try(rmbl_path_arg(path), 0);
    if (fd < 0) return busy;
    return R_ExecWithCleanup(rmbl_flock_call_fn, (void *) fn, rmbl_flock_cleanup, &fd);
}

/* "missing", "regular", "directory" or "other" (a device, a FIFO, a socket): the used-index
 * record must be a regular file, so "/dev/null" is refused rather than renamed over (B7). */
SEXP C_rmbl_path_kind(SEXP path) {
    const char *p = rmbl_path_arg(path);
    struct stat st;
    if (stat(p, &st) != 0) return mkString(errno == ENOENT || errno == ENOTDIR ? "missing" : "other");
    if (S_ISREG(st.st_mode)) return mkString("regular");
    if (S_ISDIR(st.st_mode)) return mkString("directory");
    return mkString("other");
}

/* Write `bytes` to `tmp`, check its size, flush it to the disk (fsync / FlushFileBuffers), rename
 * it over `path` and flush the directory entry; NULL on success, else a message. `tmp` is created here (O_EXCL), so the cleanup
 * only ever removes a file this call made. A short write, a full disk (ENOSPC, which a delayed
 * allocation may report only at fsync or close) or a failed rename takes the one exit at the end:
 * `tmp` removed, the old record untouched (review of 52a8883, B3). */
SEXP C_rmbl_write_file_checked(SEXP tmp_, SEXP path_, SEXP bytes) {
    if (TYPEOF(bytes) != RAWSXP) error("`bytes` must be a raw vector");
    char tmp[4096], path[4096];
    const char *t = rmbl_path_arg(tmp_);
    if (strlen(t) >= sizeof tmp) error("path too long");
    strcpy(tmp, t);
    const char *q = rmbl_path_arg(path_);
    if (strlen(q) >= sizeof path) error("path too long");
    strcpy(path, q);
    const unsigned char *b = RAW(bytes);
    size_t n = (size_t) XLENGTH(bytes);
    /* room for a whole path and its error (gcc -Wformat-truncation: 512 cut a long path short) */
    char msg[sizeof tmp + 256];
#ifdef _WIN32
    int fd = _open(tmp, _O_WRONLY | _O_CREAT | _O_EXCL | _O_BINARY | _O_NOINHERIT, _S_IREAD | _S_IWRITE);
#else
    int fd = open(tmp, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
#endif
    if (fd < 0) {
        snprintf(msg, sizeof msg, "cannot create %s: %s", tmp, strerror(errno));
        return mkString(msg);
    }
    const char *why = NULL;
    int err = 0;
    size_t off = 0;
    while (off < n && why == NULL) {
#ifdef _WIN32
        int w = _write(fd, b + off, (unsigned int) (n - off > 1048576 ? 1048576 : n - off));
#else
        ssize_t w = write(fd, b + off, n - off);
#endif
        if (w > 0) off += (size_t) w;
        else if (!(w < 0 && errno == EINTR)) { why = "the write did not complete"; err = w < 0 ? errno : ENOSPC; }
    }
    /* the file holds exactly the bytes asked for */
    struct stat st;
    if (why == NULL && (fstat(fd, &st) != 0 || (size_t) st.st_size != n)) { why = "the write did not complete"; err = EIO; }
#ifdef _WIN32
    if (why == NULL && !FlushFileBuffers((HANDLE) _get_osfhandle(fd))) { why = "the write did not reach the disk"; err = EIO; }
#else
    if (why == NULL && fsync(fd) != 0) { why = "the write did not reach the disk"; err = errno; }
#endif
    if (RMBL_CLOSE(fd) != 0 && why == NULL) { why = "the write did not reach the disk"; err = errno; }
#ifdef _WIN32
    if (why == NULL && !MoveFileExA(tmp, path, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        why = "the new record could not replace the old one";
        err = EACCES;
    }
#else
    if (why == NULL && rename(tmp, path) != 0) { why = "the new record could not replace the old one"; err = errno; }
    if (why == NULL) {
        /* the rename is an entry in the directory: flush it too, or after a power cut the old
         * record can come back. A file system that cannot fsync a directory (EINVAL) is let be. */
        char dir[4096];
        strcpy(dir, path);
        char *slash = strrchr(dir, '/');
        if (slash == dir) dir[1] = 0; else if (slash) *slash = 0; else strcpy(dir, ".");
        int dfd = open(dir, O_RDONLY | O_CLOEXEC);
        if (dfd >= 0) {
            if (fsync(dfd) != 0 && errno != EINVAL && errno != EROFS) { why = "the new record did not reach the disk"; err = errno; }
            close(dfd);
        }
        /* a failure here takes the one exit below: the rename is done, so its remove(tmp) finds
         * nothing and the message is all that is left to give */
    }
#endif
    if (why != NULL) {
        snprintf(msg, sizeof msg, "%s: %s", why, strerror(err));
        remove(tmp);
        return mkString(msg);
    }
    return R_NilValue;
}

/*
 * Wipes an environment variable's value in place, before the R side unsets it. unsetenv() takes
 * the name out of environ, but for a variable the process was started with the bytes stay where
 * the kernel put them, and /proc/self/environ still showed RMBL_KEY's value (audit of 30bed8e,
 * #17). getenv() points at those bytes. Windows keeps no such copy (its CRT holds its own), so
 * there nothing is written.
 */
SEXP C_rmbl_env_wipe(SEXP name) {
    if (!isString(name) || XLENGTH(name) != 1 || STRING_ELT(name, 0) == NA_STRING)
        error("`name` must be one string");
#ifndef _WIN32
    char *v = getenv(CHAR(STRING_ELT(name, 0)));
    if (v != NULL) memset(v, 0, strlen(v));
    return ScalarLogical(v != NULL);
#else
    return ScalarLogical(getenv(CHAR(STRING_ELT(name, 0))) != NULL);
#endif
}
