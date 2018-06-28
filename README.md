
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

### NixOS

- `configuration.nix`

System-wide:

```nix
{
  environment.systemPackages = [ pkgs.pass-otp ];
}
```

Per-user:

```nix
{
  users.users."name".packages = [ pkgs.pass-otp ];
}
```

- Imperative

```
nix-env -i pass-otp
```

### macOS

```
brew install oath-toolkit
git clone https://github.com/tadfisher/pass-otp
cd pass-otp
make install PREFIX=/usr/local
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
