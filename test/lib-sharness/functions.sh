# Library of functions shared by all tests scripts, included by
# sharness.sh.
#
# Copyright (c) 2005-2019 Junio C Hamano
# Copyright (c) 2005-2019 Git project
# Copyright (c) 2011-2019 Mathias Lafeldt
# Copyright (c) 2015-2019 Christian Couder
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see http://www.gnu.org/licenses/ .

# These assignments are to make shellcheck happy. They should be
# removed when we can use a new version of shellcheck that contains:
# https://github.com/koalaman/shellcheck/pull/1553
: "${debug:=}"
: "${verbose:=}"
: "${this_test:=}"
: "${skip_all:=}"
: "${EXIT_OK:=}"
: "${test_failure:=0}"
: "${test_fixed:=0}"
: "${test_broken:=0}"
: "${test_success:=0}"

# Public: Define that a test prerequisite is available.
#
# The prerequisite can later be checked explicitly using test_have_prereq or
# implicitly by specifying the prerequisite name in calls to test_expect_success
# or test_expect_failure.
#
# $1 - Name of prerequisite (a simple word, in all capital letters by convention)
#
# Examples
#
#   # Set PYTHON prerequisite if interpreter is available.
#   command -v python >/dev/null && test_set_prereq PYTHON
#
#   # Set prerequisite depending on some variable.
#   test -z "$NO_GETTEXT" && test_set_prereq GETTEXT
#
# Returns nothing.
test_set_prereq() {
	satisfied_prereq="$satisfied_prereq$1 "
}
satisfied_prereq=" "

# Public: Check if one or more test prerequisites are defined.
#
# The prerequisites must have previously been set with test_set_prereq.
# The most common use of this is to skip all the tests if some essential
# prerequisite is missing.
#
# $1 - Comma-separated list of test prerequisites.
#
# Examples
#
#   # Skip all remaining tests if prerequisite is not set.
#   if ! test_have_prereq PERL; then
#       skip_all='skipping perl interface tests, perl not available'
#       test_done
#   fi
#
# Returns 0 if all prerequisites are defined or 1 otherwise.
test_have_prereq() {
	# prerequisites can be concatenated with ','
	save_IFS=$IFS
	IFS=,
	set -- $@
	IFS=$save_IFS

	total_prereq=0
	ok_prereq=0
	missing_prereq=

	for prerequisite; do
		case "$prerequisite" in
		!*)
			negative_prereq=t
			prerequisite=${prerequisite#!}
			;;
		*)
			negative_prereq=
		esac

		total_prereq=$((total_prereq + 1))
		case "$satisfied_prereq" in
		*" $prerequisite "*)
			satisfied_this_prereq=t
			;;
		*)
			satisfied_this_prereq=
		esac

		case "$satisfied_this_prereq,$negative_prereq" in
		t,|,t)
			ok_prereq=$((ok_prereq + 1))
			;;
		*)
			# Keep a list of missing prerequisites; restore
			# the negative marker if necessary.
			prerequisite=${negative_prereq:+!}$prerequisite
			if test -z "$missing_prereq"; then
				missing_prereq=$prerequisite
			else
				missing_prereq="$prerequisite,$missing_prereq"
			fi
		esac
	done

	test $total_prereq = $ok_prereq
}

# Public: Execute commands in debug mode.
#
# Takes a single argument and evaluates it only when the test script is started
# with --debug. This is primarily meant for use during the development of test
# scripts.
#
# $1 - Commands to be executed.
#
# Examples
#
#   test_debug "cat some_log_file"
#
# Returns the exit code of the last command executed in debug mode or 0
#   otherwise.
test_debug() {
	test "$debug" = "" || eval "$1"
}

# Public: Stop execution and start a shell.
#
# This is useful for debugging tests and only makes sense together with "-v".
# Be sure to remove all invocations of this command before submitting.
test_pause() {
	if test "$verbose" = t; then
		"$SHELL_PATH" <&6 >&3 2>&4
	else
		error >&5 "test_pause requires --verbose"
	fi
}

