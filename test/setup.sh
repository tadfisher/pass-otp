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

. ./sharness.sh

export PASSWORD_STORE_ENABLE_EXTENSIONS=true
export PASSWORD_STORE_EXTENSIONS_DIR="../"

export PASSWORD_STORE_DIR="$SHARNESS_TRASH_DIRECTORY/test-store"
rm -rf "$PASSWORD_STORE_DIR"
mkdir -p "$PASSWORD_STORE_DIR"
if [[ ! -d $PASSWORD_STORE_DIR ]]; then
	echo "Could not create $PASSWORD_STORE_DIR"
	exit 1
fi

export GIT_DIR="$PASSWORD_STORE_DIR/.git"
export GIT_WORK_TREE="$PASSWORD_STORE_DIR"
git config --global user.email "Pass-Automated-Testing-Suite@zx2c4.com"
git config --global user.name "Pass Automated Testing Suite"

PASS=`which pass`
if [[ ! -e $PASS ]]; then
	echo "Could not find pass command"
	exit 1
fi

# Note: the assumption is the test key is unencrypted.
export GNUPGHOME="$TEST_HOME/gnupg/"
chmod 700 "$GNUPGHOME"
GPG="gpg"
which gpg2 &>/dev/null && GPG="gpg2"

# We don't want any currently running agent to conflict.
unset GPG_AGENT_INFO

KEY1="CF90C77B"  # pass test key 1
KEY2="D774A374"  # pass test key 2
KEY3="EB7D54A8"  # pass test key 3
KEY4="E4691410"  # pass test key 4
KEY5="39E5020C"  # pass test key 5
