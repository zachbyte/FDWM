#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies and sed scripts expand later, not here
# The .bashrc prompt: what it shows, how many git calls it makes, and that
# ~/.local/bin lands on PATH only once however deep shells are nested.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
git_sandboxed
export HOME=/nonexistent  # so \w shows full paths, never ~

eval "$(sed -n '/^parse_git_branch() {/,/^}/p' "$ROOT/dotfiles/.bashrc")"
eval "$(grep '^PS1=' "$ROOT/dotfiles/.bashrc")"

git init -q -b main "$T/repo"
(cd "$T/repo" && echo a >a && git add a && git commit -qm c1 && echo b >a && git commit -qam c2)
git init -q -b main "$T/unborn"
mkdir "$T/plain"

# the prompt runs git in its own subshell, so count calls in a file
git() { echo x >>"$T/calls"; command git "$@"; }
calls() { wc -l <"$T/calls" | tr -d " "; }
# prompt DIR: the prompt text in DIR with colors stripped
prompt() {
    local p
    : >"$T/calls"
    cd "$1" || exit 1
    p=${PS1@P}
    printf '%s' "$p" | sed 's/\x1b\[[0-9;]*m//g; s/[\x01\x02]//g'
}

out=$(prompt "$T/repo"; echo " #$(calls)")
expect "on a branch: shows it" "main $T/repo \$  #1" "$out"
command git -C "$T/repo" checkout -q --detach HEAD~1
hash=$(command git -C "$T/repo" rev-parse --short HEAD)
out=$(prompt "$T/repo"; echo " #$(calls)")
expect "detached HEAD: names the commit" "(HEAD detached at $hash) $T/repo \$  #2" "$out"
expect "no commits yet: shows the branch" "main $T/unborn \$ " "$(prompt "$T/unborn")"
expect "outside a repo: just the directory" "$T/plain \$ " "$(prompt "$T/plain")"

block=$(sed -n '/^case ":\$PATH:" in/,/^esac/p' "$ROOT/dotfiles/.bashrc")
path=$(PATH=/usr/bin HOME=$T; for _ in 1 2 3; do eval "$block"; done; echo "$PATH")
expect ".local/bin on PATH once after three nested shells" 1 "$(tr ':' '\n' <<<"$path" | grep -c '/\.local/bin$')"

finish
