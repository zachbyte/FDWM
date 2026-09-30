#!/usr/bin/env bash
# ~/.bashrc.d: install.sh installs claude.sh there (backing up an edited
# copy next to it), and .bashrc loads it but skips those backups.
# shellcheck source=tests/lib.sh
source "$(dirname "$0")/lib.sh"
sandbox
export HOME=$T/home
mkdir -p "$HOME" "$T/repo"
cp -r "$ROOT/dotfiles" "$T/repo/"
cd "$T/repo" || exit 1
eval "$(sed -n '/^install_dotfile() {/,/^}/p' "$ROOT/install.sh")"

out=$(install_dotfile .bashrc; install_dotfile .bashrc.d/claude.sh)
expect_match "first install: creates ~/.bashrc.d/claude.sh" "Installed ~/.bashrc.d/claude.sh" "$out"
expect_match "second install: leaves it alone" "is up to date" "$(install_dotfile .bashrc.d/claude.sh)"

echo "alias mine=true" >"$HOME/.bashrc.d/mine.sh"
echo "# your edit" >>"$HOME/.bashrc.d/claude.sh"
out=$(install_dotfile .bashrc.d/claude.sh)
expect_match "after your edit: backs it up" "Moved your old ~/.bashrc.d/claude.sh" "$out"
backups=("$HOME"/.bashrc.d/claude.sh.bak.*)
backup=${backups[0]}
expect "your other snippets are untouched" "alias mine=true" "$(cat "$HOME/.bashrc.d/mine.sh")"

# a stale alias in the backup must not win over the installed file
echo "alias cl='STALE BACKUP'" >>"$backup"
aliases=$(bash -i -c 'alias cl; alias mine; alias cc' 2>/dev/null)
expect_match "cl comes from claude.sh, not the backup" "^alias cl='claude --dangerously-skip-permissions'$" "$aliases"
expect_match "your own snippet loads" "^alias mine='true'$" "$aliases"
expect_no_match "cc is not aliased" "^alias cc=" "$aliases"

finish
