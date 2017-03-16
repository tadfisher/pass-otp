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

otp_increment_counter() {
	local ret=$1
	local counter=$2 contents="$3" path="$4" passfile="$5"

	local inc=$((counter+1))

	contents=${contents//otp_counter: $counter/otp_counter: $inc}

	set_gpg_recipients "$(dirname "$path")"

	$GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$contents" || die "OTP secret encryption aborted."

	git_add_file "$passfile" "Update HOTP counter value for $path."

	eval $ret="'$inc'"
}

otp_insert() {
	local path="${1%/}"
	local passfile="$PREFIX/$path.gpg"
	local force=$2
	local contents="$3"

	check_sneaky_paths "$path"

	[[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

	set_git "$passfile"

	mkdir -p -v "$PREFIX/$(dirname "$path")"
	set_gpg_recipients "$(dirname "$path")"

	$GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$contents" || die "OTP secret encryption aborted."

	git_add_file "$passfile" "Add given OTP secret for $path to store."
}

otp_insert_totp() {
	local opts secret="" algorithm="sha1" period=30 digits=6 force=0
	opts="$($GETOPT -o s:a:p:d:f -l secret:,algorithm:,period:,digits:,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
			       -s|--secret) secret="$2"; shift 2 ;;
			       -a|--algorithm) algorithm="$2"; shift 2 ;;
			       -p|--period) period="$2"; shift 2 ;;
			       -d|--digits) digits="$2"; shift 2 ;;
			       -f|--force) force=1; shift ;;
			       --) shift; break ;;
		       esac done

	[[ $err -ne 0 && $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND insert totp [--secret=key,s key] [--algorithm=algorithm,-a algorithm] [--period=seconds,-p seconds] [--digits=digits,-d digits] [--force,-f] pass-name"

	case $algorithm in
		sha1|sha256|sha512) ;;
		*) die "Invalid algorithm '$algorithm'. May be one of 'sha1', 'sha256', or 'sha512'" ;;
	esac

	case $digits in
		6|8) ;;
		*) die "Invalid digits '$digits'. May be one of '6' or '8'" ;;
	esac

	if [[ -z $secret ]]; then
		read -r -p "Enter secret (base32-encoded): " -s secret || exit 1
	fi

	local contents=$(cat <<-_EOF
	otp_secret: $secret
	otp_type: totp
	otp_algorithm: $algorithm
	otp_period: $period
	otp_digits: $digits
	_EOF
	)

	otp_insert "$1" $force "$contents"
}

otp_insert_hotp() {
	local opts secret="" digits=6 force=0
	opts="$($GETOPT -o s:d:f -l secret:,digits:,force -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do case $1 in
			       -s|--secret) secret="$2"; shift 2 ;;
			       -a|--algorithm) algorithm="$2"; shift 2 ;;
			       -d|--digits) digits="$2"; shift 2 ;;
			       -f|--force) force=1; shift ;;
			       --) shift; break ;;
		       esac done

	[[ $err -ne 0 || $# -ne 2 ]] && die "Usage: $PROGRAM $COMMAND insert hotp [--secret=key,s key] [--digits=digits,-d digits] [--force,-f] pass-name counter"

	case $digits in
		6|8) ;;
		*) die "Invalid digits '$digits'. May be one of '6' or '8'" ;;
	esac

	if [[ -z $secret ]]; then
		read -r -p "Enter secret (base32-encoded): " -s secret || exit 1
	fi

	local counter="$2"
	[[ $counter =~ ^[0-9]+$ ]] || die "Invalid counter '$counter'. Must be a positive number"

	local contents=$(cat <<-_EOF
	otp_secret: $secret
	otp_type: hotp
	otp_counter: $counter
	otp_digits: $digits
	_EOF
	)

	otp_insert "$1" $force "$contents"
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
		totp) shift; otp_insert_totp "$@" ;;
		hotp) shift; otp_insert_hotp "$@" ;;
		*) die "Invalid OTP type '$1'. May be one of 'totp' or 'hotp'" ;;
	esac
}

cmd_otp_show() {
	local clip=0
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

	local secret="" type="" algorithm="" counter="" period=30 digits=6

	local contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
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
		totp)	out="$($OATH -b --totp=$algorithm --time-step-size="$period"s --digits=$digits $secret)" ;;
		hotp)	otp_increment_counter counter $counter "$contents" "$path" "$passfile" > /dev/null
			[[ $? -ne 0 ]] && die "Failed to increment HOTP counter for $passfile"
			out="$($OATH -b --hotp --counter=$counter --digits=$digits $secret)"
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
	local qrcode=0 clip=0
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

	local contents=$($GPG -d "${GPG_OPTS[@]}" "$passfile")
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

case "$1" in
	help|--help|-h) shift;	cmd_otp_usage "$@" ;;
	show) shift;		cmd_otp_show "$@" ;;
	insert|add) shift;	cmd_otp_insert "$@" ;;
	uri) shift;		cmd_otp_uri "$@" ;;
	*)			cmd_otp_show "$@" ;;
esac
exit 0
