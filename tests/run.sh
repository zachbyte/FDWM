#!/usr/bin/env bash
# Runs every tests/test_*.sh and says which ones failed.
set -u
cd "$(dirname "$0")" || exit 1

failed=()
for t in test_*.sh; do
    echo "== $t"
    bash "$t" || failed+=("$t")
done

if ((${#failed[@]})); then
    echo "FAILED: ${failed[*]}"
    exit 1
fi
echo "All tests passed"
