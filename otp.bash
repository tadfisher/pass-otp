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

  local pattern='^otpauth:\/\/(totp|hotp)(\/(([^:?]+)?(:([^:?]*))?))?(\?([^#&?]+))(&([^#&?]+))*$'
  [[ "$uri" =~ $pattern ]] || die "Cannot parse OTP key URI: $uri"

  otp_uri=${BASH_REMATCH[0]}
  otp_type=${BASH_REMATCH[1]}
  otp_label=${BASH_REMATCH[3]}

  otp_accountname=${BASH_REMATCH[6]}
  [[ -z $otp_accountname ]] && otp_accountname=${BASH_REMATCH[4]} || otp_issuer=${BASH_REMATCH[4]}

  local parameters=(${BASH_REMATCH[@]:7})
  pattern='^([^?&=]+)(=(.+))$'
  for param in "${parameters[@]}"; do
    if [[ "$param" =~ $pattern ]]; then
      case ${BASH_REMATCH[1]} in
        secret) otp_secret=${BASH_REMATCH[3]} ;;
        digits) otp_digits=${BASH_REMATCH[3]} ;;
        algorithm) otp_algorithm=${BASH_REMATCH[3]} ;;
        period) otp_period=${BASH_REMATCH[3]} ;;
        counter) otp_counter=${BASH_REMATCH[3]} ;;
        issuer) otp_issuer=${BASH_REMATCH[3]} ;;
        *) ;;
      esac
    fi
  done

  [[ -z "$otp_secret" ]] && die "Invalid key URI (missing secret): $otp_uri"
  [[ "$otp_type" == 'hotp' && -z "$otp_counter" ]] && die "Invalid key URI (missing counter): $otp_uri"
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
  [[ -n "$algorithm" ]] && uri+="&algorithm=$algorithm"

  case "$1" in
    totp)
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

otp_increment_counter() {
  local ret=$1
  local counter=$2 contents="$3" path="$4" passfile="$5"

  local inc=$((counter+1))

  contents=${contents//otp_counter: $counter/otp_counter: $inc}

  set_gpg_recipients "$(dirname "$path")"

  $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$contents" || die "OTP secret encryption aborted."

  git_add_file "$passfile" "Update HOTP counter value for $path."

  eval "$ret='$inc'"
}

otp_insert() {
  local path="${1%/}"
  local passfile="$PREFIX/$path.gpg"
  local force=$2
  local contents="$3"

  check_sneaky_paths "$path"
  set_git "$passfile"

  [[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

  mkdir -p -v "$PREFIX/$(dirname "$path")"
  set_gpg_recipients "$(dirname "$path")"

  $GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$contents" || die "OTP secret encryption aborted."

  git_add_file "$passfile" "Add given OTP secret for $path to store."
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
    die "Usage: $PROGRAM $COMMAND insert totp [--secret=key,s key] [--algorithm=algorithm,-a algorithm] [--period=seconds,-p seconds] [--digits=digits,-d digits] [--force,-f] pass-name"

  [[ $type == "hotp" && ($err -ne 0 || $# -ne 2) ]] &&
    die "Usage: $PROGRAM $COMMAND insert hotp [--secret=key,s key] [--digits=digits,-d digits] [--force,-f] pass-name counter"

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

cmd_otp_show() {
  local opts contents clip=0 secret="" type="" algorithm="" counter="" period=30 digits=6
  opts="$($GETOPT -o c -l clip -n "$PROGRAM" -- "$@")"
  local err=$?
  eval set -- "$opts"
  while true; do case $1 in
    -c|--clip) clip=1; shift ;;
    --) shift; break ;;
  esac done

  [[ $err -ne 0 || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND show [--clip,-c] pass-name"

  local path="$1"
  local passfile="$PREFIX/$path.gpg"
  check_sneaky_paths "$path"
  [[ ! -f $passfile ]] && die "Passfile not found"

  contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
  while read -r -a line; do case ${line[0]} in
    otp_secret:) secret=${line[1]} ;;
    otp_type:) type=${line[1]} ;;
    otp_algorithm:) algorithm=${line[1]} ;;
    otp_period:) period=${line[1]} ;;
    otp_counter:) counter=${line[1]} ;;
    otp_digits:) digits=${line[1]} ;;
    *) true ;;
  esac done <<< "$contents"

  [[ -z $secret ]] && die "Missing otp_secret: line in $passfile"
  [[ -z $type ]] && die "Missing otp_type: line in $passfile"
  [[ $type = "totp" && -z $algorithm ]] && die "Missing otp_algorithm: line in $passfile"
  [[ $type = "hotp" && -z $counter ]] && die "Missing otp_counter: line in $passfile"

  local out
  case $type in
    totp) out=$($OATH -b --totp="$algorithm" --time-step-size="$period"s --digits="$digits" "$secret") ;;
    hotp) otp_increment_counter counter "$counter" "$contents" "$path" "$passfile" > /dev/null \
        || die "Failed to increment HOTP counter for $passfile"
      out=$($OATH -b --hotp --counter="$counter" --digits="$digits" "$secret")
      ;;
    *) die "Invalid OTP type '$type'. May be one of 'totp' or 'hotp'" ;;
  esac

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

  local secret="" type="" algorithm="" counter="" period=30 digits=6

  contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
  while read -r -a line; do case ${line[0]} in
    otp_secret:) secret=${line[1]} ;;
    otp_type:) type=${line[1]} ;;
    otp_algorithm:) algorithm=${line[1]} ;;
    otp_period:) period=${line[1]} ;;
    otp_counter:) counter=${line[1]} ;;
    otp_digits:) digits=${line[1]} ;;
    *) true ;;
  esac done <<< "$contents"

  local uri
  case $type in
    totp) uri="otpauth://totp/$path?secret=$secret&algorithm=$algorithm&digits=$digits&period=$period" ;;
    hotp) uri="otpauth://hotp/$path?secret=$secret&digits=$digits&counter=$counter" ;;
    *) die "Invalid OTP type '$type'. Must be one of 'totp' or 'hotp'" ;;
  esac

  if [[ clip -eq 1 ]]; then
    clip "$uri" "OTP key URI for $path"
  elif [[ qrcode -eq 1 ]]; then
    qrcode "$uri" "OTP key URI for $path"
  else
    echo "$uri"
  fi
}

cmd_otp_validate() {
    otp_parse_uri "$1"
}

case "$1" in
  help|--help|-h) shift; cmd_otp_usage "$@" ;;
  show)           shift; cmd_otp_show "$@" ;;
  insert|add)     shift; cmd_otp_insert "$@" ;;
  uri)            shift; cmd_otp_uri "$@" ;;
  validate)       shift; cmd_otp_validate "$@" ;;
  *)                     cmd_otp_show "$@" ;;
esac
exit 0
