#!/usr/bin/env bash
# Builds dwm, st, dmenu and slock as install.sh does (make clean all in each),
# with every warning an error. -Wall is what dwm, dmenu and slock already
# build with; st gets the same.
set -euo pipefail
cd "$(dirname "$0")/.."

cc=${CC:-cc}
for tool in dwm st dmenu slock; do
    echo "== $tool"
    make -C "suckless/$tool" clean all CC="$cc -Wall -Werror"
done