# Public: Run test commands and expect them to succeed.
#
# When the test passed, an "ok" message is printed and the number of successful
# tests is incremented. When it failed, a "not ok" message is printed and the
# number of failed tests is incremented.
#
# With --immediate, exit test immediately upon the first failed test.
#
# Usually takes two arguments:
# $1 - Test description
# $2 - Commands to be executed.
#
# With three arguments, the first will be taken to be a prerequisite:
# $1 - Comma-separated list of test prerequisites. The test will be skipped if
#      not all of the given prerequisites are set. To negate a prerequisite,
#      put a "!" in front of it.
# $2 - Test description
# $3 - Commands to be executed.
#
# Examples
#
#   test_expect_success \
#       'git-write-tree should be able to write an empty tree.' \
#       'tree=$(git-write-tree)'
#
#   # Test depending on one prerequisite.
#   test_expect_success TTY 'git --paginate rev-list uses a pager' \
#       ' ... '
#
#   # Multiple prerequisites are separated by a comma.
#   test_expect_success PERL,PYTHON 'yo dawg' \
#       ' test $(perl -E 'print eval "1 +" . qx[python -c "print 2"]') == "4" '
#
# Returns nothing.
test_expect_success() {
	test "$#" = 3 && { test_prereq=$1; shift; } || test_prereq=
	test "$#" = 2 || error "bug in the test script: not 2 or 3 parameters to test_expect_success"
	export test_prereq
	if ! test_skip_ "$@"; then
		say >&3 "expecting success: $2"
		if test_run_ "$2"; then
			test_ok_ "$1"
		else
			test_failure_ "$@"
		fi
	fi
	echo >&3 ""
}

# Public: Run test commands and expect them to fail. Used to demonstrate a known
# breakage.
#
# This is NOT the opposite of test_expect_success, but rather used to mark a
# test that demonstrates a known breakage.
#
# When the test passed, an "ok" message is printed and the number of fixed tests
# is incremented. When it failed, a "not ok" message is printed and the number
# of tests still broken is incremented.
#
# Failures from these tests won't cause --immediate to stop.
#
# Usually takes two arguments:
# $1 - Test description
# $2 - Commands to be executed.
#
# With three arguments, the first will be taken to be a prerequisite:
# $1 - Comma-separated list of test prerequisites. The test will be skipped if
#      not all of the given prerequisites are set. To negate a prerequisite,
#      put a "!" in front of it.
# $2 - Test description
# $3 - Commands to be executed.
#
# Returns nothing.
test_expect_failure() {
	test "$#" = 3 && { test_prereq=$1; shift; } || test_prereq=
	test "$#" = 2 || error "bug in the test script: not 2 or 3 parameters to test_expect_failure"
	export test_prereq
	if ! test_skip_ "$@"; then
		say >&3 "checking known breakage: $2"
		if test_run_ "$2" expecting_failure; then
			test_known_broken_ok_ "$1"
		else
			test_known_broken_failure_ "$1"
		fi
	fi
	echo >&3 ""
}

# Public: Run test commands and expect anything from them. Used when a
# test is not stable or not finished for some reason.
#
# When the test passed, an "ok" message is printed, but the number of
# fixed tests is not incremented.
#
# When it failed, a "not ok ... # TODO known breakage" message is
# printed, and the number of tests still broken is incremented.
#
# Failures from these tests won't cause --immediate to stop.
#
# Usually takes two arguments:
# $1 - Test description
# $2 - Commands to be executed.
#
# With three arguments, the first will be taken to be a prerequisite:
# $1 - Comma-separated list of test prerequisites. The test will be skipped if
#      not all of the given prerequisites are set. To negate a prerequisite,
#      put a "!" in front of it.
# $2 - Test description
# $3 - Commands to be executed.
#
# Returns nothing.
test_expect_unstable() {
	test "$#" = 3 && { test_prereq=$1; shift; } || test_prereq=
	test "$#" = 2 || error "bug in the test script: not 2 or 3 parameters to test_expect_unstable"
	export test_prereq
	if ! test_skip_ "$@"; then
		say >&3 "checking unstable test: $2"
		if test_run_ "$2" unstable; then
			test_ok_ "$1"
		else
			test_known_broken_failure_ "$1"
		fi
	fi
	echo >&3 ""
}

