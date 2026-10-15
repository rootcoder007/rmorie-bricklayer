/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Animated progress bars, drawn in C so every caller in the MORIE family (R
 * here, and rmorie / rmoriedata through LinkingTo) gets the same look: the
 * filled part with a shimmer travelling along it, a head that fills in
 * eighths and pulses while work is going on, then the empty track; and a
 * spinner. One frame per call: the caller owns the timing and the easing,
 * so the renderer has no state and is safe to call from anywhere.
 *
 * Colour only when asked for, at the console's depth (the R side decides it,
 * .bl_console() in R/progress_anim.R): `color` is 0 for none, 1 for 24-bit
 * (what TRUE has always meant), or the number of colours the console shows --
 * 16777216 for 24-bit, 256 for the 6x6x6 cube (the RStudio console), 8 or 16
 * for the basic colours, without the shimmer. `unicode = 0` draws the same
 * bar in ASCII for a console that cannot show block characters.
 */
#include <R.h>
#include <Rinternals.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#define RMBL_BAR_MAX_WIDTH 200

typedef struct {
    char *b;
    size_t n, cap;
} rmbl_buf;

static void put(rmbl_buf *o, const char *s) {
    size_t l = strlen(s);
    if (o->n + l + 1 > o->cap) return;   /* never overruns: the caller sized it for the widest bar */
    memcpy(o->b + o->n, s, l);
    o->n += l;
    o->b[o->n] = '\0';
}

/* NaN is not below, above or between: it would be cast to INT_MIN (a sibling of E13) */
static int clamp255(double v) { return !(v == v) ? 0 : v < 0 ? 0 : v > 255 ? 255 : (int) (v + 0.5); }

/* The escape for a foreground colour at `ncolors` colours into `out` (`cap` bytes; 32 is enough),
 * "" below 8: 24-bit, the nearest of the 6x6x6 cube of 256, or the basic colour made of the
 * channels within a quarter of the brightest (blue gives cyan, amber yellow, violet blue). The R
 * side's .bl_sgr() is the same mapping; rmbl_fetch.cpp colours the native spinner with it. */
int rmbl_progress_fg(char *out, int cap, int r, int g, int b, int ncolors) {
    if (cap <= 0) return 0;
    out[0] = '\0';
    r = clamp255(r);
    g = clamp255(g);
    b = clamp255(b);
    int n = 0;
    if (ncolors == 1 || ncolors >= 16777216) {
        n = snprintf(out, (size_t) cap, "\033[38;2;%d;%d;%dm", r, g, b);
    } else if (ncolors >= 256) {
        const int q = 16 + 36 * ((r * 5 + 127) / 255) + 6 * ((g * 5 + 127) / 255) + (b * 5 + 127) / 255;
        n = snprintf(out, (size_t) cap, "\033[38;5;%dm", q);
    } else if (ncolors >= 8) {
        const int m = r > g ? (r > b ? r : b) : (g > b ? g : b);
        const int c = (4 * r >= 3 * m) + 2 * (4 * g >= 3 * m) + 4 * (4 * b >= 3 * m);
        n = snprintf(out, (size_t) cap, "\033[%dm", 30 + c);
    }
    if (n < 0 || n >= cap) out[0] = '\0';
    return out[0] ? n : 0;
}

static void put_rgb(rmbl_buf *o, int r, int g, int b, int ncolors) {
    char t[64];   /* three clamped ints: 43 bytes at most; gcc's bound is the int's (-Wformat-truncation) */
    rmbl_progress_fg(t, (int) sizeof t, r, g, b, ncolors);
    put(o, t);
}

/* The bar for a fraction `frac` (0..1) at time `t` seconds, `width` cells.
 * Writes a NUL-terminated string to `out` (`cap` bytes; 8192 holds any
 * width up to 200 in colour) and returns its length. */
