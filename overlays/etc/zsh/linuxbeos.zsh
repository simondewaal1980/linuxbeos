# LinuxBeOS ZSH-branding en git-herkenning.
#
# Dit bestand wordt geladen door /etc/zsh/zshrc en door /etc/skel/.zshrc.
# Het bevat bewust geen netwerk-afhankelijke pluginmanager: de prompt moet
# ook offline en in een rescue-omgeving direct werken.

# Voorkom dubbel laden wanneer zowel de systeem- als de gebruikersconfiguratie
# dit bestand sourced.
[[ -n ${LINUXBEOS_ZSH_LOADED:-} ]] && return 0
LINUXBEOS_ZSH_LOADED=1

# Distro-identiteit wordt tijdens de build gegenereerd uit config/project.conf.
[[ -r /etc/linuxbeos/identity.conf ]] && source /etc/linuxbeos/identity.conf
: ${LINUXBEOS_NAME:=LinuxBeOS}
: ${LINUXBEOS_VERSION:=0.1}

autoload -Uz colors && colors
autoload -Uz vcs_info
autoload -Uz add-zsh-hook
autoload -Uz compinit

# Snelle, offline completion met case-insensitive matchen en een keuzemenu.
# De dump wordt in de XDG-cache bewaard, zodat nieuwe shells sneller starten.
typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d "$ZSH_CACHE_DIR" ]] || mkdir -p "$ZSH_CACHE_DIR" 2>/dev/null
if [[ -d "$ZSH_CACHE_DIR" ]]; then
  compinit -u -d "$ZSH_CACHE_DIR/zcompdump"
else
  compinit -u
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/zcompcache"
zstyle ':completion:*' original true

setopt prompt_subst
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt extended_history
setopt share_history
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt interactive_comments
setopt complete_in_word

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=${HISTFILE:-$HOME/.zsh_history}

# vcs_info toont in een git-repository de branch en of er staged/unstaged
# wijzigingen zijn. Buiten een repository blijft de prompt compact.
# Het BeOS-geel markeert de branch; groen/rood markeren de wijzigingen.
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr ' %F{green}%B+%b%f'
zstyle ':vcs_info:git:*' unstagedstr ' %F{red}%B*%b%f'
zstyle ':vcs_info:git:*' formats ' %F{220}git:(%b)%f%u%c'
zstyle ':vcs_info:git:*' actionformats ' %F{220}git:(%b|%a)%f%u%c'

# De prompt wordt in twee regels getekend: identiteit en locatie boven,
# commando-invoer onder. De statusregel toont een groen vinkje of een rode
# kruis met de exitcode, de looptijd van langzame commando's en het aantal
# achtergrondtaken. Zo blijft de prompt informatief zonder een pluginmanager.
typeset -g _linuxbeos_cmd_start=${SECONDS:-0}
typeset -g _linuxbeos_duration_segment=''
typeset -g _linuxbeos_status_segment='%F{green}%B✔%b%f'

_linuxbeos_preexec() {
  _linuxbeos_cmd_start=$SECONDS
}

_linuxbeos_precmd() {
  local last_status=$?
  local elapsed

  elapsed=$(( SECONDS - _linuxbeos_cmd_start ))
  if (( elapsed >= 2 )); then
    _linuxbeos_duration_segment="%F{244}${elapsed}s%f "
  else
    _linuxbeos_duration_segment=''
  fi

  if (( last_status == 0 )); then
    _linuxbeos_status_segment='%F{green}%B✔%b%f'
  else
    _linuxbeos_status_segment="%F{red}%B✘ ${last_status}%b%f"
  fi

  vcs_info
}

_linuxbeos_title() {
  case ${TERM:-} in
    xterm*|rxvt*|screen*|tmux*|alacritty*|kitty*|wezterm*) ;;
    *) return 0 ;;
  esac
  print -Pn "\e]0;${LINUXBEOS_NAME} — %n@%m: %~\a"
}

add-zsh-hook preexec _linuxbeos_preexec
add-zsh-hook precmd _linuxbeos_precmd
add-zsh-hook precmd _linuxbeos_title

# BeOS-gele distronaam, grijze versie, blauw pad en geel/groen/rood voor git.
# De gekleurde statusregel maakt in één oogopslag duidelijk of het laatste
# commando slaagde; de klok rechts komt uit dezelfde BeOS-desktopgedachte als
# de Deskbar, maar blijft bescheiden.
PROMPT='
%F{244}%B╭─%b%f %F{220}%B${LINUXBEOS_NAME}%b%f %F{244}${LINUXBEOS_VERSION}%f %F{240}·%f %F{cyan}%n%F{244}@%f%m %F{240}·%f %F{blue}%~%f${vcs_info_msg_0_}
%F{244}%B╰─%b%f ${_linuxbeos_duration_segment}%(1j.%F{220}⚙ %j%f .)${_linuxbeos_status_segment} %F{220}%B%#%b%f '
RPROMPT='%F{244}%D{%H:%M}%f'
PROMPT2='%F{244}%_>%f '
SPROMPT='%F{220}%Bcorrigeer%b%f %F{red}%R%f %F{244}naar%f %F{green}%r%f? [y/n/e/a] '

alias gs='git status --short --branch'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all -30'
alias gco='git checkout'
alias gb='git branch --sort=-committerdate'
alias gp='git pull --rebase'
alias gc='git commit'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