# Public: Run command and ensure that it fails in a controlled way.
#
# Use it instead of "! <command>". For example, when <command> dies due to a
# segfault, test_must_fail diagnoses it as an error, while "! <command>" would
# mistakenly be treated as just another expected failure.
#
# This is one of the prefix functions to be used inside test_expect_success or
# test_expect_failure.
#
# $1.. - Command to be executed.
#
# Examples
#
#   test_expect_success 'complain and die' '
#       do something &&
#       do something else &&
#       test_must_fail git checkout ../outerspace
#   '
#
# Returns 1 if the command succeeded (exit code 0).
# Returns 1 if the command died by signal (exit codes 130-192)
# Returns 1 if the command could not be found (exit code 127).
# Returns 0 otherwise.
test_must_fail() {
	"$@"
	exit_code=$?
	if test $exit_code = 0; then
		echo >&2 "test_must_fail: command succeeded: $*"
		return 1
	elif test $exit_code -gt 129 -a $exit_code -le 192; then
		echo >&2 "test_must_fail: died by signal: $*"
		return 1
	elif test $exit_code = 127; then
		echo >&2 "test_must_fail: command not found: $*"
		return 1
	fi
	return 0
}

# Public: Run command and ensure that it succeeds or fails in a controlled way.
#
# Similar to test_must_fail, but tolerates success too. Use it instead of
# "<command> || :" to catch failures caused by a segfault, for instance.
#
# This is one of the prefix functions to be used inside test_expect_success or
# test_expect_failure.
#
# $1.. - Command to be executed.
#
# Examples
#
#   test_expect_success 'some command works without configuration' '
#       test_might_fail git config --unset all.configuration &&
#       do something
#   '
#
# Returns 1 if the command died by signal (exit codes 130-192)
# Returns 1 if the command could not be found (exit code 127).
# Returns 0 otherwise.
test_might_fail() {
	"$@"
	exit_code=$?
	if test $exit_code -gt 129 -a $exit_code -le 192; then
		echo >&2 "test_might_fail: died by signal: $*"
		return 1
	elif test $exit_code = 127; then
		echo >&2 "test_might_fail: command not found: $*"
		return 1
	fi
	return 0
}

# Public: Run command and ensure it exits with a given exit code.
#
# This is one of the prefix functions to be used inside test_expect_success or
# test_expect_failure.
#
# $1   - Expected exit code.
# $2.. - Command to be executed.
#
# Examples
#
#   test_expect_success 'Merge with d/f conflicts' '
#       test_expect_code 1 git merge "merge msg" B master
#   '
#
# Returns 0 if the expected exit code is returned or 1 otherwise.
test_expect_code() {
	want_code=$1
	shift
	"$@"
	exit_code=$?
	if test "$exit_code" = "$want_code"; then
		return 0
	fi

	echo >&2 "test_expect_code: command exited with $exit_code, we wanted $want_code $*"
	return 1
}

# Public: Compare two files to see if expected output matches actual output.
#
# The TEST_CMP variable defines the command used for the comparison; it
# defaults to "diff -u". Only when the test script was started with --verbose,
# will the command's output, the diff, be printed to the standard output.
#
# This is one of the prefix functions to be used inside test_expect_success or
# test_expect_failure.
#
# $1 - Path to file with expected output.
# $2 - Path to file with actual output.
#
# Examples
#
#   test_expect_success 'foo works' '
#       echo expected >expected &&
#       foo >actual &&
#       test_cmp expected actual
#   '
#
# Returns the exit code of the command set by TEST_CMP.
test_cmp() {
	${TEST_CMP:-diff -u} "$@"
}

# Public: portably print a sequence of numbers.
#
# seq is not in POSIX and GNU seq might not be available everywhere,
# so it is nice to have a seq implementation, even a very simple one.
#
# $1 - Starting number.
# $2 - Ending number.
#
# Examples
#
#   test_expect_success 'foo works 10 times' '
#       for i in $(test_seq 1 10)
#       do
#           foo || return
#       done
#   '
#
# Returns 0 if all the specified numbers can be displayed.
test_seq() {
	i="$1"
	j="$2"
	while test "$i" -le "$j"
	do
		echo "$i" || return
		i=$(("$i" + 1))
	done
}

# Public: Check if the file expected to be empty is indeed empty, and barfs
# otherwise.
#
# $1 - File to check for emptiness.
#
# Returns 0 if file is empty, 1 otherwise.
test_must_be_empty() {
	if test -s "$1"
	then
		echo "'$1' is not empty, it contains:"
		cat "$1"
		return 1
	fi
}

