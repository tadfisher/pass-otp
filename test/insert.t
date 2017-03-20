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
  uri="otpauth://totp/passfile?secret=AAAAAAAAAAAAAAAAAAAAA"

  test_pass_init &&
  "$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA passfile &&
  [[ $("$PASS" show passfile) == "$uri" ]]
'

test_expect_success 'Inserts a TOTP key with issuer in path' '
  uri="otpauth://totp/example.com:passfile?secret=AAAAAAAAAAAAAAAAAAAAA&issuer=example.com"

  test_pass_init &&
  "$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA example.com/passfile &&
  [[ $("$PASS" show example.com/passfile) == "$uri" ]]
'

test_expect_success 'Inserts a TOTP key with issuer in nested path' '
  uri="otpauth://totp/foo:passfile?secret=AAAAAAAAAAAAAAAAAAAAA&issuer=foo"

  test_pass_init &&
  "$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA example.com/foo/passfile &&
  [[ $("$PASS" show example.com/foo/passfile) == "$uri" ]]
'

test_expect_success 'Inserts a TOTP key with spaces in path' '
  uri="otpauth://totp/example%20dot%20com:pass%20file?secret=AAAAAAAAAAAAAAAAAAAAA&issuer=example%20dot%20com"
  test_pass_init &&
  "$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA "example dot com/pass file" &&
  [[ $("$PASS" show "example dot com/pass file") == "$uri" ]]
'

test_expect_success 'Commits insert to git' '
  test_pass_init &&
  pass git init &&
  "$PASS" otp insert totp -s AAAAAAAAAAAAAAAAAAAAA passfile &&
  git log --no-decorate -1 | grep "Add OTP secret for passfile to store."
'

test_done
