# Bash init for dev CLI: wrapper + completion
# Add to .bashrc: source /path/to/dev-completion.bash
#
# Wrapper dev(): runs command dev; on success, if we're inside a dev project, cd to root then workspace.

dev() {
  local ret
  command dev "$@"
  ret=$?
  if [[ $ret -eq 0 ]]; then
    local root
    root=$(_dev_find_root 2>/dev/null)
    if [[ -n "$root" && -e "$root/workspace" ]]; then
      cd "$root" && cd workspace
    fi
  fi
  return $ret
}

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
  local root
  root=$(_dev_find_root) || return
  if [[ -d "$root/.dev/repo.git" ]]; then
    git --git-dir="$root/.dev/repo.git" branch -a 2>/dev/null | sed -e 's/^[* ]*//' -e 's|^remotes/origin/||' -e 's|^remotes/||' | grep -v 'HEAD ' | sort -u
  else
    local repo="$root/branches/master"
    [[ ! -d "$repo/.git" ]] && return
    git -C "$repo" branch -a 2>/dev/null | sed -e 's/^[* ]*//' -e 's|^remotes/origin/||' -e 's|^remotes/||' | grep -v 'HEAD ' | sort -u
  fi
}

_dev_list_scripts() {
  local root
  root=$(_dev_find_root) || return
  local dir="$root/.dev/scripts"
  [[ ! -d "$dir" ]] && return
  local f
  for f in "$dir"/*; do
    [[ -f "$f" && -x "$f" ]] && basename "$f"
  done | sort
}

_dev() {
  local cur prev words cword
  _init_completion -n : 2>/dev/null || _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null
  local commands="init checkout build status remove path"
  local scripts
  scripts=$(_dev_list_scripts 2>/dev/null)
  local all_commands
  all_commands=$(echo "$commands $scripts" | tr ' \n' ' ')
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$all_commands" -- "$cur"))
    return
  fi
  local cmd=${words[1]}
  case "$cmd" in
    init) ;;
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
