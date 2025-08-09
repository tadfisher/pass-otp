#!/usr/bin/env bash
# pass otp - Password Store Extension (https://www.passwordstore.org/)
# Copyright (C) 2017 Tad Fisher
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
# []

VERSION="1.1.2"
OATH=$(command -v oathtool)
OTPTOOL=$(command -v otptool)

if [[ $PASSAGE == 1 ]]; then
  EXT="age"
else
  EXT="gpg"
fi

## source:  https://gist.github.com/cdown/1163649
urlencode() {
  local l=${#1}
  for (( i = 0 ; i < l ; i++ )); do
    local c=${1:i:1}
    case "$c" in
      [a-zA-Z0-9.~_-]) printf "%c" "$c";;
      ' ') printf + ;;
      *) printf '%%%.2X' "'$c"
    esac
  done
}

urldecode() {
  # urldecode <string>

  local url_encoded="${1//+/ }"
  printf '%b' "${url_encoded//%/\\x}"
}

# Parse a Key URI per: https://github.com/google/google-authenticator/wiki/Key-Uri-Format
# Vars are consumed by caller
# shellcheck disable=SC2034
otp_parse_uri() {
  local uri="$1"

  uri="${uri//\`/%60}"
  uri="${uri//\"/%22}"

  local pattern='^otpauth:\/\/(totp|hotp)(\/(([^:?]+)?(:([^:?]*))?)(:([0-9]+))?)?\?(.+)$'
  [[ "$uri" =~ $pattern ]] || die "Cannot parse OTP key URI: $uri"

  otp_uri=${BASH_REMATCH[0]}
  otp_type=${BASH_REMATCH[1]}
  otp_label=${BASH_REMATCH[3]}

  otp_accountname=$(urldecode "${BASH_REMATCH[6]}")
  [[ -z $otp_accountname ]] && otp_accountname=$(urldecode "${BASH_REMATCH[4]}") || otp_issuer=$(urldecode "${BASH_REMATCH[4]}")
  [[ -z $otp_accountname ]] && die "Invalid key URI (missing accountname): $otp_uri"

  local p=${BASH_REMATCH[9]}
  local params
  local IFS=\&; read -r -a params < <(echo "$p") ; unset IFS

  pattern='^([^=]+)=(.+)$'
  for param in "${params[@]}"; do
    if [[ "$param" =~ $pattern ]]; then
      case ${BASH_REMATCH[1]} in
        secret) otp_secret=${BASH_REMATCH[2]} ;;
        digits) otp_digits=${BASH_REMATCH[2]} ;;
        algorithm) otp_algorithm=${BASH_REMATCH[2]} ;;
        period) otp_period=${BASH_REMATCH[2]} ;;
        counter) otp_counter=${BASH_REMATCH[2]} ;;
        issuer) otp_issuer=$(urldecode "${BASH_REMATCH[2]}") ;;
        *) ;;
      esac
    fi
  done

  [[ -z "$otp_secret" ]] && die "Invalid key URI (missing secret): $otp_uri"

  pattern='^[0-9]+$'
  [[ "$otp_type" == 'hotp' ]] && [[ ! "$otp_counter" =~ $pattern ]] && die "Invalid key URI (missing counter): $otp_uri"
}

otp_read_uri() {
  local uri prompt="$1" echo="$2"

  if [[ -t 0 ]]; then
    if [[ $echo -eq 0 ]]; then
      read -r -p "Enter otpauth:// URI for $prompt: " -s uri || exit 1
      echo
      read -r -p "Retype otpauth:// URI for $prompt: " -s uri_again || exit 1
      echo
      [[ "$uri" == "$uri_again" ]] || die "Error: the entered URIs do not match."
    else
      read -r -p "Enter otpauth:// URI for $prompt: " -e uri
    fi
  else
    read -r uri
  fi

  otp_parse_uri "$uri"
}

