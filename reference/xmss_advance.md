# Advance an XMSS key past a signature it made

An XMSS signature consumes one leaf, so the key that made it must not
sign at that index again. This returns the key with `next_index` set to
one past the signature's index (refusing a signature that was not made
by this key), which is the key to save and to use for the next
signature. The signature object itself carries no key material.

## Usage

``` r
xmss_advance(key, signature, message = NULL)

xmss_register_key(key_to_register)

xmss_forget_used_indices(key_to_forget = NULL)
```

## Arguments

- key:

  The `bricklayer_signing_key` that made `signature`.

- signature:

  The XMSS signature it made, from
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md),
  or the attestation, bundle or recode manifest that carries it.

- message:

  The message the signature was made over; when given, the signature is
  verified against the key first, so an edited or foreign signature
  cannot advance it. Without it, the signature's index is accepted only
  up to the highest index the record shows this key has used here, so an
  edited index cannot burn the key's remaining leaves; a signature made
  on another machine needs `message`.

- key_to_register:

  For `xmss_register_key()`: a signing key generated on another machine,
  regenerated from given seeds, or whose record was deleted, that has
  never signed; it is added to the record so that it may sign from
  `next_index`. A key the record shows has signed is refused.

- key_to_forget:

  For `xmss_forget_used_indices()`: a signing key (the record is keyed
  by its secret seed) whose entry alone is reset to "nothing used" (it
  may sign from index 0 again); `NULL` removes the whole record (every
  key, and the record of the releases before 0.5.12), after which only
  keys generated afterwards, or vouched for by `xmss_register_key()`,
  may sign.

## Value

The key with `next_index` advanced past the signature's index and past
every index the record knows this key has used.

## Details

The package records the highest index each key has signed with and
refuses that index again, within the session and across sessions on this
machine. The record is the file `xmss_used_indices.txt` under
`tools::R_user_dir("rmoriebricklayer", "config")`, which is where CRAN
policy lets a package keep its own configuration. A key is entered under
a fingerprint of its secret seed (`sk_seed`), not under the `root` it
carries, so editing a stale copy's `root` does not make it a new key,
and a signature whose `root` does not match the seeds is withheld.
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
registers a key it generates from fresh randomness. A key built from
given seeds is not registered, because it may be one that has signed
elsewhere: it signs from index 0 only after `xmss_register_key()`
vouches for it, and the same holds for any key the record does not know
(from another machine, or whose record was deleted). Every reservation
runs under an operating-system file lock (`flock` on Unix, `LockFileEx`
on Windows) on `xmss_used_indices.txt.flock`, which the system releases
when the process ends, so a crashed session leaves no lock for another
process to take over. A record that cannot be read, or that cannot be
written in full (a full disk), stops the signature. The record of the
releases before 0.5.12 (`xmss_index.json` in the same directory) is read
and merged, and kept as `xmss_index.json.migrated` once the new record
has been written. Another path can be set with the option
`rmoriebricklayer.xmss_index_file` or the environment variable
`RMBL_XMSS_INDEX_FILE`: an absolute path to a regular file, or to one
that does not exist yet (a device such as `/dev/null`, a directory or a
relative path is refused). The option `FALSE` (or, except on Windows,
where an empty environment variable is an unset one, the value `""`)
turns the file off: then only the session remembers, every signature
warns, and a stale copy of the key reloaded elsewhere signs a used index
again. The record does not travel with the key and is lost if the file
is deleted, so a key copied to another machine is protected only by the
`next_index` you saved: save the advanced key after every signature. In
CI or a container with a fresh home directory, a key that was not
generated in that run is unknown to the record: register it once with
`xmss_register_key()`, or point the record at a file that persists.
Examples and vignettes point the record at a temporary file so that
checks and builds leave the configuration directory alone. The record
keeps one line per key for good (an exhausted key's line is what stops a
stale copy of it), and is read and rewritten whole at every signature: a
whole signature took 0.5 s with a hundred thousand keys in the record
(measured on an x86-64 laptop; a slower machine takes longer), and
longer when several processes sign at once (each waits its turn for the
lock, up to 10 s).

`xmss_forget_used_indices()` resets one key's entry, or removes the
whole record, and with it the protection against re-signing: use it for
test keys only.

## See also

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md),
`xmss_forget_used_indices()`

## Examples

``` r
op <- options(rmoriebricklayer.xmss_index_file = tempfile())  # keep this example's
# one-time index record out of your configuration directory; leave the default in use
key <- pqc_keygen(height = 2)
s1 <- capsule_sign("manifest-1", key)
key <- xmss_advance(key, s1)
key$next_index
#> [1] 1
s2 <- capsule_sign("manifest-2", key)
capsule_verify("manifest-2", s2, signing_public_key(key))
#> [1] TRUE
options(op)
```
