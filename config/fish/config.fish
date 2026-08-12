set -g fish_greeting ""

if status is-interactive
    # Commands to run in interactive sessions can go here
end

function fish_prompt
    set -l last_status $status

    set_color 7fbbb3
    printf '%s' (prompt_pwd)

    if command -q git
        set -l branch (git branch --show-current 2>/dev/null)
        if test -n "$branch"
            set_color 859289
            printf ' @ '
            set_color dbbc7f
            printf '%s' $branch
        end
    end

    printf ' '

    if test $last_status -eq 0
        set_color 83c092
        printf '❯ '
    else
        set_color e67e80
        printf '✗ '
    end

    set_color normal
end

# Everforest eza colors
set -gx EZA_COLORS "di=38;2;131;192;146:fi=38;2;211;198;170:ex=38;2;167;192;128:ln=38;2;127;187;179:or=38;2;230;126;128"

alias gco 'git checkout'
alias ls 'eza --icons --color=always'
alias la 'eza -a --icons --color=always'
alias ll 'eza -a -l --icons --color=always'
alias oc opencode
alias lg lazygit
alias fcf 'nvim ~/.config/fish/config.fish'
alias sf 'source ~/.config/fish/config.fish'

zoxide init fish | source

# >>> Codex installer >>>
export PATH="$HOME/.local/bin:$PATH"
# <<< Codex installer <<<
