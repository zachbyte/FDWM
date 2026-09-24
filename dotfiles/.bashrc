# .bashrc

# Fedora's system-wide defaults
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

[[ $- != *i* ]] && return

# parse the branch and transfer it to the prompt
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}

# prompt: pink git branch, blue directory
PS1='\[\e[38;5;204m\]$(if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "$(parse_git_branch) "; fi)\[\e[38;2;137;180;250m\]\w $ \[\e[0m\]'

# essential stuff
stty -ixon # disable ctrl+s and ctrl+q
HISTFILE=~/.bash_history
HISTSIZE=-1
HISTFILESIZE=-1
HISTCONTROL=ignoredups
shopt -s histappend
# write each command to the history file right away and pick up other terminals' commands
PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# essentials
alias cc='claude --dangerously-skip-permissions'
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
alias stash='git stash && git stash drop'
alias status='git status'
alias log='git log'

# env's
export EDITOR='nvim'
export VISUAL='nvim'
export TERMINAL='st'
export BROWSER='firefox'

# stashes changes before pulling and then releases the changes
pull() {
    git stash
    git pull
    git stash pop
}

# commit with a message dynamically
commit() {
    git add .
    git commit -m "$*"
    git push
}

# cloning and cding into that cloned repo
clone() {
    git clone "$1" 2>/dev/null && cd "$(basename "$1" .git)"
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

export PATH="$HOME/.local/bin:$PATH"

# extra snippets in ~/.bashrc.d, as Fedora's default .bashrc loads them
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
