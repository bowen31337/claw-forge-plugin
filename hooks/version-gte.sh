#!/bin/sh
# POSIX semver comparator.
# Usage: version-gte.sh <current> <minimum>
# Exits 0 when current >= minimum, 1 otherwise.
# No-arg invocation runs self-tests and prints "all pass" on success.

set -eu

_split() {
    _v="${1#v}"
    _maj="${_v%%.*}"
    case "$_v" in
        *.*.*)
            _rest="${_v#*.}"
            _min="${_rest%%.*}"
            _pat="${_rest#*.}"
            ;;
        *.*)
            _min="${_v#*.}"
            _pat=0
            ;;
        *)
            _min=0
            _pat=0
            ;;
    esac
    _pat="${_pat%%.*}"
    _pat="${_pat%%-*}"
    _pat="${_pat%%+*}"
    _min="${_min%%-*}"
    _min="${_min%%+*}"
    _maj="${_maj%%-*}"
    _maj="${_maj%%+*}"
}

_gte() {
    _split "$1"
    _a_maj=$_maj
    _a_min=$_min
    _a_pat=$_pat
    _split "$2"
    if   [ "$_a_maj" -gt "$_maj" ]; then return 0
    elif [ "$_a_maj" -lt "$_maj" ]; then return 1
    elif [ "$_a_min" -gt "$_min" ]; then return 0
    elif [ "$_a_min" -lt "$_min" ]; then return 1
    elif [ "$_a_pat" -ge "$_pat" ]; then return 0
    else return 1
    fi
}

if [ "$#" -eq 2 ]; then
    _gte "$1" "$2"
    exit
fi

if [ "$#" -ne 0 ]; then
    printf 'usage: %s <current> <minimum>\n' "$0" >&2
    exit 2
fi

# Self-test mode
_pass=0
_fail=0

_ok() {
    if _gte "$1" "$2"; then
        _pass=$(( _pass + 1 ))
    else
        printf 'FAIL: %s >= %s expected true\n' "$1" "$2" >&2
        _fail=$(( _fail + 1 ))
    fi
}

_no() {
    if _gte "$1" "$2"; then
        printf 'FAIL: %s >= %s expected false\n' "$1" "$2" >&2
        _fail=$(( _fail + 1 ))
    else
        _pass=$(( _pass + 1 ))
    fi
}

# equal
_ok  "1.2.3"      "1.2.3"
_ok  "0.0.0"      "0.0.0"
_ok  "0.6.0"      "0.6.0"

# greater major
_ok  "2.0.0"      "1.9.9"
_ok  "10.0.0"     "9.9.9"

# greater minor
_ok  "1.3.0"      "1.2.9"
_ok  "1.0.0"      "0.6.0"

# greater patch
_ok  "1.2.4"      "1.2.3"
_ok  "0.6.1"      "0.6.0"

# leading v stripped
_ok  "v1.2.3"     "1.2.3"
_ok  "1.2.3"      "v1.2.3"
_ok  "v0.6.0"     "v0.6.0"

# pre-release: numeric part compared, suffix ignored
_ok  "0.6.0-rc1"  "0.6.0"
_ok  "1.0.0-beta" "1.0.0"

# less-than
_no  "1.9.9"      "2.0.0"
_no  "1.2.9"      "1.3.0"
_no  "1.2.3"      "1.2.4"
_no  "0.5.9"      "0.6.0"
_no  "0.0.1"      "0.1.0"

if [ "$_fail" -eq 0 ]; then
    printf 'all pass (%d cases)\n' "$_pass"
    exit 0
fi
printf '%d/%d cases failed\n' "$_fail" $(( _pass + _fail )) >&2
exit 1
