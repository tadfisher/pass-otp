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

otp_urlencode() {
  local LANG=C
  for ((i=0; i<${#1}; i++)); do
    if [[ ${1:$i:1} =~ ^[a-zA-Z0-9\.\~_-]$ ]]; then
    printf "%s" "${1:$i:1}"
    else
      printf '%%%02X' "'${1:$i:1}"
    fi
  done
}

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

otp_build_uri() {
  local type="$1" issuer="$2" accountname="$3" secret="$4" algorithm="$5" \
        digits="$6" period="$7" counter="$8"

  local uri="otpauth://$type/"

  local pattern='^[^:]+$'
  if [[ -n "$issuer" ]]; then
    [[ "$issuer" =~ $pattern ]] || die "Invalid character in issuer: ':'"
    issuer=$(otp_urlencode "$issuer")
  fi

  [[ -z "$accountname" ]] && die "Missing accountname"
  [[ "$accountname" =~ $pattern ]] || die "Invalid character in accountname: ':'"
  accountname=$(otp_urlencode "$accountname")

  if [[ -n "$issuer" ]]; then
    uri+="$issuer:$accountname"
  else
    uri+="$accountname"
  fi

  [[ -z "$secret" ]] && die "Missing secret"; uri+="?secret=$secret"

  case "$1" in
    totp)
      [[ -n "$algorithm" ]] && uri+="&algorithm=$algorithm"
      [[ -n "$digits" ]] && uri+="&digits=$digits"
      [[ -n "$period" ]] && uri+="&period=$period"
      ;;

    hotp)
      [[ -z "$counter" ]] && die "Missing counter"; uri+="&counter=$counter"
      ;;

    *) die "Invalid OTP type '$1'" ;;
  esac

  [[ -n "$issuer" ]] && uri+="&issuer=$issuer"

  echo "$uri"
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

  [[ -z "$message" ]] && message="Add OTP secret for $path to store."

  git_add_file "$passfile" "$message"
}

otp_insert_uri() {
  local opts force=0
  opts="$($GETOPT -o f -l force -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -f|--force) force=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || $# -ne 2 ]] && die "Usage: $PROGRAM $COMMAND insert [--force,-f] uri pass-name"

  local uri="$1"

  otp_parse_uri "$uri"

  otp_insert "$2" $force "$otp_uri"
}

otp_insert_spec() {
  local opts contents secret issuer accountname algorithm period digits counter force=0
  local type="$1"; shift

  opts="$($GETOPT -o s:i:n:a:p:d:f -l secret:,issuer:,accountname:,algorithm:,period:,digits:,force -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case "$1" in
    -s|--secret) secret="$2"; shift 2 ;;
    -i|--issuer) issuer="$2"; shift 2 ;;
    -n|--accountname) accountname="$2"; shift 2 ;;
    -a|--algorithm) algorithm="$2"; shift 2 ;;
    -p|--period) period="$2"; shift 2 ;;
    -d|--digits) digits="$2"; shift 2 ;;
    -f|--force) force=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $type == "totp" && ($err -ne 0 || $# -ne 1) ]] &&
    die "Usage: $PROGRAM $COMMAND insert totp [--secret=key,s key] [--issuer=issuer,-i issuer] [--accountname=name,-n name] [--algorithm=algorithm,-a algorithm] [--period=seconds,-p seconds] [--digits=digits,-d digits] [--force,-f] pass-name"

  [[ $type == "hotp" && ($err -ne 0 || $# -ne 2) ]] &&
    die "Usage: $PROGRAM $COMMAND insert hotp [--secret=key,s key] [--issuer=issuer,-i issuer] [--accountname=accountname,-n accountname] [--digits=digits,-d digits] [--force,-f] pass-name counter"

  local path="$1" counter="$2"

  [[ -n "$algorithm" ]] && case $algorithm in
    sha1|sha256|sha512) ;;
    *) die "Invalid algorithm '$algorithm'. May be one of 'sha1', 'sha256', or 'sha512'" ;;
  esac

  [[ -n "$digits" ]] && case $digits in
    6|8) ;;
    *) die "Invalid digits '$digits'. May be one of '6' or '8'" ;;
  esac

  if [[ -z $secret ]]; then
    read -r -p "Enter secret (base32-encoded): " -s secret || die "Missing secret"
  fi

  # Populate issuer and accountname from either options or path
  if [[ -z $accountname ]]; then
    accountname="$(basename "$path")"
    if [[ -z "$issuer" ]]; then
      issuer="$(basename "$(dirname "$path")")"
      [[ "$issuer" == "." ]] && unset issuer
    fi
  fi

  local uri; uri=$(otp_build_uri "$type" "$issuer" "$accountname" "$secret" "$algorithm" "$period" "$digits" "$counter")

  otp_insert "$1" $force "$uri"
}

cmd_otp_usage() {
  cat <<-_EOF
Usage:
    $PROGRAM otp [show] [--clip,-c] pass-name
        Generate an OTP code and optionally put it on the clipboard.
        If put on the clipboard, it will be cleared in $CLIP_TIME seconds.
    $PROGRAM otp insert totp [--secret=key,-s key] [--algorithm alg,-a alg]
                             [--period=seconds,-p seconds]
                             [--digits=digits,-d digits] [--force,-f] pass-name
        Insert new TOTP secret. Prompt before overwriting existing password
        unless forced.
    $PROGRAM otp insert hotp [--secret=secret,-s secret]
                             [--digits=digits,-d digits] [--force,-f]
                             pass-name counter
        Insert new HOTP secret with initial counter. Prompt before overwriting
        existing password unless forced.
    $PROGRAM otp uri [--clip,-c] [--qrcode,-q] pass-name
        Create a secret key URI suitable for importing into other TOTP clients.
        Optionally, put it on the clipboard, or display a QR code.

More information may be found in the pass-otp(1) man page.
_EOF
  exit 0
}

cmd_otp_insert() {
  case "$1" in
    totp|hotp) otp_insert_spec "$@" ;;
    *) otp_insert_uri "$@" ;;
  esac
}

cmd_otp_code() {
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
      [[ -n "$otp_period" ]] && cmd+=" --time-step-size=$period"s
      [[ -n "$otp_digits" ]] && cmd+=" --digits=$digits"
      cmd+=" $otp_secret"
      ;;

    hotp)
      local counter=$((otp_counter+1))
      cmd="$OATH -b --hotp --counter=$counter"
      [[ -n "$otp_digits" ]] && cmd+=" --digits=$digits"
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
