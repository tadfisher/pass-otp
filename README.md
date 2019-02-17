
| Branch | Status |
|--------|--------|
| [**master**](https://github.com/tadfisher/pass-otp/tree/master) | [![Build Status: master](https://travis-ci.org/tadfisher/pass-otp.svg?branch=master)](https://travis-ci.org/tadfisher/pass-otp) |
| [**develop**](https://github.com/tadfisher/pass-otp/tree/develop) | [![Build Status: develop](https://travis-ci.org/tadfisher/pass-otp.svg?branch=develop)](https://travis-ci.org/tadfisher/pass-otp) |

# pass-otp

A [pass](https://www.passwordstore.org/) extension for managing
one-time-password (OTP) tokens.

## Usage

```
Usage:

    pass otp [code] [--clip,-c] pass-name
        Generate an OTP code and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in 45 seconds.

    pass otp insert [--force,-f] [--echo,-e] [pass-name]
        Prompt for and insert a new OTP key URI. If pass-name is not supplied,
        use the URI label. Optionally, echo the input. Prompt before overwriting
        existing password unless forced. This command accepts input from stdin.

    pass otp append [--force,-f] [--echo,-e] pass-name
        Appends an OTP key URI to an existing password file. Optionally, echo
        the input. Prompt before overwriting an existing URI unless forced. This
        command accepts input from stdin.

    pass otp uri [--clip,-c] [--qrcode,-q] pass-name
        Display the key URI stored in pass-name. Optionally, put it on the
        clipboard, or display a QR code.

    pass otp validate uri
        Test if the given URI is a valid OTP key URI.

More information may be found in the pass-otp(1) man page.
```

## Examples

Prompt for an OTP token, hiding input:

```
$ pass otp insert totp-secret
Enter otpauth:// URI for totp-secret:
Retype otpauth:// URI for totp-secret:
```

Prompt for an OTP token, echoing input:

```
$ pass otp insert -e totp-secret
Enter otpauth:// URI for totp-secret: otpauth://totp/totp-secret?secret=AAAAAAAAAAAAAAAA&issuer=totp-secret
```

Pipe an `otpauth://` URI into a passfile:

```
$ pass otp insert totp-secret < totp-secret.txt
```

Use [zbar](http://zbar.sourceforge.net/) to decode a QR image into a passfile:

```
$ zbarimg -q --raw qrcode.png | pass otp insert totp-secret
```

The same, but appending to an existing passfile:

```
$ zbarimg -q --raw google-qrcode.png | pass otp append google/example@gmail.com
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

### From git

```
git clone https://github.com/tadfisher/pass-otp
cd pass-otp
sudo make install
```

### Arch Linux

`pass-otp` is available in the `[community]` repository:

```
pacman -S pass-otp
```

### Debian

`pass-otp` is available in `buster` and `sid` repositories with the package-name `pass-extension-otp` according to [tracker](https://tracker.debian.org/pkg/pass-otp):

```
apt install pass-extension-otp
```

### Gentoo Linux

```
emerge app-admin/pass-otp
```

### Nix/NixOS

The following expression builds `pass` with the `pass-otp` extension:

```nix
with pkgs;
pass.withExtensions (exts: [ exts.pass-otp ])
```

The above can be installed imperatively via `nix-env` or ran in a temprorary
environment via `nix-shell`.

### macOS
#### Brew
```
brew install pass-otp
```

#### Macports.org
```
sudo port install pass-otp
```

### openSUSE

```
zypper install pass-otp
```

### Crux Linux
pass-otp in this port

```
#/etc/ports/mk.httpup
# MK ports collection
#
# https://github.com/beli3ver/crux-ports/

ROOT_DIR=/usr/ports/mk
URL=https://raw.githubusercontent.com/beli3ver/crux-ports/master/
```

## Requirements

- `pass` 1.7.0 or later for extension support
- `oathtool` for generating 2FA codes
- `qrencode` for generating QR code images

### Build requirements

- `make test`
  - `pass` >= 1.7.0
  - `git`
  - `oathtool`
  - `expect`
- `make lint`
  - `shellcheck`

## Browser Support
[passff](https://github.com/passff/passff) >= 1.6.0 now supports using `pass-otp` to fill login forms.

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
otpauth://totp/totp-secret?secret=AAAAAAAAAAAAAAAA&issuer=totp-secret
```

Note that the following default values do not need to be specified in the URI:

| parameter | default |
| --------- | ------- |
| algorithm | sha1    |
| period    | 30      |
| digits    | 6       |

## Migrating from Google Authenticator

**Warning:** This method is provided as a means to transport your TOTP tokens to
other devices, disconnected from your single factor authentication part. If you
add those secrets into the same basket of eggs, you will be defeating the whole
purpose of the [multi factor
authentication](https://en.wikipedia.org/wiki/Multi-factor_authentication)
mantra. Please think it through before running this migration.

If you read the warning paragraph above, [keep calm and move on with the
migration](https://github.com/tadfisher/pass-otp/wiki/How-to-migrate-your-Google-Authenticator-database-to-pass-otp%3F).
