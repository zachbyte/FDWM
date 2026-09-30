#!/usr/bin/env bash
# Loads the Neovim config headless, the way a first start on a new machine
# does: lazy.nvim bootstraps itself and installs the plugins lazy-lock.json
# pins, then a second start loads every plugin (the lazy-loaded ones too) and
# fails on any error. Uses its own config and data dirs, not yours.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if ! nvim --clean --headless +'if !has("nvim-0.12") | cquit | endif' +qa; then
    echo "The config needs Neovim 0.12 or newer; this is $(nvim --version | head -1)" >&2
    exit 1
fi

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export XDG_CONFIG_HOME=$T/config XDG_DATA_HOME=$T/data XDG_STATE_HOME=$T/state XDG_CACHE_HOME=$T/cache
mkdir -p "$XDG_CONFIG_HOME"
cp -r "$ROOT/dotfiles/.config/nvim" "$XDG_CONFIG_HOME/"

echo "== first start: install the pinned plugins"
nvim --headless '+Lazy! restore' +qa

echo "== second start: load everything"
nvim --headless --cmd "luafile $ROOT/tests/nvim-check.lua"
