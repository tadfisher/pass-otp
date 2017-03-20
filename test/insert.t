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

  test_pass_init
  "$PASS" otp insert "$uri1" passfile
  expect <<EOD
    spawn "$PASS" otp insert "$uri2" passfile
    expect {
      "An entry already exists" {
        send "n\r"
        exp_continue
      }
      eof
    }
EOD
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

test_expect_success 'Reads non-terminal input' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  [[ $("$PASS" show passfile) == "$uri" ]]
'

test_expect_success 'Reads terminal input in noecho mode' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init
  expect <<EOD
    spawn "$PASS" otp insert passfile
    expect {
      "Enter" {
        send "$uri\r"
        exp_continue
      }
      "Retype" {
        send "$uri\r"
        exp_continue
      }
      eof
    }
EOD
  [[ $("$PASS" show passfile) == "$uri" ]]
'

test_expect_success 'Reads terminal input in echo mode' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init
  expect <<EOD
    spawn "$PASS" otp insert -e passfile
    expect {
      "Enter" {
        send "$uri\r"
        exp_continue
      }
      eof
    }
EOD
  [[ $("$PASS" show passfile) == "$uri" ]]
'

test_done