otp_read_secret() {
  local uri prompt="$1" echo="$2" issuer accountname separator
  [ ! "$3" = false ] && issuer="$(urlencode "$3")"
  [ ! "$4" = false ] && accountname="$(urlencode "$4")"
  [ -n "$issuer" ] && [ -n "$accountname" ] && separator=":"

  if [[ -t 0 ]]; then
    if [[ $echo -eq 0 ]]; then
      read -r -p "Enter secret for $prompt: " -s secret || exit 1
      echo
      read -r -p "Retype secret for $prompt: " -s secret_again || exit 1
      echo
      [[ "$secret" == "$secret_again" ]] || die "Error: the entered secrets do not match."
    else
        read -r -p "Enter secret for $prompt: " -e secret
    fi
  else
      read -r secret
  fi

  uri="otpauth://totp/${issuer}${separator}${accountname}?secret=${secret}"
  [ -n "$issuer" ] && uri="${uri}&issuer=${issuer}"
  otp_parse_uri "$uri"
}

otp_insert() {
  local path="$1" passfile="$2" contents="$3" message="$4" quiet="$5"

  check_sneaky_paths "$path"
  set_git "$passfile"

  mkdir -p -v "$PREFIX/$(dirname "$path")"
  if [[ $PASSAGE == 1 ]]; then
    set_age_recipients "$(dirname "$path")"
    echo "$contents" | $AGE -e "${AGE_RECIPIENT_ARGS[@]}" -o "$passfile" || die "OTP secret encryption aborted"
  else
    set_gpg_recipients "$(dirname "$path")"
    echo "$contents" | $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" || die "OTP secret encryption aborted."
  fi

  if [[ "$quiet" -eq 1 ]]; then
    git_add_file "$passfile" "$message" 1>/dev/null
  else
    git_add_file "$passfile" "$message"
  fi
}

cmd_otp_usage() {
  cat <<-_EOF
Usage:

    $PROGRAM otp [code] [--clip,-c] pass-name
        Generate an OTP code and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in $CLIP_TIME seconds.

    $PROGRAM otp insert [--force,-f] [--echo,-e]
            [[--secret, -s] [--issuer,-i issuer] [--account,-a account] [--path,-p path-name]]
            [pass-name]
        Prompt for and insert a new OTP key.

        If 'secret' is specified, prompt for the OTP secret, assuming SHA1
        algorithm, 30-second period, and 6 OTP digits; one of 'issuer' or
        'account' is also required. Otherwise, prompt for a key URI; if
        'pass-name' is not supplied, use the URI label.

        Optionally, echo the input. Prompt before overwriting existing URI
        unless forced. This command accepts input from stdin.

    $PROGRAM otp append [--force,-f] [--echo,-e]
            [[--secret, -s] [--issuer,-i issuer] [--account,-a account]]
            pass-name
        Appends an OTP key URI to an existing password file.

        If 'secret' is specified, prompt for the OTP secret, assuming SHA1
        algorithm, 30-second period, and 6 OTP digits; one of 'issuer' or
        'account' is also required. Otherwise, prompt for a key URI.

        Optionally, echo the input. Prompt before overwriting an existing URI
        unless forced. This command accepts input from stdin.

    $PROGRAM otp uri [--clip,-c] [--qrcode,-q] pass-name
        Display the key URI stored in pass-name. Optionally, put it on the
        clipboard, or display a QR code.

    $PROGRAM otp validate uri
        Test if the given URI is a valid OTP key URI.

More information may be found in the pass-otp(1) man page.
_EOF
  exit 0
}

cmd_otp_version() {
  echo $VERSION
  exit 0
}

