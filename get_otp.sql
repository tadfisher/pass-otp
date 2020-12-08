/*
If a bash script is needed for some reason, it could be along the lines of:

if ! [[ -f "$1" ]]; then
    die "$1 is not a file"
elif [[ $(file -b --mime-type "$1") != "application/x-sqlite3" ]]; then
    die "$1 is not an SQLite3 database"
fi

sqlite3 "$1" < get_otp.sql

*/
SELECT printf('otpauth://totp/%s?secret=%s&issuer=%s', email, secret, issuer) FROM accounts
