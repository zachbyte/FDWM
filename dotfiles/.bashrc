# .bashrc

# Fedora's system-wide defaults
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

[[ $- != *i* ]] && return

# on a Linux console (the ttys), use the same Catppuccin colors as st and
# dwm: \e]P<n><rrggbb> sets palette entry n; 0 is the background and 7 the
# default text, so they get dwm's #1e1e2e and st's #cdd6f4
if [ "$TERM" = linux ]; then
    printf '\e]P01e1e2e\e]P1cba6f7\e]P2a6e3a1\e]P3f9e2af\e]P489b4fa\e]P5f38ba8\e]P694e2d5\e]P7cdd6f4'
    printf '\e]P8585b70\e]P9cba6f7\e]PAa6e3a1\e]PBf9e2af\e]PC89b4fa\e]PDf38ba8\e]PE94e2d5\e]PFa6adc8'
    clear  # repaint the whole screen in the new background
fi

# the current branch and a space, or nothing outside a git repo: one git call
# per prompt (a second only on a detached HEAD, to name the commit)
parse_git_branch() {
    local b
    b=$(git branch --show-current 2>/dev/null) || return 0
    [ -n "$b" ] || b="(HEAD detached at $(git rev-parse --short HEAD 2>/dev/null))"
    printf '%s ' "$b"
}

# prompt: pink git branch, blue directory
PS1='\[\e[38;5;204m\]$(parse_git_branch)\[\e[38;2;137;180;250m\]\w $ \[\e[0m\]'

# essential stuff
stty -ixon # disable ctrl+s and ctrl+q
HISTFILE=~/.bash_history
HISTSIZE=-1
HISTFILESIZE=-1
HISTCONTROL=ignoredups
shopt -s histappend
# write each command to the history file right away and pick up other terminals' commands
# (as the first element of an array, which bash 5.1+ runs in turn, so whatever
# PROMPT_COMMAND already held, string or array, still runs after it)
PROMPT_COMMAND=("history -a; history -n" "${PROMPT_COMMAND[@]}")

# essentials
alias grep='grep --color=auto'
alias c='clear'
alias vim='nvim'
alias mpv='mpv --keep-open'
alias ls='ls -hN --group-directories-first --color=auto'
alias ..='cd ..'

# git based actions
alias checkout='git checkout'
alias push='git push'
alias fetch='git fetch'
alias merge='git merge'
alias add='git add .'
alias discard='git reset --hard' # throw away uncommitted changes to tracked files
alias status='git status'
alias log='git log'

# env's
export EDITOR='nvim'
export VISUAL='nvim'
export NNN_OPTS='e' # nnn opens text files in $EDITOR
export TERMINAL='st'

# pull, setting uncommitted changes aside first and reapplying them after
# (--autostash leaves your own stashes alone, unlike stash + pop)
pull() {
    git pull --autostash "$@"
}

# commit with a message dynamically
commit() {
    git add .
    git commit -m "$*"
    git push
}

# cloning and cding into that cloned repo
clone() {
    git clone "$1" && cd "$(basename "$1" .git)" || return
}

# dynamically delete branches while on the branch you want to delete
branch() {
    if [ "$1" = "-d" ] && [ -n "$2" ]; then
        git checkout main 2>/dev/null || git checkout master 2>/dev/null
        git branch -d "$2"
    else
        git branch "$@"
    fi
}

# rebasing
rebase() {
    if [ "$1" = "--abort" ]; then
        git rebase --abort
        return
    fi
    if [[ "$1" =~ ^[0-9]+$ ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git rebase -i HEAD~"$1"
    fi
}

# ~/.local/bin, added once even when shells are nested (login -> startx -> st)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# extra snippets in ~/.bashrc.d, as Fedora's default .bashrc loads them,
# skipping the .bak.<time> copies install.sh leaves next to files it replaces
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ] && [[ $rc != *.bak.* ]]; then
            # shellcheck source=/dev/null
            . "$rc"
        fi
    done
fi
unset rc
