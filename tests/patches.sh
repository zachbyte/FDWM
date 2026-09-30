#!/usr/bin/env bash
# Rebuilds dwm, st, dmenu and slock from upstream and patches/, which proves
# patches/ records every change: for each release in patches/upstream it
# downloads the tarball (checking its sha256), applies patches/<tool>/*.diff
# in order with git apply, and checks the result is suckless/<tool> exactly,
# file for file. Set FDWM_TARBALLS to a folder of the tarballs to skip the
# download.
#
#   tests/patches.sh [--keep DIR]
#
# --keep leaves each rebuilt tree in DIR/<tool>, a git repository with one
# commit per diff that applied: for moving to a new release (see "Patches"
# in the README).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
root=$PWD

keep=
if [[ ${1:-} == --keep ]]; then
    keep=${2:?usage: tests/patches.sh [--keep DIR]}
    mkdir -p "$keep"
fi
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

status=0
fail() { echo "  FAIL  $*"; status=1; }

while read -r tool version url sum; do
    echo "== $tool $version"
    tarball=${FDWM_TARBALLS:+$FDWM_TARBALLS/${url##*/}}
    if [[ -z $tarball ]]; then
        tarball=$T/${url##*/}
        curl -fsSL -o "$tarball" "$url" || { fail "can't download $url"; continue; }
    fi
    if ! echo "$sum  $tarball" | sha256sum -c --quiet - >/dev/null 2>&1; then
        fail "${url##*/}: sha256 isn't $sum"
        continue
    fi
    grep -qx "VERSION = $version" "suckless/$tool/config.mk" ||
        fail "suckless/$tool/config.mk doesn't say VERSION = $version"

    # the release, as its own git repository so git apply works inside it
    tree=${keep:-$T}/$tool
    rm -rf "$tree" && mkdir -p "$tree"
    tar -xzf "$tarball" -C "$tree" --strip-components=1
    git -C "$tree" init -q
    # commit NAME: with --keep, a commit of the tree as it is now
    commit() {
        [[ -n $keep ]] || return 0
        git -C "$tree" add -A &&
            git -C "$tree" -c user.name=fdwm -c user.email=fdwm@localhost commit -qm "$1"
    }
    commit "$tool $version"
    n=0
    for p in patches/"$tool"/*.diff; do
        if ! git -C "$tree" apply --whitespace=nowarn "$root/$p"; then
            fail "$p does not apply (after $n)"
            continue 2
        fi
        commit "${p##*/}"
        n=$((n + 1))
    done
    echo "  ok    $n patches apply"

    # the same files as the repo, with the same content and executable bits
    want=$(git ls-files "suckless/$tool" | sed "s#^suckless/$tool/##" | sort)
    got=$(cd "$tree" && find . -path ./.git -prune -o -type f -print | sed 's#^\./##' | sort)
    if [[ $want != "$got" ]]; then
        fail "$tool: not the same files as suckless/$tool:"
        diff <(echo "$want") <(echo "$got") | sed -n 's/^[<>]/        &/p'
        continue
    fi
    differ=
    while read -r mode f; do
        cmp -s "suckless/$tool/$f" "$tree/$f" || differ+=" $f"
        [[ $mode != 100755 || -x $tree/$f ]] || differ+=" $f(not executable)"
    done < <(git ls-files -s "suckless/$tool" | awk '{ sub("suckless/'"$tool"'/", "", $4); print $1, $4 }')
    if [[ -n $differ ]]; then
        fail "$tool: differs from suckless/$tool:$differ"
    else
        echo "  ok    the result is suckless/$tool, file for file"
    fi
done < <(sed 's/#.*//' patches/upstream | awk 'NF')

if ((status)); then
    echo "FAILED"
else
    echo "patches/ rebuilds every tool"
fi
exit $status
