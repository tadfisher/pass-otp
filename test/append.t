#!/usr/bin/env bash

export test_description="Tests pass otp append commands"

. ./setup.sh

test_expect_success 'Reads non-terminal input' '
  existing="foo bar baz"
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"

  test_pass_init &&
  "$PASS" insert -e passfile <<< "$existing" &&
  "$PASS" otp append -e passfile <<< "$uri" &&
  [[ $("$PASS" otp uri passfile) == "$uri" ]]
'

test_expect_success 'Reads terminal input in noecho mode' '
  existing="foo bar baz"
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" insert -e passfile <<< "$existing" &&
  { expect -d <<EOD
    spawn "$PASS" otp append passfile
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
  } &&
  [[ $("$PASS" otp uri passfile) == "$uri" ]]
'

test_expect_success 'Reads terminal input in echo mode' '
  existing="foo bar baz"
  uri="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"

  test_pass_init &&
  "$PASS" insert -e passfile <<< "$existing" &&
  {
    expect <<EOD
      spawn "$PASS" otp append -e passfile
      expect {
        "Enter" {
          send "$uri\r"
          exp_continue
        }
        eof
      }
EOD
  } &&
  [[ $("$PASS" otp uri passfile) == "$uri" ]]
'

test_expect_success 'Prompts before overwriting key URI' '
  existing="foo bar baz"
  uri1="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"
  uri2="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Bar"

  test_pass_init &&
  "$PASS" insert -e passfile <<< "$existing" &&
  "$PASS" otp append -e passfile <<< "$uri1" &&
  {
    expect -d <<EOD
      spawn "$PASS" otp append -e passfile
      expect {
        "Enter" {
          send "$uri2\r"
          exp_continue
        }
        "An OTP secret already exists" {
          send "n\r"
          exp_continue
        }
        eof
      }
EOD
  } &&
  [[ $("$PASS" otp uri passfile) == "$uri1" ]]
'

test_expect_success 'Force overwrites key URI' '
  existing="foo bar baz"
  uri1="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"
  uri2="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Bar"

  test_pass_init &&
  "$PASS" insert -e passfile <<< "$existing" &&
  "$PASS" otp append -e passfile <<< "$uri1" &&
  "$PASS" otp append -ef passfile <<< "$uri2" &&
  [[ $("$PASS" otp uri passfile) == "$uri2" ]]
'

test_expect_success 'Preserves multiline contents' '
  uri1="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Foo"
  uri2="otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Bar"

  read -r -d "" existing <<EOF
foo bar baz
zab rab oof
$uri1
baz bar foo
EOF

  read -r -d "" expected <<EOF
foo bar baz
zab rab oof
$uri2
baz bar foo
EOF

  test_pass_init &&
  "$PASS" insert -mf passfile <<< "$existing" &&
  "$PASS" otp append -ef passfile <<< "$uri2" &&
  [[ $("$PASS" show passfile) == "$expected" ]]
'

test_done
