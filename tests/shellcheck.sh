#!/usr/bin/env bash
# ShellCheck every shell script in the repo.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

status=0
check() {
    echo "== shellcheck $*"
    shellcheck -x "$@" || status=1
}

check install.sh update.sh
check dotfiles/.xinitrc grub/60-fdwm-title.install
# sourced by bash, no shebang
check -s bash dotfiles/.bashrc dotfiles/.bash_profile dotfiles/.bashrc.d/claude.sh
check tests/*.sh tests/werror-cc
check suckless/dmenu/dmenu_run suckless/dmenu/dmenu_path

exit $status
