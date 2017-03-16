#!/usr/bin/env bash

export test_description="Tests pass otp insert commands"

. ./setup.sh

test_expect_success 'Inserts a basic TOTP key' '
	"$PASS" init $KEY1 &&
	"$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA totp-secret
'

test_expect_success 'Commits insert to git' '
	git init "$PASSWORD_STORE_DIR" &&
	"$PASS" init $KEY1 &&
	"$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA totp-secret2 &&
	git log --no-decorate -1 | grep "Add given OTP secret for totp-secret2 to store."
'

test_done
