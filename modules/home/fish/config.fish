set fish_greeting ""

# Load matugen colors if available
if test -f ~/.cache/matugen/colors.fish
    source ~/.cache/matugen/colors.fish
end

starship init fish | source

set -Ux PATH $HOME/.local/bin $PATH

function mark_prompt_start --on-event fish_prompt
    echo -en "\e]133;A\e\\"
end

function y
    # Yazi file manager with directory change
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    command yazi $argv --cwd-file="$tmp"
    if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
        builtin cd -- "$cwd"
    end
    command rm -f -- "$tmp"
end