# debugging-friendly alternatives to "test [-f|-d|-e]"
# The commands test the existence or non-existence of $1. $2 can be
# given to provide a more precise diagnosis.
test_path_is_file () {
	if ! test -f "$1"
	then
		echo "File $1 doesn't exist. $2"
		false
	fi
}

test_path_is_dir () {
	if ! test -d "$1"
	then
		echo "Directory $1 doesn't exist. $2"
		false
	fi
}

# Check if the directory exists and is empty as expected, barf otherwise.
test_dir_is_empty () {
	test_path_is_dir "$1" &&
	if test -n "$(find "$1" -mindepth 1 -maxdepth 1)"
	then
		echo "Directory '$1' is not empty, it contains:"
		ls -la "$1"
		return 1
	fi
}

# Public: Schedule cleanup commands to be run unconditionally at the end of a
# test.
#
# If some cleanup command fails, the test will not pass. With --immediate, no
# cleanup is done to help diagnose what went wrong.
#
# This is one of the prefix functions to be used inside test_expect_success or
# test_expect_failure.
#
# $1.. - Commands to prepend to the list of cleanup commands.
#
# Examples
#
#   test_expect_success 'test core.capslock' '
#       git config core.capslock true &&
#       test_when_finished "git config --unset core.capslock" &&
#       do_something
#   '
#
# Returns the exit code of the last cleanup command executed.
test_when_finished() {
	test_cleanup="{ $*
		} && (exit \"\$eval_ret\"); eval_ret=\$?; $test_cleanup"
}

# Public: Schedule cleanup commands to be run unconditionally when all tests
# have run.
#
# This can be used to clean up things like test databases. It is not needed to
# clean up temporary files, as test_done already does that.
#
# Examples:
#
#   cleanup mysql -e "DROP DATABASE mytest"
#
# Returns the exit code of the last cleanup command executed.
final_cleanup=
cleanup() {
	final_cleanup="{ $*
		} && (exit \"\$eval_ret\"); eval_ret=\$?; $final_cleanup"
}

# Public: Summarize test results and exit with an appropriate error code.
#
# Must be called at the end of each test script.
#
# Can also be used to stop tests early and skip all remaining tests. For this,
# set skip_all to a string explaining why the tests were skipped before calling
# test_done.
#
# Examples
#
#   # Each test script must call test_done at the end.
#   test_done
#
#   # Skip all remaining tests if prerequisite is not set.
#   if ! test_have_prereq PERL; then
#       skip_all='skipping perl interface tests, perl not available'
#       test_done
#   fi
#
# Returns 0 if all tests passed or 1 if there was a failure.
test_done() {
	EXIT_OK=t

	if test -z "$HARNESS_ACTIVE"; then
		test_results_dir="$SHARNESS_TEST_OUTDIR/test-results"
		mkdir -p "$test_results_dir"
		test_results_path="$test_results_dir/$this_test.$$.counts"

		cat >>"$test_results_path" <<-EOF
		total $SHARNESS_TEST_NB
		success $test_success
		fixed $test_fixed
		broken $test_broken
		failed $test_failure

		EOF
	fi

	if test "$test_fixed" != 0; then
		say_color error "# $test_fixed known breakage(s) vanished; please update test(s)"
	fi
	if test "$test_broken" != 0; then
		say_color warn "# still have $test_broken known breakage(s)"
	fi
	if test "$test_broken" != 0 || test "$test_fixed" != 0; then
		test_remaining=$((SHARNESS_TEST_NB - test_broken - test_fixed))
		msg="remaining $test_remaining test(s)"
	else
		test_remaining=$SHARNESS_TEST_NB
		msg="$SHARNESS_TEST_NB test(s)"
	fi

	case "$test_failure" in
	0)
		# Maybe print SKIP message
		check_skip_all_
		if test "$test_remaining" -gt 0; then
			say_color pass "# passed all $msg"
		fi
		say "1..$SHARNESS_TEST_NB$skip_all"

		test_eval_ "$final_cleanup"

		remove_trash_

		exit 0 ;;

	*)
		say_color error "# failed $test_failure among $msg"
		say "1..$SHARNESS_TEST_NB"

		exit 1 ;;

	esac
}
