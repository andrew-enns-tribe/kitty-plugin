# >>> kitty-plugin integration >>>
# Auto-renames each kitty tab to the current directory's name on every
# prompt. Adds nothing to non-kitty shells. Safe to remove this whole
# block if you uninstall the kitty-plugin.
if [[ "$TERM" == "xterm-kitty" ]]; then
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
  _kitty_set_tab_title() {
    local dir="${PWD##*/}"
    [[ -z "$dir" ]] && dir="~"
    kitten @ set-tab-title "$dir" 2>/dev/null
  }
  precmd_functions+=(_kitty_set_tab_title)
fi
# <<< kitty-plugin integration <<<
