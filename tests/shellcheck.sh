#!/usr/bin/env bash
# ShellCheck every shell script in the repo.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

status=0
check() {
    echo "== shellcheck $*"
    shellcheck -x "$@" || status=1
}

check install.sh update.sh fdwm-theme
check dotfiles/.xinitrc dotfiles/.local/bin/* grub/60-fdwm-title.install
# sourced by bash, no shebang
check -s bash dotfiles/.bashrc dotfiles/.bash_profile dotfiles/.bashrc.d/claude.sh
check tests/*.sh tests/werror-cc
# upstream dmenu, unchanged: dmenu_path splits $PATH on purpose (IFS=:)
check suckless/dmenu/dmenu_run
check -e SC2086 suckless/dmenu/dmenu_path

exit $status
