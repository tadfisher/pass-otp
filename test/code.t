#!/usr/bin/env bash

export test_description='Tests pass otp code generation'

. ./setup.sh

test_expect_success 'Fails for missing secret' '
  test_pass_init &&
  "$PASS" insert passfile <<< "12345"
  test_expect_code 1 pass otp passfile
'

test_expect_success 'Generates TOTP code' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  code=$("$PASS" otp passfile | head -n 1) &&
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

test_expect_success 'Generates HOTP code quietly' '
  uri="otpauth://hotp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&counter=10&issuer=Example"
  inc="otpauth://hotp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&counter=11&issuer=Example"

  test_pass_git_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  code=$("$PASS" otp -q passfile) &&
  [[ ${#code} -eq 6 ]] &&
  [[ $("$PASS" otp uri passfile) == "$inc" ]]
'

test_expect_success 'HOTP counter increments and preserves multiline contents' '
  uri="otpauth://hotp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&counter=10&issuer=Example"
  inc="otpauth://hotp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&counter=11&issuer=Example"

  read -r -d "" existing <<EOF
foo bar baz
zab rab oof
$uri
baz bar foo
EOF

  read -r -d "" expected <<EOF
foo bar baz
zab rab oof
$inc
baz bar foo
EOF

  test_pass_init &&
  "$PASS" insert -mf passfile <<< "$existing" &&
  "$PASS" otp code passfile &&
  [[ $("$PASS" show passfile) == "$expected" ]]
'

test_expect_success 'Generates TOTP code for URI with port number' '
  uri="otpauth://totp/Example:alice@domain.com:443?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  code=$("$PASS" otp passfile) &&
  [[ ${#code} -eq 6 ]]
'

test_expect_success 'Generates HOTP code for URI with port number' '
  uri="otpauth://hotp/Example:alice@google.com:443?secret=JBSWY3DPEHPK3PXP&counter=10&issuer=Example"
  inc="otpauth://hotp/Example:alice@google.com:443?secret=JBSWY3DPEHPK3PXP&counter=11&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  code=$("$PASS" otp passfile) &&
  [[ ${#code} -eq 6 ]] &&
  [[ $("$PASS" otp uri passfile) == "$inc" ]]
'

test_done
