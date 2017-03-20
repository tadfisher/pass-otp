#!/usr/bin/env bash

export test_description='Tests pass otp code generation'

. ./setup.sh

test_expect_success 'Generates TOTP code' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  code=$("$PASS" otp passfile) &&
  [[ ${#code} -eq 6 ]]
'

test_expect_success 'Generates HOTP code and increments counter' '
  uri="otpauth://hotp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&counter=10&issuer=Example"
  inc="otpauth://hotp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&counter=11&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  code=$("$PASS" otp passfile) &&
  [[ ${#code} -eq 6 ]] &&
  [[ $("$PASS" otp uri passfile) == "$inc" ]]
'

test_done