cmd_otp_insert() {
  local opts force=0 echo=0 from_secret=0
  opts="$($GETOPT -o fesi:a:p: -l force,echo,secret,issuer:,account:,path: -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -f|--force) force=1; shift ;;
    -e|--echo) echo=1; shift ;;
    -s|--secret) from_secret=1; shift;;
    -i|--issuer) issuer=$2; shift; shift;;
    -a|--account) account=$2;  shift; shift;;
    -p|--path) path_prefix=$2;  shift; shift;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 ]] && die "Usage: $PROGRAM $COMMAND insert [--force,-f] [--echo,-e] [--secret, -s] [--issuer,-i issuer] [--account,-a account] [--path,-p path-name] [pass-name]"

  local prompt path uri
  if [[ $# -eq 1 ]]; then
    path="${1%/}"
    prompt="$path"
  else
    prompt="this token"
  fi

  if [[ $from_secret -eq 1 ]]; then
    [ -z "$issuer" ] && issuer=false
    [ -z "$account" ] && account=false

    [ "$issuer" = false ] && [ "$account" = false ] && die "Missing one of either '--issuer' or '--account'"

    otp_read_secret "$prompt" $echo "$issuer" "$account"
  else
    otp_read_uri "$prompt" $echo
  fi

  if [[ -z "$path" ]]; then
    [[ -n "$otp_issuer" ]] && path+="$otp_issuer/"
    path+="$otp_accountname"
    if [ -n "$path_prefix" ]; then
      path="${path_prefix%/}/$path"
    fi
    yesno "Insert into $path?"
  fi

  local passfile="$PREFIX/$path.$EXT"
  [[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

  otp_insert "$path" "$passfile" "$otp_uri" "Add OTP secret for $path to store."
}

cmd_otp_append() {
  local opts force=0 echo=0 from_secret=0
  opts="$($GETOPT -o fesi:a: -l force,echo,secret,issuer:,account: -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -f|--force) force=1; shift ;;
    -e|--echo) echo=1; shift ;;
    -s|--secret) from_secret=1; shift;;
    -i|--issuer) issuer=$2; shift; shift;;
    -a|--account) account=$2;  shift; shift;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND append [--force,-f] [--echo,-e] [--secret, -s] [--issuer,-i issuer] [--account,-a account] pass-name"

  local uri
  local path="${1%/}"
  local prompt="$path"
  local passfile="$PREFIX/$path.$EXT"

  [[ -f $passfile ]] || die "Passfile not found"
  if [[ $PASSAGE == 1 ]]; then
    old_contents=$($AGE -d -i "$IDENTITIES_FILE" "$passfile")
  else
    old_contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
  fi

  local existing contents=""
  while IFS= read -r line || [ -n "$line" ]; do
    [[ -z "$existing" && "$line" == otpauth://* ]] && existing="$line"
    [[ -n "$contents" ]] && contents+=$'\n'
    contents+="$line"
  done < <(echo "$old_contents")

  [[ -n "$existing" ]] && yesno "An OTP secret already exists for $path. Overwrite it?"

  if [[ $from_secret -eq 1 ]]; then
    [ -z "$issuer" ] && issuer=false
    [ -z "$account" ] && account=false

    [ "$issuer" = false ] && [ "$account" = false ] && die "Missing one of either '--issuer' or '--account'"

    otp_read_secret "$prompt" $echo "$issuer" "$account"
  else
    otp_read_uri "$prompt" $echo
  fi

  local replaced
  if [[ -n "$existing" ]]; then
    while IFS= read -r line; do
      [[ "$line" == otpauth://* ]] && line="$otp_uri"
      [[ -n "$replaced" ]] && replaced+=$'\n'
      replaced+="$line"
    done < <(echo "$contents")
  else
    replaced="$contents"$'\n'"$otp_uri"
  fi

  local message
  if [[ -n "$existing" ]]; then
    message="Replace OTP secret for $path."
  else
    message="Append OTP secret for $path."
  fi

  otp_insert "$path" "$passfile" "$replaced" "$message"
}

cmd_otp_code() {
  [[ -z "$OATH" && -z "$OTPTOOL" ]] && die "Failed to generate OTP code: oathtool or otptool is not installed."

  local opts clip=0 quiet=0
  opts="$($GETOPT -o cq -l clip,quiet -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -c|--clip) clip=1; shift ;;
    -q|--quiet) quiet=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--clip,-c] [--quiet,-q] pass-name"

  local path="${1%/}"
  local passfile="$PREFIX/$path.$EXT"
  check_sneaky_paths "$path"
  [[ ! -f $passfile ]] && die "$path: passfile not found."

  if [[ $PASSAGE == 1 ]]; then
    contents=$($AGE -d -i "$IDENTITIES_FILE" "$passfile")
  else
    contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
  fi
  while read -r line; do
    if [[ "$line" == otpauth://* ]]; then
      local uri="$line"
      otp_parse_uri "$line"
      break
    fi
  done < <(echo "$contents")

  # Check oathtool for stdin secrets feature
  OATH_SAFE_VERSION=2.6.5
  OATH_VERSION=$("$OATH" --version | head -n1 | tr ' ' '\n' | tail -n1)
  printf -v OATH_VERSIONS '%s\n%s' "$OATH_SAFE_VERSION" "$OATH_VERSION"
  [[ "$OATH_VERSIONS" = "$(sort -n <<< "$OATH_VERSIONS")" ]] && OATH_SAFE=1

  local cmd
  case "$otp_type" in
    totp)
      cmd=("$OATH" --base32)
      [[ -z "$otp_algorithm" ]] && cmd+=(--totp)
      [[ -n "$otp_algorithm" ]] && cmd+=(--totp="$(echo "${otp_algorithm}"|tr "[:upper:]" "[:lower:]")")
      [[ -n "$otp_period" ]] && cmd+=(--time-step-size="$otp_period"s)
      [[ -n "$otp_digits" ]] && cmd+=(--digits="$otp_digits")
      if [[ -n "$OATH_SAFE" ]] ; then
        cmd+=(-) # secrets on stdin
        unset OTPTOOL
      else
        cmd+=("$otp_secret")
      fi
      [[ -n "$OTPTOOL" ]] && cmd=("$OTPTOOL" "$uri")
      ;;

    hotp)
      local counter=$((otp_counter+1))
      cmd=("$OATH" --base32 --hotp --counter="$counter")
      [[ -n "$otp_digits" ]] && cmd+=(--digits="$otp_digits")
      if [[ -n "$OATH_SAFE" ]] ; then
        cmd+=(-) # secrets on stdin
        unset OTPTOOL
      else
        cmd+=("$otp_secret")
      fi
      [[ -n "$OTPTOOL" ]] && cmd=("$OTPTOOL" "$uri")
      ;;

    *)
      die "$path: OTP secret not found."
      ;;
  esac

  local out
  if [[ -n "$OATH" && -n "$OATH_SAFE" && -z "$OTPTOOL" ]] ; then
    out=$("${cmd[@]}" <<< "$otp_secret") || die "$path: failed to generate OTP code."
  else
    out=$("${cmd[@]}") || die "$path: failed to generate OTP code."
  fi

  if [[ "$otp_type" == "hotp" ]]; then
    # Increment HOTP counter in-place
    local line replaced uri=${otp_uri/&counter=$otp_counter/&counter=$counter}
    while IFS= read -r line; do
      [[ "$line" == otpauth://* ]] && line="$uri"
      [[ -n "$replaced" ]] && replaced+=$'\n'
      replaced+="$line"
    done < <(echo "$contents")

    otp_insert "$path" "$passfile" "$replaced" "Increment HOTP counter for $path." "$quiet"
  fi

  if [[ $clip -ne 0 ]]; then
    clip "$out" "OTP code for $path"
  else
    echo "$out"
  fi
}

cmd_otp_uri() {
  local contents qrcode=0 clip=0
  opts="$($GETOPT -o cq -l clip,qrcode -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -q|--qrcode) qrcode=1; shift ;;
    -c|--clip) clip=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND uri [--clip,-c | --qrcode,-q] pass-name"

  local path="$1"
  local passfile="$PREFIX/$path.$EXT"
  check_sneaky_paths "$path"
  [[ ! -f $passfile ]] && die "Passfile not found"
  if [[ $PASSAGE == 1 ]]; then
    contents=$($AGE -d -i "$IDENTITIES_FILE" "$passfile")
  else
    contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
  fi

  while read -r line; do
    if [[ "$line" == otpauth://* ]]; then
      otp_parse_uri "$line"
      break
    fi
  done < <(echo "$contents")

  if [[ $clip -eq 1 ]]; then
    clip "$otp_uri" "OTP key URI for $path"
  elif [[ $qrcode -eq 1 ]]; then
    qrcode "$otp_uri" "OTP key URI for $path"
  else
    echo "$otp_uri"
  fi
}

cmd_otp_validate() {
  otp_parse_uri "$1"
}

case "$1" in
  help|--help|-h) shift; cmd_otp_usage "$@" ;;
  version|--version) shift; cmd_otp_version "$@" ;;
  insert|add)     shift; cmd_otp_insert "$@" ;;
  append)         shift; cmd_otp_append "$@" ;;
  uri)            shift; cmd_otp_uri "$@" ;;
  validate)       shift; cmd_otp_validate "$@" ;;
  code|show)      shift; cmd_otp_code "$@" ;;
  *)                     cmd_otp_code "$@" ;;
esac
exit 0
