Change Log
=============

Version 1.2.0 *(2018-11-15)*
-------------------------------

* New: Bash completion is now supported. (thanks Zoltan Kertesz)
* Fix getopt parsing; passing `--issuer` and `--account` should no longer hang.
  (thanks @xPMo)


Version 1.1.1 *(2018-06-28)*
-------------------------------

This is mainly a bugfix release.

 * Numerous build and test infrstructure updates. (thanks @LucidOne)
 * `insert` and `append` now require only one of "issuer" or "account",
   matching the documentation. (thanks @sudoforge and @xPMo)
 * `append` now displays the passfile in its prompt. (thanks @sudoforge)
 * Add a separate `LICENSE` file. (thanks @dmarcoux)
 * Avoid use of herestrings when reading input. (thanks @rbuzatu90)
 * Discard base64 padding (`=` characters) in OTP secrets.

In addition, thanks to @endgame and @brainstorm for their contributions to the
documentation.

Version 1.1.0 *(2018-03-04)*
-------------------------------

 * New: `insert` and `append` commands accept secret parameters directly using
   the `--secret`, `--issuer` and `--account` arguments.
 * Fix compatibility with Bash versions prior to 4.x.
 * Return an error status for `code` when the passfile does not contain an
   `otpauth://` entry.

Version 1.0.0 *(2017-03-20)*
-------------------------------

 * New: `insert` command accepts `otpauth://` URIs directly.
 * New: `append` command appends or replaces OTP URIs in existing passfiles.
 * New: `validate` command validates an `otpauth://` URI against the
   [Key Uri Format](https://github.com/google/google-authenticator/wiki/Key-Uri-Format) standard.
 * Rename `show` to `code` for disambiguation from `pass show`. `show` is still
   supported as an alias.

 * **Drop `insert totp` and `insert hotp` commands.** These were cumbersome to
   support and are obviated by key URIs.

 * **Drop support for the 0.1.0 OTP passfile format.** Please see the
   [Migrating from pass-otp 0.1.0](https://github.com/tadfisher/pass-otp/blob/v1.0.0/README.md#migrating-from-pass-otp-01)
   section of the README for advice on migrating your OTP passfiles from the
   previous version.

 * **Drop support for entering OTP secrets as arguments.** This practice is
   prone to history leakage, which is why it is not supported by `pass insert`.
   Intrepid users may use `echo <uri> | pass otp insert`, but they should be
   warned to disable their shell's history feature.

Version 0.1.0 *(2017-02-14)*
----------------------------

 * Initial release.
 * Supports the following commands:
   - `insert totp`: Insert a TOTP secret.
   - `insert hotp`: Insert an HOTP secret.
   - `show`: Generate a QR code.
   - `uri`: Generate an otpauth:// URI for a secret.
