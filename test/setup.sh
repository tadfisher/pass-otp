#!/usr/bin/env bash

# This file should be sourced by all test-scripts
#
# This scripts sets the following:
#   $PASS	Full path to password-store script to test
#   $GPG	Name of gpg executable
#   $KEY{1..5}	GPG key ids of testing keys
#   $TEST_HOME	This folder


# Unset config vars
unset PASSWORD_STORE_DIR
unset PASSWORD_STORE_KEY
unset PASSWORD_STORE_GIT
unset PASSWORD_STORE_GPG_OPTS
unset PASSWORD_STORE_X_SELECTION
unset PASSWORD_STORE_CLIP_TIME
unset PASSWORD_STORE_UMASK
unset PASSWORD_STORE_GENERATED_LENGTH
unset PASSWORD_STORE_CHARACTER_SET
unset PASSWORD_STORE_CHARACTER_SET_NO_SYMBOLS
unset PASSWORD_STORE_ENABLE_EXTENSIONS
unset PASSWORD_STORE_EXTENSIONS_DIR
unset PASSWORD_STORE_SIGNING_KEY
unset EDITOR

# We must be called from test/
TEST_HOME="$(pwd)"
EXT_HOME="$(dirname "$TEST_HOME")"

# shellcheck disable=SC1091
. ./sharness.sh

export PASSWORD_STORE_ENABLE_EXTENSIONS=true
export PASSWORD_STORE_EXTENSIONS_DIR="$EXT_HOME"

export PASSWORD_STORE_DIR="$SHARNESS_TRASH_DIRECTORY/test-store"

export GIT_DIR="$PASSWORD_STORE_DIR/.git"
export GIT_WORK_TREE="$PASSWORD_STORE_DIR"
git config --global user.email "Pass-Automated-Testing-Suite@zx2c4.com"
git config --global user.name "Pass Automated Testing Suite"

PASS=$(which pass)
[[ -e $PASS ]] || error "Could not find pass command"

EXPECT=$(which expect)
[[ -e $EXPECT ]] || error "Could not find expect command"

OAUTHTOOL=$(which oathtool)
[[ -e $OAUTHTOOL ]] || error "Could not find oathtool command"

GPG=$(which gpg2) || GPG=$(which gpg)
[[ -e $GPG ]] || error "Could not find gpg command"

# Note: the assumption is the test key is unencrypted.
export GNUPGHOME="$TEST_HOME/gnupg/"
chmod 700 "$GNUPGHOME"

# We don't want any currently running agent to conflict.
unset GPG_AGENT_INFO

KEY[1]="CF90C77B"  # pass test key 1
KEY[2]="D774A374"  # pass test key 2
KEY[3]="EB7D54A8"  # pass test key 3
KEY[4]="E4691410"  # pass test key 4
KEY[5]="39E5020C"  # pass test key 5

# Test helpers
test_pass_init() {
  rm -rf "$PASSWORD_STORE_DIR"
  "$PASS" init "${KEY[@]}"
}

test_pass_git_init() {
    rm -rf "$PASSWORD_STORE_DIR"
    "$PASS" init "${KEY[@]}" && "$PASS" git init
}
