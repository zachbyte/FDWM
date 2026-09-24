#!/usr/bin/env bash
# Updates FDWM: installs any missing packages, reclones the repo and rebuilds
# dwm, st and dmenu. It stops before touching the repo if you have
# uncommitted changes or unpushed commits, so nothing of yours is lost.
set -euo pipefail
trap 'echo "update.sh: failed on line $LINENO: $BASH_COMMAND" >&2' ERR

# Everything runs inside main() so bash has read the whole script before the
# reclone replaces the directory this file lives in.
main() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root; it calls sudo where needed." >&2
        exit 1
    fi

    local repo
    repo=$(dirname "$(readlink -f "$0")")
    cd "$repo"

    echo "==> Checking packages"
    local packages missing=() p
    mapfile -t packages < <(sed 's/#.*//' packages.txt | xargs -n1)
    for p in "${packages[@]}"; do
        rpm -q --whatprovides "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if (( ${#missing[@]} )); then
        echo "Installing missing packages: ${missing[*]}"
        sudo dnf install -y "${missing[@]}"
    else
        echo "All installed"
    fi

    echo "==> Recloning $repo"
    if [[ -n $(git status --porcelain) ]]; then
        echo "You have uncommitted changes in $repo; commit or stash them, then run this again." >&2
        exit 1
    fi
    if [[ -n $(git log --oneline '@{upstream}..HEAD' 2>/dev/null) ]]; then
        echo "You have commits that aren't pushed yet; push them, then run this again." >&2
        exit 1
    fi
    local url new
    url=$(git remote get-url origin)
    new=$(mktemp -d "$repo.new.XXXXXX")
    if ! git clone --quiet "$url" "$new"; then
        rm -rf "$new"
        echo "Clone failed; $repo was left as it was." >&2
        exit 1
    fi
    cd /
    rm -rf "$repo"
    mv "$new" "$repo"
    cd "$repo"

    local tool
    for tool in dwm st dmenu; do
        echo "==> Building and installing $tool"
        sudo make -C "suckless/$tool" clean install
    done

    echo "==> Done. Press Alt+Shift+W to restart dwm on the new build."
    echo "    Dotfiles and the GRUB theme aren't touched; run ./install.sh to reapply them."
}

main "$@"
