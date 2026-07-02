bindkey -M viins '^Y' yank
bindkey -M viins '^U' kill-whole-line
bindkey "''${key[Up]}" up-line-or-search

# Remove duplicates
typeset -U PATH

export LANG=en_US.UTF-8
unset LC_ALL

export EDITOR=vim
export LESSCHARSET=utf-8
export PAGER='less -R'
# Don't force TERM globally: kitty sets xterm-kitty, tmux sets its own.
[ -n "$TMUX" ] && export TERM=screen-256color

setopt interactivecomments
setopt rm_star_silent

# ----------------------------------------------------------------------------
# use OS time
# ----------------------------------------------------------------------------
disable -r time

# ----------------------------------------------------------------------------
# ssh+tmux
# ----------------------------------------------------------------------------
s() {
    [[ ! -z $1 ]] && ssh -t $@ "tmux -2 attach -t $USER -d || tmux -2 new -s $USER"
}
compdef s=ssh

alias sudo='sudo '

autoreload () {
    pattern=$1
    shift
    watchexec -c -r -e $pattern "$*"
}

bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

export PATH=/run/current-system/sw/bin/:/Users/dlutgehet/.nix-profile/bin/:$PATH

# Performance boost
export ZSH_AUTOSUGGEST_MANUAL_REBIND=1

if hash eza 2>/dev/null; then
    alias ls='eza'
    alias l='eza -l --all --group-directories-first --git'
    alias ll='eza -l --all --all --group-directories-first --git'
    alias lt='eza -T --git-ignore --level=2 --group-directories-first'
    alias llt='eza -lT --git-ignore --level=2 --group-directories-first'
    alias lT='eza -T --git-ignore --level=4 --group-directories-first'
else
    alias l='ls -lah'
    alias ll='ls -alF'
    alias la='ls -A'
fi

alias cgc='git rev-parse HEAD | tr -d '\\\\n' | pbcopy'
alias make_pwd_private='chmod -R go-rwx .'
alias g='git'
alias t='tmux -2 attach -d || tmux -2 new';

# Capslock mapping is handled by nix-darwin (system.keyboard.remapCapsLockToControl);
# running hidutil here slowed down every new shell.

# Launch/connect to tmux if needed (but not inside editor-integrated terminals)
if [[ -z "$TMUX" && "$TERM_PROGRAM" != "vscode" && "$TERM_PROGRAM" != "zed" ]]; then t; fi
