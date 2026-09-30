# shellcheck shell=bash
# Helpers shared by the tests in this directory; every test sources this.
# A test prints one line per check and exits non-zero if any check failed.

# shellcheck disable=SC2034  # ROOT is for the tests that source this file
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fails=0

pass() { printf '  ok    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; fails=$((fails + 1)); }

# expect DESCRIPTION EXPECTED ACTUAL
expect() {
    if [[ $2 == "$3" ]]; then pass "$1"; else fail "$1 (expected '$2', got '$3')"; fi
}

# expect_match DESCRIPTION REGEX TEXT (grep -E)
expect_match() {
    if grep -qE -- "$2" <<<"$3"; then pass "$1"; else fail "$1 (no '$2' in: $3)"; fi
}

# expect_no_match DESCRIPTION REGEX TEXT (grep -E)
expect_no_match() {
    if grep -qE -- "$2" <<<"$3"; then fail "$1 (unexpected '$2' in: $3)"; else pass "$1"; fi
}

# sandbox: a fresh temp dir in $T, removed when the test exits
sandbox() {
    T=$(mktemp -d)
    trap 'rm -rf "$T"' EXIT
}

# stub NAME BODY: put a /bin/sh command NAME running BODY in $T/bin, which
# tests put first on PATH
stub() {
    mkdir -p "$T/bin"
    printf '#!/bin/sh\n%s\n' "$2" >"$T/bin/$1"
    chmod +x "$T/bin/$1"
}

# git with no user or system config, so a test sees the same git everywhere
git_sandboxed() {
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
}

finish() {
    exit $((fails > 0))
}
