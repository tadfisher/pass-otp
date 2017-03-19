#!/usr/bin/env bash

export test_description='Tests pass otp URI parsing'

. ./setup.sh

test_expect_success 'Shows key URI in single-line passfile' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert "$uri" passfile &&
  [[ $("$PASS" otp uri passfile) == "$uri" ]]
'

test_expect_success 'Shows key URI in multi-line passfile' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" insert -m passfile < <(echo -e "password\nfoo\n$uri\nbar") &&
  [[ $("$PASS" otp uri passfile) == "$uri" ]]
'

test_done
