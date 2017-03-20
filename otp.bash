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
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
# []

OATH=$(which oathtool)

# Parse a Key URI per: https://github.com/google/google-authenticator/wiki/Key-Uri-Format
# Vars are consumed by caller
# shellcheck disable=SC2034
otp_parse_uri() {
  local uri="$1"

  uri="${uri//\`/%60}"
  uri="${uri//\"/%22}"

  local pattern='^otpauth:\/\/(totp|hotp)(\/(([^:?]+)?(:([^:?]*))?))?\?(.+)$'
  [[ "$uri" =~ $pattern ]] || die "Cannot parse OTP key URI: $uri"

  otp_uri=${BASH_REMATCH[0]}
  otp_type=${BASH_REMATCH[1]}
  otp_label=${BASH_REMATCH[3]}

  otp_accountname=${BASH_REMATCH[6]}
  [[ -z $otp_accountname ]] && otp_accountname=${BASH_REMATCH[4]} || otp_issuer=${BASH_REMATCH[4]}
  [[ -z $otp_accountname ]] && die "Invalid key URI (missing accountname): $otp_uri"

  local p=${BASH_REMATCH[7]}
  local IFS=\&; local params=(${p[@]}); unset IFS

  pattern='^(.+)=(.+)$'
  for param in "${params[@]}"; do
    if [[ "$param" =~ $pattern ]]; then
      case ${BASH_REMATCH[1]} in
        secret) otp_secret=${BASH_REMATCH[2]} ;;
        digits) otp_digits=${BASH_REMATCH[2]} ;;
        algorithm) otp_algorithm=${BASH_REMATCH[2]} ;;
        period) otp_period=${BASH_REMATCH[2]} ;;
        counter) otp_counter=${BASH_REMATCH[2]} ;;
        issuer) otp_issuer=${BASH_REMATCH[2]} ;;
        *) ;;
      esac
    fi
  done

  [[ -z "$otp_secret" ]] && die "Invalid key URI (missing secret): $otp_uri"

  pattern='^[0-9]+$'
  [[ "$otp_type" == 'hotp' ]] && [[ ! "$otp_counter" =~ $pattern ]] && die "Invalid key URI (missing counter): $otp_uri"
}

otp_insert() {
  local path="${1%/}"
  local passfile="$PREFIX/$path.gpg"
  local force=$2
  local contents="$3"
  local message="$4"

  check_sneaky_paths "$path"
  set_git "$passfile"

  [[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

  mkdir -p -v "$PREFIX/$(dirname "$path")"
  set_gpg_recipients "$(dirname "$path")"

  $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$contents" || die "OTP secret encryption aborted."

  git_add_file "$passfile" "$message"
}

cmd_otp_usage() {
  cat <<-_EOF
Usage:
    $PROGRAM otp [show] [--clip,-c] pass-name
        Generate an OTP code and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in $CLIP_TIME seconds.
    $PROGRAM otp insert [--force,-f] [--echo,-e] [uri] pass-name
        Insert a new OTP key URI. If one is not supplied, it will be read from
        stdin. Optionally, echo the input. Prompt before overwriting existing
        password unless forced.
    $PROGRAM otp uri [--clip,-c] [--qrcode,-q] pass-name
        Display the key URI stored in pass-name. Optionally, put it on the
        clipboard, or display a QR code.
    $PROGRAM otp validate uri
        Test if the given URI is a valid OTP key URI.

More information may be found in the pass-otp(1) man page.
_EOF
  exit 0
}

cmd_otp_insert() {
  local opts force=0 echo=0
  opts="$($GETOPT -o fe -l force,echo -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -f|--force) force=1; shift ;;
    -e|--echo) echo=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || ($# -ne 1 && $# -ne 2) ]] && die "Usage: $PROGRAM $COMMAND insert [--force,-f] [uri] pass-name"

  local path uri
  if [[ $# -eq 1 ]]; then
    path="$1"
    if [[ -t 0 ]]; then
      if [[ $echo -eq 0 ]]; then
        while true; do
          read -r -p "Enter otpauth:// URI for $path: " -s uri || exit 1
          echo
          read -r -p "Retype otpauth:// URI for $path: " -s uri_again || exit 1
          echo
          [[ "$uri" == "$uri_again" ]] && break
          die "Error: the entered URIs do not match."
        done
      else
        read -r -p "Enter otpauth:// URI for $path: " -e uri
      fi
    else
      read -r uri
    fi
  else
    uri="$1"
    path="$2"
  fi

  otp_parse_uri "$uri"

  otp_insert "$path" $force "$otp_uri" "Add OTP secret for $2 to store."
}

cmd_otp_code() {
  [[ -z "$OATH" ]] && die "Failed to generate OTP code: oathtool is not installed."

  local opts clip=0
  opts="$($GETOPT -o c -l clip -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -c|--clip) clip=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--clip,-c] pass-name"

  local path="$1"
  local passfile="$PREFIX/$path.gpg"
  check_sneaky_paths "$path"
  [[ ! -f $passfile ]] && die "Passfile not found"

  contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
  while read -r -a line; do
    if [[ "$line" == otpauth://* ]]; then
      otp_parse_uri "$line"
      break
    fi
  done <<< "$contents"

  local cmd
  case "$otp_type" in
    totp)
      cmd="$OATH -b --totp"
      [[ -n "$otp_algorithm" ]] && cmd+="=$otp_algorithm"
      [[ -n "$otp_period" ]] && cmd+=" --time-step-size=$otp_period"s
      [[ -n "$otp_digits" ]] && cmd+=" --digits=$otp_digits"
      cmd+=" $otp_secret"
      ;;

    hotp)
      local counter=$((otp_counter+1))
      cmd="$OATH -b --hotp --counter=$counter"
      [[ -n "$otp_digits" ]] && cmd+=" --digits=$otp_digits"
      cmd+=" $otp_secret"
      ;;
  esac

  local out; out=$($cmd) || die "Failed to generate OTP code for $path"

  if [[ "$otp_type" == "hotp" ]]; then
    # Increment HOTP counter in-place
    local uri=${otp_uri/&counter=$otp_counter/&counter=$counter}
    otp_insert "$path" 1 "$uri" "Increment HOTP counter for $path."
  fi

  if [[ $clip -ne 0 ]]; then
    clip "$out" "OTP code for $path"
  else
    echo "$out"
  fi
}

cmd_otp_uri() {
  local contents qrcode=0 clip=0
  opts="$($GETOPT -o q -l qrcode -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -q|--qrcode) qrcode=1; shift ;;
    -c|--clip) clip=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND uri [--clip,-c | --qrcode,-q] pass-name"

  local path="$1"
  local passfile="$PREFIX/$path.gpg"
  check_sneaky_paths "$path"
  [[ ! -f $passfile ]] && die "Passfile not found"

  contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
  while read -r -a line; do
    if [[ "$line" == otpauth://* ]]; then
      otp_parse_uri "$line"
      break
    fi
  done <<< "$contents"

  if [[ clip -eq 1 ]]; then
    clip "$otp_uri" "OTP key URI for $path"
  elif [[ qrcode -eq 1 ]]; then
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
  insert|add)     shift; cmd_otp_insert "$@" ;;
  uri)            shift; cmd_otp_uri "$@" ;;
  validate)       shift; cmd_otp_validate "$@" ;;
  code|show)      shift; cmd_otp_code "$@" ;;
  *)                     cmd_otp_code "$@" ;;
esac
exit 0
