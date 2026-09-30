#!/usr/bin/env bash
# The README and install.sh must agree with packages.txt and with each other
# on what gets installed and built.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"

# README step 2 word-splits packages.txt; install.sh reads it with xargs -n1
# shellcheck disable=SC2046  # word splitting is the point, as in the README
readme=$(printf '%s\n' $(sed 's/#.*//' "$ROOT/packages.txt"))
install=$(sed 's/#.*//' "$ROOT/packages.txt" | xargs -n1)
expect "README step 2 installs exactly what install.sh installs" "$install" "$readme"
expect_match "README step 2 uses packages.txt" "sudo dnf install \\\$\(sed 's/#\.\*//' packages\.txt\)" "$(cat "$ROOT/README.md")"

tools() { grep -o 'for tool in [a-z ]*; do' "$1" | head -1; }
expect "README builds the same tools as install.sh" "$(tools "$ROOT/install.sh")" "$(tools "$ROOT/README.md")"
for t in $(tools "$ROOT/install.sh" | sed 's/for tool in //; s/; do//'); do
    expect "suckless/$t has a Makefile" yes "$([[ -f $ROOT/suckless/$t/Makefile ]] && echo yes)"
done

finish
