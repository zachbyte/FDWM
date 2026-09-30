#!/usr/bin/env bash
# update.sh against a local bare repo standing in for GitHub, with a stub
# install.sh: what it updates, what it refuses to touch, what it keeps.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
git_sandboxed

# origin (bare), seed (where "upstream" commits are made), w (the checkout
# update.sh runs in)
git init -q --bare -b main "$T/o.git"
git clone -q "$T/o.git" "$T/seed" 2>/dev/null
cp "$ROOT/update.sh" "$T/seed/"
printf '#!/bin/sh\necho INSTALL RAN\n' >"$T/seed/install.sh"
chmod +x "$T/seed/update.sh" "$T/seed/install.sh"
git -C "$T/seed" add . && git -C "$T/seed" commit -qm init
git -C "$T/seed" push -q origin main 2>/dev/null
git clone -q "$T/o.git" "$T/w" 2>/dev/null

run() { out=$(cd "$T/w" && ./update.sh 2>&1); rc=$?; }

run
expect "up to date: exits 0" 0 "$rc"
expect_match "up to date: runs install.sh" "INSTALL RAN" "$out"

(cd "$T/seed" && echo a >a.txt && git add a.txt && git commit -qm "new upstream" && git push -q 2>/dev/null)
run
expect "new upstream commit: checkout moves to it" "$(git -C "$T/seed" rev-parse HEAD)" "$(git -C "$T/w" rev-parse HEAD)"
expect "new upstream commit: its file arrives" yes "$([[ -f $T/w/a.txt ]] && echo yes)"

echo x >>"$T/w/a.txt"
run
expect_match "uncommitted change: refuses" "uncommitted changes" "$out"
expect_no_match "uncommitted change: install.sh not run" "INSTALL RAN" "$out"
git -C "$T/w" checkout -q a.txt

(cd "$T/w" && echo y >b.txt && git add b.txt && git commit -qm local)
run
expect_match "unpushed commit: refuses" "aren't pushed" "$out"
git -C "$T/w" reset -q --hard '@{upstream}'

git -C "$T/w" checkout -qb feature
(cd "$T/w" && echo f >f.txt && git add f.txt && git commit -qm feature)
run
expect_match "branch with no upstream: refuses" "no upstream" "$out"
expect "branch with no upstream: branch kept" feature "$(git -C "$T/w" branch --list feature --format='%(refname:short)')"

git -C "$T/w" checkout -q --detach main
run
expect_match "detached HEAD: refuses" "no upstream" "$out"
git -C "$T/w" checkout -q main

# a stash and another local branch must survive an update, even over a
# force-pushed upstream
(cd "$T/w" && echo s >>a.txt && git stash -q)
(cd "$T/seed" && git commit -q --amend -m "rewritten upstream" && git push -q -f 2>/dev/null)
run
expect "force-pushed upstream: exits 0" 0 "$rc"
expect "force-pushed upstream: checkout follows it" "rewritten upstream" "$(git -C "$T/w" log -1 --format=%s)"
expect "force-pushed upstream: stash kept" 1 "$(git -C "$T/w" stash list | wc -l | tr -d ' ')"
expect "force-pushed upstream: other branch kept" feature "$(git -C "$T/w" branch --list feature --format='%(refname:short)')"

mv "$T/o.git" "$T/gone.git"
run
expect "fetch fails: exits non-zero" yes "$([[ $rc -ne 0 ]] && echo yes)"
expect_match "fetch fails: ERR trap names the line" "update.sh: failed on line [0-9]+: git fetch" "$out"

finish
