#!/usr/bin/env bash

export test_description="Tests pass otp insert commands"

. ./setup.sh

test_expect_success 'Inserts a key URI' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert "$uri" passfile &&
  [[ $("$PASS" show passfile) == "$uri" ]]
'

test_expect_success 'Prompts before overwriting key URI' '
  uri1="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"
  uri2="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Bar"

  test_pass_init &&
  "$PASS" otp insert "$uri1" passfile &&
  test_faketty "$PASS" otp insert "$uri2" passfile < <(echo n) &&
  [[ $("$PASS" show passfile) == "$uri1" ]]
'

test_expect_success 'Force overwrites key URI' '
  uri1="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"
  uri2="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Bar"

  test_pass_init &&
  "$PASS" otp insert "$uri1" passfile &&
  "$PASS" otp insert -f "$uri2" passfile &&
  [[ $("$PASS" show passfile) == "$uri2" ]]
'

test_expect_success 'Inserts a basic TOTP key' '
  test_pass_init &&
  "$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA passfile
'

test_expect_success 'Commits insert to git' '
  test_pass_init &&
  pass git init &&
  "$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA passfile &&
  git log --no-decorate -1 | grep "Add given OTP secret for passfile to store."
'

test_done
