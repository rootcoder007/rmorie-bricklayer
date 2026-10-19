#ifndef RMBL_ASCII_H
#define RMBL_ASCII_H

/* ASCII-only case folding for text that may hold UTF-8. std::tolower() consults the
 * C locale's single-byte table, and on macOS in a UTF-8 locale the bytes of a
 * multibyte character are folded as if they were Latin-1 (0xC3 becomes 0xE3), so
 * "ao\xc3\xbbt" no longer matched its month and siudate() returned "" for every
 * accented French date (r-universe macOS checks of 1.0.0). Letters outside ASCII are
 * left as they are: the tables this folding feeds hold both spellings. */
static inline unsigned char rmbl_ascii_lower(unsigned char c) {
    return (c >= 'A' && c <= 'Z') ? static_cast<unsigned char>(c + 32) : c;
}

#endif
