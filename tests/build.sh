#!/usr/bin/env bash
# Builds dwm, st, dmenu and slock as install.sh does (make clean all in each),
# with every warning an error. -Wall is what dwm, dmenu and slock already
# build with; st gets the same. tests/werror-cc does the compiling and lists
# the few upstream warnings that are let through.
set -euo pipefail
cd "$(dirname "$0")/.."

# colors.h, as install.sh does first (in thinkpad), with a throwaway home for the
# colors.sh and dunst colors it also writes, so yours are left alone
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT
env -u XDG_CONFIG_HOME HOME="$home" ./fdwm-theme generate

export WERROR_CC=${CC:-cc}
for tool in dwm st dmenu slock; do
    echo "== $tool"
    make -C "suckless/$tool" clean all CC="$PWD/tests/werror-cc"
done
