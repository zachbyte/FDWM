#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies and sed scripts expand later, not here
# The .bashrc prompt: what it shows, its colors, how many git calls it
# makes, and that ~/.local/bin lands on PATH only once however deep shells
# are nested.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
git_sandboxed
theme_repo "$T/theme"
HOME=$T/home bash "$T/theme/fdwm-theme" generate >/dev/null
export HOME=/nonexistent  # so \w shows full paths, never ~

prompt_block=$(sed -n '/^# prompt:/,/^unset -f fdwm_fg$/p' "$ROOT/dotfiles/.bashrc")
eval "$(sed -n '/^parse_git_branch() {/,/^}/p' "$ROOT/dotfiles/.bashrc")"
# without FDWM's colors: no color for the directory, and no error
expect "no colors.sh: no 24-bit color, nothing on stderr" "" \
    "$(unset fdwm_blue; eval "$prompt_block" 2>&1; grep -o '38;2;' <<<"$PS1")"
# with them: the directory in the palette's blue
# shellcheck source=/dev/null
. "$T/home/.config/fdwm/colors.sh"
eval "$prompt_block"
expect_match "the directory is in the palette's blue" \
    "$(printf '38;2;%d;%d;%dm' "0x${fdwm_blue:1:2}" "0x${fdwm_blue:3:2}" "0x${fdwm_blue:5:2}")"'\\\]\\w' "$PS1"

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
