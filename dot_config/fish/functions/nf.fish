function nf
    set file (fzf --preview 'bat --color=always {}')
    and nvim $file
end
