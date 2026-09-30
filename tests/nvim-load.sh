#!/usr/bin/env bash
# Loads the Neovim config headless, the way a first start on a new machine
# does: lazy.nvim bootstraps itself and installs the plugins lazy-lock.json
# pins, then a second start loads every plugin (the lazy-loaded ones too) and
# fails on any error. Then once more for each flavor fdwm-theme can save, to
# check the colorscheme follows it. Uses its own config and data dirs, not
# yours.
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

# the flavors in the palette's header line
for flavor in $(awk '$1 == "name" { $1 = ""; print; exit }' "$ROOT/palette"); do
    echo "== with $flavor saved by fdwm-theme"
    mkdir -p "$XDG_CONFIG_HOME/fdwm"
    echo "$flavor" >"$XDG_CONFIG_HOME/fdwm/flavor"
    if ! out=$(nvim --headless --cmd "luafile $ROOT/tests/nvim-check.lua" 2>&1); then
        echo "$out"
        exit 1
    fi
    echo "$out"
    grep -qx "colorscheme catppuccin-$flavor" <<<"$out" || {
        echo "the colorscheme isn't catppuccin-$flavor" >&2
        exit 1
    }
done
