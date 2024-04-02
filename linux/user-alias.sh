#!/bin/bash

echo "
# user Aliases (from [dev-choking])

# alias rm='rm -rf' # can you handle this power?
alias eb='gedit ~/.bashrc' 
alias sb='source ~/.bashrc'
alias agi='sudo apt-get install'  

alias xo='xdg-open'

alias gs='git status'  
alias gp='git pull'
" >> ~/.bashrc

echo "<dev-choking> Added .bashrc aliases"

source ~/.bashrc