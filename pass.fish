#!/usr/bin/env fish

#TODO Do not suggest a second subcommand after a first one is used
#TODO Do not suggest --clip on insert, append or validate
#TODO Do not hard-code the path to the main pass completions
#TODO Make sure the Makefile does not overwrite the main pass completions
#TODO Make sure the default FISHCOMPDIR is in $fish_complete_path, and before the main pass completions' location

source "/usr/share/fish/vendor_completions.d/pass.fish"

# Allow for the checking of two commands
function __fish_pass_uses_command
    set -l cmd (commandline -opc)
    if test (count $argv) -gt 1
        if test (count $cmd) -gt 2
            if test \( $argv[1] = $cmd[2] \) -a \( $argv[2] = $cmd[3] \)
                return 0
            end
        end
    else if test (count $cmd) -gt 1
        if test $argv[1] = $cmd[2]
            return 0
        end
    end
    return 1
end

set -l PROG 'pass'

# Add `otp` after `pass`. Defaults to `pass otp code`
complete -c $PROG -f -n '__fish_pass_needs_command' -a otp -d 'Command: generate OTP code'
complete -c $PROG -f -n '__fish_pass_uses_command otp' -s c -l clip -d 'Put OTP code in clipboard'
complete -c $PROG -f -n '__fish_pass_uses_command otp' -a "(__fish_pass_print_entries_and_dirs)"

# Add `code` after `pass otp`
complete -c $PROG -f -n '__fish_pass_uses_command otp' -a code -d 'Command: generate an OTP code'
complete -c $PROG -f -n '__fish_pass_uses_command otp code' -s c -l clip -d 'Put OTP code in clipboard'

# Add `insert` after `pass otp`
complete -c $PROG -f -n '__fish_pass_uses_command otp' -a insert -d 'Command: insert a new OTP key URI in a new password file'
complete -c $PROG -f -n '__fish_pass_uses_command otp insert' -s e -l echo -d 'Echo the input'
complete -c $PROG -f -n '__fish_pass_uses_command otp insert' -s f -l force -d 'Do not prompt before overwriting an existing URI'

# Add `append` after `pass otp`
complete -c $PROG -f -n '__fish_pass_uses_command otp' -a append -d 'Command: append an OTP key URI to an existing password file'
complete -c $PROG -f -n '__fish_pass_uses_command otp append' -s e -l echo -d 'Echo the input'
complete -c $PROG -f -n '__fish_pass_uses_command otp append' -s f -l force -d 'Do not prompt before overwriting an existing URI'
complete -c $PROG -f -n '__fish_pass_uses_command otp append' -a "(__fish_pass_print_entries_and_dirs)"

# Add `uri` after `pass otp`
complete -c $PROG -f -n '__fish_pass_uses_command otp' -a uri -d 'Command: display the stored key URI'
complete -c $PROG -f -n '__fish_pass_uses_command otp uri' -s c -l clip -d 'Put key URI in clipboard'
complete -c $PROG -f -n '__fish_pass_uses_command otp uri' -s q -l qrcode -d 'Display a QR code'
complete -c $PROG -f -n '__fish_pass_uses_command otp uri' -a "(__fish_pass_print_entries_and_dirs)"

# Add `validate` after `pass otp`
complete -c $PROG -f -n '__fish_pass_uses_command otp' -a validate -d 'Command: test if the given URI is a valid OTP key URI'
