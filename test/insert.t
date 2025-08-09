#!/usr/bin/env bash

export test_description="Tests pass otp insert commands"

. ./setup.sh

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

test_expect_success 'Prompts before overwriting key URI' '
  uri1="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"
  uri2="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Bar"

  test_pass_init
  "$PASS" otp insert passfile <<< "$uri1" || return 1
  expect <<EOD
    spawn "$PASS" otp insert -e passfile
    expect {
      "Enter" {
        send "$uri2\r"
        exp_continue
      }
      "An entry already exists" {
        send "n\r"
        exp_continue
      }
      eof
    }
EOD
  [[ $("$PASS" show passfile) == "$uri1" ]]
'

test_expect_success 'Generates default pass-name from label' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init
  "$PASS" otp insert <<< "$uri"
  [[ $("$PASS" show "Example/alice@google.com") == "$uri" ]]
'

test_expect_success 'Prompts when inserting default pass-name from terminal' '
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init
  expect <<EOD
    spawn "$PASS" otp insert -e
    expect {
      "Enter" {
        send "$uri\r"
        exp_continue
      }
      "Insert into Example/alice@google.com?" {
        send "y\r"
        exp_continue
      }
      eof
    }
EOD
  [[ $("$PASS" show "Example/alice@google.com") == "$uri" ]]
'

test_expect_success 'Force overwrites key URI' '
  uri1="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"
  uri2="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Bar"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri1" &&
  "$PASS" otp insert -f passfile <<< "$uri2" &&
  [[ $("$PASS" show passfile) == "$uri2" ]]
'

test_expect_success 'Insert passfile from secret with options(issuer, accountname)' '
  secret="JBSWY3DPEHPK3PXP"
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert -s -i Example -a alice@google.com passfile <<< "$secret" &&
   echo [[ $("$PASS" show passfile) == "$uri" ]]
'

test_expect_success 'Insert from secret without passfile' '
  secret="JBSWY3DPEHPK3PXP"
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert -s -i Example -a alice@google.com <<< "$secret" &&
   echo [[ $("$PASS" show Example/alice@google.com) == "$uri" ]]
'

test_expect_success 'Tolerates padding in secret' '
  secret="JBSWY3DPEHPK3PXP=="
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert -s -i Example -a alice@google.com <<< "$secret" &&
  echo [[ $("$PASS" show Example/alice@google.com) == "$uri" ]]
'

test_expect_success 'Allow path prefixes in insert' '
  secret="JBSWY3DPEHPK3PXP=="
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert -s -p totp -i Example -a alice@google.com <<< "$secret" &&
  echo [[ $("$PASS" show totp/Example/alice@google.com) == "$uri" ]]
'

test_expect_success 'Allow multiple levels in path prefix' '
  secret="JBSWY3DPEHPK3PXP=="
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert -s -p totp/pass-test -i Example -a alice@google.com <<< "$secret" &&
  echo [[ $("$PASS" show totp/pass-test/Example/alice@google.com) == "$uri" ]]
'

test_expect_success 'Insert TOTP URI with port number' '
  uri="otpauth://totp/Example:alice@google.com:443?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" otp insert passfile <<< "$uri" &&
  [[ $("$PASS" show passfile) == "$uri" ]]
'

test_done
