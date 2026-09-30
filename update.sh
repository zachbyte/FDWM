#!/usr/bin/env bash
# Updates FDWM: pulls the latest commits into this checkout, then runs the new
# install.sh, which installs any missing packages, rebuilds dwm, st and dmenu,
# and reapplies the dotfiles and GRUB theme. It stops before touching
# the repo if you have uncommitted changes or unpushed commits, and it never
# touches your stashes or other branches.
set -Eeuo pipefail  # -E: the ERR trap below also fires inside main()
trap 'echo "update.sh: failed on line $LINENO: $BASH_COMMAND" >&2' ERR

# Everything runs inside main() so bash has read the whole script before
# git reset rewrites this file.
main() {
    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root; it calls sudo where needed." >&2
        exit 1
    fi

    local repo
    repo=$(dirname "$(readlink -f "$0")")
    cd "$repo"

    echo "==> Updating $repo"
    if [[ -n $(git status --porcelain) ]]; then
        echo "You have uncommitted changes in $repo; commit or stash them, then run this again." >&2
        exit 1
    fi
    # Without an upstream the unpushed-commits check below has nothing to
    # compare against and would always pass.
    if ! git rev-parse --verify --quiet '@{upstream}' >/dev/null; then
        echo "This branch has no upstream (or HEAD is detached); check out main, then run this again." >&2
        exit 1
    fi
    if [[ -n $(git log --oneline '@{upstream}..HEAD') ]]; then
        echo "You have commits that aren't pushed yet; push them, then run this again." >&2
        exit 1
    fi
    # reset rather than merge, so a force-pushed upstream still updates cleanly
    git fetch --quiet
    git reset --hard '@{upstream}'

    exec ./install.sh
}

main "$@"
