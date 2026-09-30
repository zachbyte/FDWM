#!/usr/bin/env bash
# The .bashrc git helpers: pull and discard must never drop or pop a stash
# that isn't theirs.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
git_sandboxed

eval "$(sed -n '/^pull() {/,/^}/p' "$ROOT/dotfiles/.bashrc")"
discard_cmd=$(sed -n "s/^alias discard='\([^']*\)'.*/\1/p" "$ROOT/dotfiles/.bashrc")
expect "discard is defined" "git reset --hard" "$discard_cmd"

# a clone with one stash of its own ("MY STASH"), one commit behind upstream
setup() {
    rm -rf "$T/r" && mkdir "$T/r" && cd "$T/r" || exit 1
    git init -q --bare -b main o.git
    git clone -q o.git w 2>/dev/null && git clone -q o.git up 2>/dev/null
    (cd up && echo 1 >f && git add f && git commit -qm c1 && git push -q 2>/dev/null)
    cd w && git pull -q 2>/dev/null
    echo mine >>f && git stash push -q -m "MY STASH"
    (cd ../up && echo 2 >g && git add g && git commit -qm c2 && git push -q 2>/dev/null)
}
stashes() { git stash list | wc -l | tr -d ' '; }

setup
pull >/dev/null 2>&1
expect "pull, no local changes: your stash is kept" 1 "$(stashes)"
expect "pull, no local changes: tree stays clean" "" "$(git status --porcelain)"
expect "pull, no local changes: upstream arrives" yes "$([[ -f g ]] && echo yes)"

setup
echo local >>f
pull >/dev/null 2>&1
expect "pull with a local edit: edit reapplied" local "$(tail -1 f)"
expect "pull with a local edit: your stash is kept" 1 "$(stashes)"

setup
eval "$discard_cmd" >/dev/null
expect "discard, nothing to discard: your stash is kept" 1 "$(stashes)"

setup
echo local >>f
eval "$discard_cmd" >/dev/null
expect "discard: the edit is gone" "" "$(git status --porcelain)"
expect "discard: your stash is kept" 1 "$(stashes)"

finish
