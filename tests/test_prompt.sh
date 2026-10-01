#!/usr/bin/env bash
# shellcheck disable=SC2016  # stub bodies and sed scripts expand later, not here
# shellcheck disable=SC2154  # fdwm_* come from the generated colors.sh
# The .bashrc prompt: what it shows, its colors (the flavor's prompt_branch
# and prompt_dir), that a shell already open follows fdwm-theme from its
# next prompt, how many git calls it makes, and that ~/.local/bin lands on
# PATH only once however deep shells are nested.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
git_sandboxed
theme_repo "$T/theme"
export XDG_CONFIG_HOME=$T/home/.config
# gen FLAVOR: colors.sh in FLAVOR, as fdwm-theme writes it
gen() {
    mkdir -p "$XDG_CONFIG_HOME/fdwm"
    echo "$1" >"$XDG_CONFIG_HOME/fdwm/flavor"
    bash "$T/theme/fdwm-theme" generate >/dev/null
}
export HOME=/nonexistent  # so \w shows full paths, never ~

prompt_block=$(sed -n '/^# prompt:/,/^fdwm_prompt$/p' "$ROOT/dotfiles/.bashrc")
eval "$(sed -n '/^parse_git_branch() {/,/^}/p' "$ROOT/dotfiles/.bashrc")"
# without FDWM's colors: no colors, and no error
expect "no colors.sh: no colors, nothing on stderr" "" \
    "$(eval "$prompt_block" 2>&1; grep -o '38;' <<<"$PS1")"
# with them: the branch and the directory in the flavor's prompt colors
rgb() { printf '38;2;%d;%d;%dm' "0x${1:1:2}" "0x${1:3:2}" "0x${1:5:2}"; }
# colors FLAVOR: that the prompt has FLAVOR's colors
colors() {
    # shellcheck source=/dev/null
    . "$XDG_CONFIG_HOME/fdwm/colors.sh"
    expect_match "$1: the branch in its prompt_branch" "^\\\\\\[\\\\e\\[$(rgb "$fdwm_prompt_branch")"'\\\]\$\(parse_git_branch\)' "$PS1"
    expect_match "$1: the directory in its prompt_dir" "$(rgb "$fdwm_prompt_dir")"'\\\]\\w' "$PS1"
}
gen mocha
eval "$prompt_block"
colors mocha
expect_no_match "no other colors (such as the 256-color pink it had)" '38;5;' "$PS1"
mocha_ps1=$PS1
# a switch while the shell is open: the next prompt (PROMPT_COMMAND runs
# fdwm_prompt first) has the new colors
gen thinkpad
fdwm_prompt
colors "switched to thinkpad, same shell"
expect "switched to thinkpad, same shell: not mocha's prompt" yes "$([[ $PS1 != "$mocha_ps1" ]] && echo yes)"
expect "PROMPT_COMMAND runs fdwm_prompt first" 1 \
    "$(grep -c '^PROMPT_COMMAND=(fdwm_prompt ' "$ROOT/dotfiles/.bashrc")"

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
