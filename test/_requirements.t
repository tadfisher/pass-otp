#!/usr/bin/env bash

export test_description='Check test requirements'

. ./setup.sh

test_expect_success 'Check that expect is installed' '
  $(which expect)
'

test_expect_success 'Check that oathtool is installed' '
  $(which oathtool)
'

test_done
