export ZSH=~/.oh-my-zsh
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"
export EDITOR="mvim"

ZSH_THEME="robbyrussell"

plugins=(git virtualenvwrapper autoenv)

if [ -f "${HOME}/.zshrc.local" ]; then
  source "${HOME}/.zshrc.local"
fi

source $ZSH/oh-my-zsh.sh
