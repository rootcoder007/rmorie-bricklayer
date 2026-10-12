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
SEXP C_rmbl_flock_acquire(SEXP path, SEXP timeout_ms) {
    const char *p = rmbl_path_arg(path);
    int tmo = asInteger(timeout_ms);
    if (tmo == NA_INTEGER || tmo < 0) tmo = 0;
#ifdef _WIN32
    int fd = _open(p, _O_RDWR | _O_CREAT | _O_BINARY | _O_NOINHERIT, _S_IREAD | _S_IWRITE);
#else
    int fd = open(p, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0600);
#endif
    if (fd < 0) {
        int e = errno;
        error("cannot open the lock file %s: %s", p, strerror(e));
    }
    struct stat st;
    if (fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) {
        RMBL_CLOSE(fd);
        error("the lock file %s is not a regular file", p);
    }
    double start = rmbl_now_ms();
    for (;;) {
#ifdef _WIN32
        HANDLE h = (HANDLE) _get_osfhandle(fd);
        OVERLAPPED ov;
        memset(&ov, 0, sizeof ov);
        if (LockFileEx(h, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &ov)) break;
        DWORD e = GetLastError();
        if (e != ERROR_LOCK_VIOLATION && e != ERROR_IO_PENDING) {
            RMBL_CLOSE(fd);
            error("cannot lock %s (Windows error %lu)", p, (unsigned long) e);
        }
#else
        if (flock(fd, LOCK_EX | LOCK_NB) == 0) break;
        int e = errno;
        if (e != EWOULDBLOCK && e != EAGAIN && e != EINTR) {
            RMBL_CLOSE(fd);
            error("cannot lock %s: %s", p, strerror(e));
        }
#endif
        if (rmbl_now_ms() - start >= (double) tmo) {
            RMBL_CLOSE(fd);
            return ScalarInteger(-1);
        }
        rmbl_sleep_ms(20);
    }
    return ScalarInteger(fd);
}

SEXP C_rmbl_flock_release(SEXP fd_) {
    int fd = asInteger(fd_);
    if (fd == NA_INTEGER || fd < 0) return R_NilValue;
#ifdef _WIN32
    HANDLE h = (HANDLE) _get_osfhandle(fd);
    OVERLAPPED ov;
    memset(&ov, 0, sizeof ov);
    UnlockFileEx(h, 0, 1, 0, &ov);
#else
    flock(fd, LOCK_UN);
#endif
    RMBL_CLOSE(fd);
    return R_NilValue;
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

/* Write `bytes` to `tmp`, flush it to the disk (fsync / FlushFileBuffers) and only then rename it
 * over `path`; NULL on success, else a message. `tmp` is created here (O_EXCL), so the cleanup
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
    char msg[512];
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
#endif
    if (why != NULL) {
        snprintf(msg, sizeof msg, "%s: %s", why, strerror(err));
        remove(tmp);
        return mkString(msg);
    }
    return R_NilValue;
}
