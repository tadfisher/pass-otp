========
pass-otp
========
 
-----------------------------------------------------------------------
A Password Store extension for managing one-time-password (OTP) tokens.
-----------------------------------------------------------------------
 
:Author: Tad Fisher <tadfisher@gmail.com>
:Date:   2018-02-17
:Copyright: GPLv3
:Version: 1.0.0
:Manual section: 1
:Manual group: Password Store Extension
 
SYNOPSIS
========

pass otp [`COMMAND`] [`OPTIONS`]... [`ARGS`]...

DESCRIPTION
===========

pass-otp extends the **pass**\ (1) utility with the otp command for adding OTP secrets, generating OTP codes, and displaying secret key URIs using the standard `otpauth://` scheme.

If no COMMAND is specified, COMMAND defaults to **code**.

COMMANDS
========

otp code [-c, --clip] `pass-name`
---------------------------------
Generate and print an OTP code from the secret key stored in `pass-name` using **oathtool**\ (1). If **-c** (**--clip**) is specified, do not print the code but instead copy it to the clipboard using **xclip**\ (1) and then restore the clipboard after 45 (or **PASSWORD_STORE_CLIP_TIME**) seconds. This command is alternatively named **show**.

otp insert [-f, --force] [-e, --echo] [ [-s, --secret] [-i, --issuer `issuer`] [-a, --account `account`] ] [`pass-name`]
------------------------------------------------------------------------------------------------------------------------
Prompt for and insert a new OTP secret into the password store at `pass-name`.

If **--secret** is specified, prompt for the `secret` value, assuming SHA1 algorithm, 30-second period, and 6 OTP digits. One or both of `issuer` and `account` must also be specified.

If **--secret** is not specified, prompt for a key URI; for the key URI specification see the documentation at

<https://github.com/google/google-authenticator/wiki/Key-Uri-Format>

The secret/URI is consumed from stdin; specify **-e** (**--echo**) to echo input when running this command interactively.

If `pass-name` is not specified, convert the `issuer:accountname` URI label to a path in the form of `issuer/accountname`.

Prompt before overwriting an existing secret, unless **-f** (**--force**) is specified. This command is alternatively named **add**.

otp append [-f, --force] [-e, --echo] [ [-s, --secret] [-i, --issuer `issuer`] [-a, --account `account`] ] [`pass-name`]
------------------------------------------------------------------------------------------------------------------------
Append an OTP secret to the password stored in `pass-name`, preserving any existing lines.

If **--secret** is specified, prompt for the `secret` value, assuming SHA1 algorithm, 30-second period, and 6 OTP digits. One or both of `issuer` and `account` must also be specified.

If **--secret** is not specified, prompt for a key URI; for the key URI specification see the documentation at

<https://github.com/google/google-authenticator/wiki/Key-Uri-Format>

The secret/URI is consumed from stdin; specify **-e** (**--echo**) to echo input when running this command interactively.

Prompt before overwriting an existing secret, unless **-f** (**--force**) is specified.

otp uri [-c, --clip | -q, --qrcode] `pass-name`
-----------------------------------------------
Print the key URI stored in `pass-name` to stdout. If **-c** (**--clip**) is specified, do not print the URI but instead copy it to the clipboard using **xclip**\ (1) and then restore the clipboard after 45 (or **PASSWORD_STORE_CLIP_TIME**) seconds. If **-q** (**--qrcode**) is specified, do not print the URI but instead display a QR code using **qrencode**\ (1) either to the terminal or graphically if supported.

otp validate `uri`
------------------
Test a URI string for validity according to the Key Uri Format. For more information about this format, see the documentation at

<https://github.com/google/google-authenticator/wiki/Key-Uri-Format>

OPTIONS
=======

help, -h, \--help
  Show usage message.

SEE ALSO
========
**pass**\ (1),
**qrencode**\ (1),
**zbarimg**\ (1)

<https://github.com/tadfisher/pass-otp>

COPYING
=======
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