int rmbl_progress_bar(double frac, double t, int width, int color, int unicode, int active,
                      int r, int g, int b, char *out, int cap) {
    rmbl_buf o = {out, 0, (size_t) (cap > 0 ? cap : 0)};
    if (cap <= 0) return 0;
    out[0] = '\0';
    if (!(frac >= 0)) frac = 0;            /* NaN too */
    if (frac > 1) frac = 1;
    if (!R_FINITE(t)) t = 0;
    if (width < 1) width = 1;
    if (width > RMBL_BAR_MAX_WIDTH) width = RMBL_BAR_MAX_WIDTH;
    /* 8 or 16 colours: one accent and a dim track, no shimmer or pulse (a basic colour has no shades) */
    const int basic = color > 1 && color < 256;
    if (color > 1 && color < 8) color = 0;
    const double full = frac * width;
    const int n = (int) floor(full);
    /* the shimmer: a soft highlight four cells wide sweeping left to right */
    const double pos = fmod(t * 12.0, width + 8.0) - 4.0;
    static const char *eighth[] = {"\xe2\x96\x8f", "\xe2\x96\x8e", "\xe2\x96\x8d", "\xe2\x96\x8c",
                                   "\xe2\x96\x8b", "\xe2\x96\x8a", "\xe2\x96\x89"};
    for (int i = 0; i < width; ++i) {
        if (i < n) {
            if (color) {
                double glow = 1.0 - fabs(i - pos) / 4.0;
                if (glow < 0) glow = 0;
                if (!basic) {
                    put_rgb(&o, clamp255(r + (255 - r) * 0.6 * glow), clamp255(g + (255 - g) * 0.6 * glow),
                            clamp255(b + (255 - b) * 0.6 * glow), color);
                } else if (i == 0) {
                    put_rgb(&o, r, g, b, color);
                }
            }
            put(&o, unicode ? "\xe2\x96\x88" : "#");      /* full block */
        } else if (i == n && frac < 1) {
            const double part = full - n;
            if (color) {
                const double pulse = active ? 0.55 + 0.45 * sin(t * 6.0) : 0.6;
                if (basic) put_rgb(&o, r, g, b, color);
                else put_rgb(&o, clamp255(r * pulse), clamp255(g * pulse), clamp255(b * pulse), color);
            }
            if (unicode) {
                int k = (int) (part * 8.0);
                if (k < 0) k = 0;
                if (k > 6) k = 6;
                put(&o, eighth[k]);
            } else {
                /* a half-filled head shows; an empty one blinks while work goes on, else it is track */
                put(&o, part >= 0.5 ? ">" : (active && fmod(t * 2.0, 1.0) < 0.5 ? ">" : "."));
            }
        } else {
            if (color && i == (frac < 1 ? n + 1 : n)) {
                if (basic) put(&o, "\033[0m\033[2m");
                else put_rgb(&o, 70, 70, 80, color);
            }
            put(&o, unicode ? "\xe2\x94\x80" : ".");      /* the track */
        }
    }
    if (color) put(&o, "\033[0m");
    return (int) o.n;
}

/* The spinner frame for time `t`: braille dots, or | / - \ in ASCII. */
const char *rmbl_progress_spinner(double t, int unicode) {
    static const char *braille[] = {"\xe2\xa0\x8b", "\xe2\xa0\x99", "\xe2\xa0\xb9", "\xe2\xa0\xb8",
                                    "\xe2\xa0\xbc", "\xe2\xa0\xb4", "\xe2\xa0\xa6", "\xe2\xa0\xa7",
                                    "\xe2\xa0\x87", "\xe2\xa0\x8f"};
    static const char *ascii[] = {"|", "/", "-", "\\"};
    if (!R_FINITE(t) || t < 0) t = 0;
    /* the frame index in double: a cast of t * 10 to an integer overflows for t past ~9e17 (a caller
     * passing nanoseconds) and indexed outside the table; fmod of a finite non-negative value is in [0, n) */
    double f = floor(t * 10.0);
    if (!R_FINITE(f)) f = 0;
    const int k10 = (int) fmod(f, 10.0), k4 = (int) fmod(f, 4.0);
    return unicode ? braille[k10 < 0 || k10 > 9 ? 0 : k10] : ascii[k4 < 0 || k4 > 3 ? 0 : k4];
}

