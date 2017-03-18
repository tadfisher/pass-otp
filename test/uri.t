#!/usr/bin/env bash

export test_description='Tests pass otp URI parsing'

. ./setup.sh

test_expect_success 'Parses a basic TOTP URI' '
  "$PASS" otp validate  "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
'

test_expect_success 'Parses a complex TOTP URI' '
  "$PASS" otp validate otpauth://totp/ACME%20Co:john.doe@email.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME%20Co&algorithm=SHA1&digits=6&period=30
'

test_expect_success 'Fails for bogus URL' '
  test_must_fail "$PASS" otp validate https://www.google.com/
'

test_expect_success 'Fails for missing secret' '
  test_must_fail "$PASS" otp validate otpauth://totp/ACME%20Co:john.doe@email.com?issuer=ACME%20Co&algorithm=SHA1&digits=6&period=30
'

test_expect_success 'Fails for missing counter' '
  test_must_fail "$PASS" otp validate otpauth://hotp?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ
'

test_done
