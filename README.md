[![Build Status](https://travis-ci.org/tadfisher/pass-otp.svg?branch=master)](https://travis-ci.org/tadfisher/pass-otp)

# pass-otp

A [pass](https://www.passwordstore.org/) extension for managing
one-time-password (OTP) tokens.

## Usage

```
Usage:

    pass otp [code] [--clip,-c] pass-name
        Generate an OTP code and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in 45 seconds.

    pass otp insert [--force,-f] [--echo,-e] [uri] pass-name
        Insert a new OTP key URI. If one is not supplied, it will be read from
        stdin. Optionally, echo the input. Prompt before overwriting existing
        password unless forced.

    pass otp uri [--clip,-c] [--qrcode,-q] pass-name
        Display the key URI stored in pass-name. Optionally, put it on the
        clipboard, or display a QR code.

    pass otp validate uri
        Test if the given URI is a valid OTP key URI.

More information may be found in the pass-otp(1) man page.
```

## Examples

Insert a TOTP token:

```
$ pass otp insert otpauth://totp/totp-secret?secret=AAAAAAAAAAAAAAAA totp-secret
```

Have `pass-otp` prompt you for a token (avoids potential shell history leakage):

```
$ pass otp insert totp-secret
```

Pipe an `otpauth://` URI into a passfile:

```
$ cat totp-uri.txt | pass otp insert totp-secret
```

Use `[zbar](http://zbar.sourceforge.net/)` to decode a QR image into a passfile:

```
$ zbarimg -q --raw qrcode.png | pass otp insert totp-secret
```

Generate a 2FA code using this token:

```
$ pass otp totp-secret
698816
```

Display a QR code for an OTP token:

```
$ pass otp uri -q totp-secret
█████████████████████████████████████
█████████████████████████████████████
████ ▄▄▄▄▄ ██▄▄ ▀█  ▀  █▀█ ▄▄▄▄▄ ████
████ █   █ █▀▄  █▀▀▄▀▀██ █ █   █ ████
████ █▄▄▄█ █▄▀ █▄▄▄ █▀▀▄ █ █▄▄▄█ ████
████▄▄▄▄▄▄▄█▄▀▄█ ▀ █▄█ ▀▄█▄▄▄▄▄▄▄████
████▄▄▀██▄▄ ▀▄ █▄█▀ ▀▄▀▀▄▀█▀ ▄▀██████
████  ▀▄▀ ▄▀ ▄▀ ▄▄ ▄ ███ ██ █ ███████
████▀▀ ▄▄█▄▄▄▄ █ █ ▀███▀▄▀  ▀▀█  ████
████▀▄▀ ▀ ▄█▀▄██ ▀▀▄██▀█▀▄▀▀  ▀█▀████
████▀ █▀ ▄▄██ █▀▄▄▄   ▄▀ ▄▀ ▀ ▄▀▀████
████ ▄ ▀█ ▄█▄ ▀ ▄██▄▀██▄ ▀▀▀█ ▄▀ ████
████▄█▄▄▄█▄▄ █▄▄ ▀█ █▄█▀ ▄▄▄ █▄█▄████
████ ▄▄▄▄▄ █ ▄▀▀▀▀▄ █▄▄  █▄█ ███▀████
████ █   █ ██▀▄ █▄█ ▀█▀   ▄▄▄█▀▄ ████
████ █▄▄▄█ █▀▄ █  █  ██▄▄▀ ▀▄█ ▄▀████
████▄▄▄▄▄▄▄█▄█▄▄███▄█▄█▄█▄█▄██▄██████
█████████████████████████████████████
█████████████████████████████████████
```

## Installation

```
git clone https://github.com/tadfisher/pass-otp
cd pass-otp
sudo make install
```

## Requirements

- `pass` 1.7.0 or later for extenstion support
- `oathtool` for generating 2FA codes
- `qrencode` for generating QR code images

## Migrating from pass-otp 0.1

`pass-otp` has switched to storing OTP tokens in the
standard
[Key Uri Format](https://github.com/google/google-authenticator/wiki/Key-Uri-Format).
You'll need to edit any saved tokens and change them to this format. For
example:

```
$ pass edit totp-secret
```

Old format:

```
otp_secret: AAAAAAAAAAAAAAAA
otp_type: totp
otp_algorithm: sha1
otp_period: 30
otp_digits: 6
```

New format:

```
otpauth://
```

## License

```
Copyright (C) 2017 Tad Fisher

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
```
