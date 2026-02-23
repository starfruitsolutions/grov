# Bash init for dev CLI: wrapper + completion
# Add to .bashrc: source /path/to/dev/dev-completion.bash
#
# Wrapper dev(): for "checkout" runs "command dev checkout ... --shell" and evals
# the output (cd + export) on success so the current shell changes directory.
# All other commands run as "command dev ...". Uses "command" to avoid recursion.

dev() {
  local out ret
  case "${1:-}" in
    checkout)
      out="$(command dev "$@" --shell)"
      ret=$?
      if [[ $ret -eq 0 && -n "$out" ]]; then
        eval "$out"
      fi
      return $ret
      ;;
    *)
      command dev "$@"
      ;;
  esac
}

# Optional: devc = dev checkout (same behavior via wrapper)
devc() {
  dev checkout "$@"
}

_dev_find_root() {
  local d="$PWD"
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -e "$d/.dev" ]] && echo "$d" && return 0
    d="${d%/*}"
  done
  [[ -n "$DEV_ROOT" && -e "$DEV_ROOT/.dev" ]] && echo "$DEV_ROOT" && return 0
  return 1
}

_dev_list_branches() {
  local root
  root=$(_dev_find_root) || return
  local dir="$root/branches"
  [[ ! -d "$dir" ]] && return
  local d
  for d in "$dir"/*/; do
    [[ -d "$d" ]] && basename "$d"
  done | sort
}

_dev_list_git_branches() {
  local root repo
  root=$(_dev_find_root) || return
  repo="$root/branches/master"
  [[ ! -d "$repo/.git" ]] && return
  git -C "$repo" branch -a 2>/dev/null | sed -e 's/^[* ]*//' -e 's|^remotes/origin/||' -e 's|^remotes/||' | grep -v 'HEAD ' | sort -u
}

_dev() {
  local cur prev words cword
  _init_completion -n : 2>/dev/null || _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null
  local commands="checkout build status remove path"

  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    return
  fi

  local cmd=${words[1]}
  case "$cmd" in
    checkout)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "-b $(_dev_list_git_branches)" -- "$cur"))
      fi
      ;;
    build)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_dev_list_branches)" -- "$cur"))
      ;;
    status) ;;
    remove)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_dev_list_branches)" -- "$cur"))
      ;;
    path) ;;
    *)
      COMPREPLY=()
      ;;
  esac
}

complete -F _dev dev

_devc() {
  local cur prev words cword
  _init_completion -n : 2>/dev/null || _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null
  words=("dev" "checkout" "${words[@]:1}")
  ((cword++))
  _dev
}
complete -F _devc devc
