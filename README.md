[![Build Status](https://travis-ci.org/tadfisher/pass-otp.svg?branch=master)](https://travis-ci.org/tadfisher/pass-otp)

# pass-otp

A [pass](https://www.passwordstore.org/) extension for managing
one-time-password (OTP) tokens.

## Usage

```
Usage:
    pass otp [show] [--clip,-c] pass-name
        Generate an OTP code and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in 45 seconds.
    pass otp insert totp [--secret=key,-s key] [--algorithm alg,-a alg]
                             [--period=seconds,-p seconds]
                             [--digits=digits,-d digits] [--force,-f] pass-name
        Insert new TOTP secret. Prompt before overwriting existing password
        unless forced.
    pass otp insert hotp [--secret=secret,-s secret]
                             [--digits=digits,-d digits] [--force,-f]
                             pass-name counter
        Insert new HOTP secret with initial counter. Prompt before overwriting
        existing password unless forced.
    pass otp uri [--clip,-c] [--qrcode,-q] pass-name
        Create a secret key URI suitable for importing into other TOTP clients.
        Optionally, put it on the clipboard, or display a QR code.

More information may be found in the pass-otp(1) man page.
```

## Example

Insert a TOTP token:

```
$ pass otp insert totp -s AAAAAAAAAAAAAAAAAAAAA totp-secret
[master 4f9b989] Add given OTP secret for totp-secret to store.
 1 file changed, 0 insertions(+), 0 deletions(-)
 create mode 100644 totp-secret.gpg


$ pass show totp-secret
otp_secret: AAAAAAAAAAAAAAAAAAAAA
otp_type: totp
otp_algorithm: sha1
otp_period: 30
otp_digits: 6
```

Generate a 2FA code using this token:

```
$ pass otp show totp-secret
698816
```

## Installation

````
git clone https://github.com/tadfisher/pass-otp
cd pass-otp
sudo make install
```

## Requirements

- `pass` 1.7.0 or later for extenstion support
- `oathtool` for generating 2FA codes
- `qrencode` for generating QR code images

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
