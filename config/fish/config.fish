set -g fish_greeting ""

if status is-interactive
    # Commands to run in interactive sessions can go here
end

function fish_prompt
    set -l last_status $status

    set_color $VYEOS_PROMPT_PATH
    printf '%s' (prompt_pwd)

    if command -q git
        set -l branch (git branch --show-current 2>/dev/null)
        if test -n "$branch"
            set_color $VYEOS_PROMPT_MUTED
            printf ' @ '
            set_color $VYEOS_PROMPT_GIT
            printf '%s' $branch
        end
    end

    printf ' '

    if test $last_status -eq 0
        set_color $VYEOS_PROMPT_OK
        printf '❯ '
    else
        set_color $VYEOS_PROMPT_ERROR
        printf '✗ '
    end

    set_color normal
end

# Theme colors use universal variables so running Fish sessions receive changes.
for variable in VYEOS_THEME VYEOS_PRIMARY VYEOS_PROMPT_PATH VYEOS_PROMPT_MUTED VYEOS_PROMPT_GIT VYEOS_PROMPT_OK VYEOS_PROMPT_ERROR EZA_COLORS
    set -e -g $variable
end

if test -r "$HOME/.cache/vyeos/theme/fish.fish"
    source "$HOME/.cache/vyeos/theme/fish.fish"
else
    set -Ux VYEOS_PROMPT_PATH 7fbbb3
    set -Ux VYEOS_PROMPT_MUTED 859289
    set -Ux VYEOS_PROMPT_GIT dbbc7f
    set -Ux VYEOS_PROMPT_OK 83c092
    set -Ux VYEOS_PROMPT_ERROR e67e80
end

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

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