static double num1(SEXP x, const char *what) {
    if ((TYPEOF(x) != REALSXP && TYPEOF(x) != INTSXP) || XLENGTH(x) != 1) {
        Rf_error("`%s` must be a single number", what);
    }
    return Rf_asReal(x);
}

static int flag1(SEXP x, const char *what) {
    if (TYPEOF(x) != LGLSXP || XLENGTH(x) != 1 || LOGICAL(x)[0] == NA_LOGICAL) {
        Rf_error("`%s` must be TRUE or FALSE", what);
    }
    return LOGICAL(x)[0];
}

/* `color`: TRUE or FALSE, or the number of colours the console shows (see the top of the file) */
static int colors1(SEXP x) {
    if (TYPEOF(x) == LGLSXP && XLENGTH(x) == 1 && LOGICAL(x)[0] != NA_LOGICAL) return LOGICAL(x)[0];
    if ((TYPEOF(x) == INTSXP || TYPEOF(x) == REALSXP) && XLENGTH(x) == 1) {
        const double v = Rf_asReal(x);
        if (R_FINITE(v) && v >= 0) return v >= 16777216 ? 16777216 : (int) v;
    }
    Rf_error("`color` must be TRUE or FALSE, or a number of colours");
    return 0;
}

SEXP C_rmbl_progress_frame(SEXP frac, SEXP t, SEXP width, SEXP color, SEXP unicode, SEXP active, SEXP rgb) {
    const double f = num1(frac, "frac"), tt = num1(t, "t"), w = num1(width, "width");
    if ((TYPEOF(rgb) != REALSXP && TYPEOF(rgb) != INTSXP) || XLENGTH(rgb) != 3) {
        Rf_error("`rgb` must be three numbers 0-255");
    }
    int c[3];
    for (int i = 0; i < 3; ++i) {
        const double v = TYPEOF(rgb) == INTSXP
            ? (INTEGER(rgb)[i] == NA_INTEGER ? NA_REAL : (double) INTEGER(rgb)[i]) : REAL(rgb)[i];
        if (!R_FINITE(v) || v < 0 || v > 255) Rf_error("`rgb` must be three numbers 0-255");
        c[i] = (int) v;
    }
    if (!R_FINITE(w) || w < 1) Rf_error("`width` must be at least 1");
    /* clamped in double before the cast: (int) of a width past INT_MAX is undefined */
    const int wi = w > RMBL_BAR_MAX_WIDTH ? RMBL_BAR_MAX_WIDTH : (int) w;
    char buf[8192];
    rmbl_progress_bar(f, tt, wi, colors1(color), flag1(unicode, "unicode"),
                      flag1(active, "active"), c[0], c[1], c[2], buf, (int) sizeof buf);
    return Rf_ScalarString(Rf_mkCharCE(buf, CE_UTF8));
}

SEXP C_rmbl_progress_spinner(SEXP t, SEXP unicode) {
    return Rf_ScalarString(Rf_mkCharCE(rmbl_progress_spinner(num1(t, "t"), flag1(unicode, "unicode")), CE_UTF8));
}

int rmbl_interrupt_pending(void);             /* rmbl_barrier.cpp: take a pending Ctrl-C */
void rmbl_interrupt_raise_unbarriered(void);   /* rmbl_barrier.cpp: raise R's interrupt condition */

/* A Ctrl-C already pending is raised now, as R's interrupt (.bl_readline, before the terminal read:
 * left pending it was lost once the read began; network stress test of 5e1dce5). Plain C, registered
 * directly: no barrier is active, so the raise happens here, over no live object. */
SEXP C_rmbl_check_interrupt(void) {
    if (rmbl_interrupt_pending()) rmbl_interrupt_raise_unbarriered();
    return R_NilValue;
}
