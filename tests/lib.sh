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

# sandbox: a fresh temp dir in $T, removed when the test exits; and no
# XDG_CONFIG_HOME, so pointing HOME into $T moves ~/.config there too
sandbox() {
    T=$(mktemp -d)
    trap 'rm -rf "$T"' EXIT
    unset XDG_CONFIG_HOME
}

# stub NAME BODY: put a /bin/sh command NAME running BODY in $T/bin, which
# tests put first on PATH
stub() {
    mkdir -p "$T/bin"
    printf '#!/bin/sh\n%s\n' "$2" >"$T/bin/$1"
    chmod +x "$T/bin/$1"
}

# theme_repo DIR: a copy of what fdwm-theme reads and writes in the repo
# (the palette, grub/, dunst/, suckless/ for colors.h), so a test can
# generate the colors without touching the checkout
theme_repo() {
    mkdir -p "$1/suckless"
    cp "$ROOT/fdwm-theme" "$ROOT/palette" "$1/"
    cp -r "$ROOT/grub" "$ROOT/dunst" "$1/"
}

# other_flavor DIR: a second flavor, other, in DIR's palette (a copy of
# theme_repo's), for tests of switching between flavors now that the real
# palette has only thinkpad: the first flavor's colors with each blue
# channel moved, so every color differs from it
other_flavor() {
    local line name first
    while IFS= read -r line; do
        read -r name first _ <<<"$line"
        if [[ $line =~ ^[[:space:]]*(#|$) ]]; then
            printf '%s\n' "$line"
        elif [[ $name == name ]]; then
            printf '%s  other\n' "$line"
        elif [[ $first =~ ^[0-9a-f]{6}$ ]]; then
            printf '%s  %s%02x\n' "$line" "${first:0:4}" $(((16#${first:4:2} + 32) % 256))
        else
            printf '%s  %s\n' "$line" "$first"
        fi
    done <"$1/palette" >"$1/palette.new"
    mv "$1/palette.new" "$1/palette"
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
