# Bash init for grov CLI: wrapper + completion
# Add to .bashrc: source /path/to/grov-completion.bash
#
# Wrapper grov(): runs command grov; on success, if we're inside a grov project, cd to root then workspace.

grov() {
  local ret restore_root
  if [[ "$1" == "restore" ]]; then
    restore_root=$(_grov_find_root 2>/dev/null)
  fi
  command grov "$@"
  ret=$?
  if [[ $ret -eq 0 ]]; then
    if [[ -n "$restore_root" && "$1" == "restore" ]]; then
      cd "$restore_root"
    else
      local root
      root=$(_grov_find_root 2>/dev/null)
      if [[ -n "$root" && -e "$root/workspace" ]]; then
        cd "$root" && cd workspace
      fi
    fi
  fi
  return $ret
}

grovc() {
  grov checkout "$@"
}

_grov_find_root() {
  local d="$PWD"
  while [[ -n "$d" && "$d" != "/" ]]; do
    [[ -e "$d/.grov" ]] && echo "$d" && return 0
    d="${d%/*}"
  done
  [[ -n "$GROV_ROOT" && -e "$GROV_ROOT/.grov" ]] && echo "$GROV_ROOT" && return 0
  return 1
}

_grov_list_branches() {
  local root
  root=$(_grov_find_root) || return
  local dir="$root/branches"
  [[ ! -d "$dir" ]] && return
  local d
  for d in "$dir"/*/; do
    [[ -d "$d" ]] && basename "$d"
  done | sort
}

_grov_list_git_branches() {
  local root
  root=$(_grov_find_root) || return
  if [[ -d "$root/.grov/repo.git" ]]; then
    git --git-dir="$root/.grov/repo.git" branch -a 2>/dev/null | sed -e 's/^[* ]*//' -e 's|^remotes/origin/||' -e 's|^remotes/||' | grep -v 'HEAD ' | grep -v '^$' | sort -u
  else
    local primary_dir
    primary_dir=$(cat "$root/.grov/primary-dir" 2>/dev/null) || primary_dir="master"
    local repo="$root/branches/$primary_dir"
    [[ ! -d "$repo/.git" ]] && return
    git -C "$repo" branch -a 2>/dev/null | sed -e 's/^[* ]*//' -e 's|^remotes/origin/||' -e 's|^remotes/||' | grep -v 'HEAD ' | grep -v '^$' | sort -u
  fi
}

_grov_list_scripts() {
  local root
  root=$(_grov_find_root) || return
  local dir="$root/.grov/scripts"
  [[ ! -d "$dir" ]] && return
  local f
  for f in "$dir"/*; do
    [[ -f "$f" && -x "$f" ]] && basename "$f"
  done | sort
}

_grov() {
  local cur prev words cword
  _init_completion -n : 2>/dev/null || _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null
  local commands="init restore checkout status remove path scripts"
  local scripts
  scripts=$(_grov_list_scripts 2>/dev/null)
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
      compopt +o default 2>/dev/null
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      elif [[ $cword -eq 3 && "$prev" == "-b" ]]; then
        COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      else
        COMPREPLY=()
      fi
      ;;
    status) ;;
    scripts) ;;
    remove)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_branches)" -- "$cur"))
      ;;
    path) ;;
    restore) ;;
    *)
      COMPREPLY=()
      ;;
  esac
}

complete -F _grov grov

_grovc() {
  local cur prev words cword
  _init_completion -n : 2>/dev/null || _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null
  words=("grov" "checkout" "${words[@]:1}")
  ((cword++))
  _grov
}
complete -F _grovc grovc
