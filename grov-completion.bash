# Bash init for grov CLI: wrapper + completion
# Add to .bashrc: source /path/to/grov-completion.bash
#
# Wrapper grov(): checkout and switch only cd to workspace when cwd is already in workspace; restore cds to (former) root.

grov() {
  local ret restore_root project_root in_workspace
  project_root=$(_grov_find_root 2>/dev/null)
  if [[ "$1" == "restore" ]]; then
    restore_root=$project_root
  fi
  if [[ ( "$1" == "checkout" || "$1" == "switch" ) && -n "$project_root" && -L "$project_root/workspace" ]]; then
    local ws_path
    ws_path=$(readlink -f "$project_root/workspace" 2>/dev/null)
    if [[ -n "$ws_path" && "$(readlink -f "$PWD" 2>/dev/null)" == "$ws_path"* ]]; then
      in_workspace=1
    fi
  fi
  command grov "$@"
  ret=$?
  if [[ $ret -eq 0 ]]; then
    if [[ -n "$restore_root" && "$1" == "restore" ]]; then
      cd "$restore_root"
    elif [[ ( "$1" == "checkout" || "$1" == "switch" ) && -n "$in_workspace" && -n "$project_root" && -e "$project_root/workspace" ]]; then
      cd "$project_root" && cd workspace
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

_grov_list_mounts() {
  local root
  root=$(_grov_find_root) || return
  local line name
  while IFS=$'\t' read -r name _ _; do
    [[ -n "$name" ]] && echo "$name"
  done < <(command grov mounts 2>/dev/null)
}

_grov_list_work_targets() {
  _grov_list_mounts
  _grov_list_branches
  _grov_list_git_branches
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

_grov_complete_push() {
  local cur prev words cword
  _init_completion -n : 2>/dev/null || _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null

  if [[ "$prev" == "--from" ]]; then
    COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
    return
  fi

  local i has_yes= has_dry= has_subtree= has_from= has_positional=
  for ((i = 2; i < cword; i++)); do
    case "${words[i]}" in
      --yes) has_yes=1 ;;
      --dry-run) has_dry=1 ;;
      --subtree) has_subtree=1 ;;
      --from)
        has_from=1
        has_subtree=1
        if ((i + 1 < cword)); then ((i++)); fi
        ;;
      --*) ;;
      *) has_positional=1 ;;
    esac
  done

  local opts=""
  [[ -z "$has_yes" ]] && opts+="--yes "
  [[ -z "$has_dry" ]] && opts+="--dry-run "
  if [[ -z "$has_positional" && -z "$has_subtree" ]]; then
    opts+="--subtree --from "
  fi

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "${opts%" "}" -- "$cur"))
    return
  fi

  if [[ -n "$has_subtree" || -n "$has_from" ]]; then
    [[ -n "$opts" ]] && COMPREPLY=($(compgen -W "${opts%" "}" -- "$cur"))
    return
  fi

  if [[ -z "$has_positional" ]]; then
    compopt +o default 2>/dev/null
    local branches reply before after
    branches=$(_grov_list_git_branches)
    if [[ "$cur" == *..* ]]; then
      before="${cur%%..*}"
      after="${cur#*..}"
      reply=($(compgen -W "$branches" -- "$after"))
      COMPREPLY=("${reply[@]/#/${before}..}")
    else
      COMPREPLY=($(compgen -W "$branches" -- "$cur"))
    fi
    return
  fi

  [[ -n "$opts" ]] && COMPREPLY=($(compgen -W "${opts%" "}" -- "$cur"))
}

_grov() {
  local cur prev words cword
  _init_completion -n : 2>/dev/null || _get_comp_words_by_ref -n : cur prev words cword 2>/dev/null
  local commands="init restore checkout switch add status remove restack push mount unmount mounts work merge exec parent base stack interactive root branch branches path scripts run"
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
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
    switch)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_branches)" -- "$cur"))
      ;;
    add)
      compopt +o default 2>/dev/null
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "-b $(_grov_list_git_branches)" -- "$cur"))
      elif [[ $cword -eq 3 && "$prev" == "-b" ]]; then
        COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      else
        COMPREPLY=()
      fi
      ;;
    status) ;;
    restack)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "--continue --abort" -- "$cur"))
      ;;
    push)
      compopt +o default 2>/dev/null
      _grov_complete_push
      ;;
    mount)
      compopt +o default 2>/dev/null
      [[ $cword -eq 3 ]] && COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      ;;
    unmount)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_mounts)" -- "$cur"))
      ;;
    mounts) ;;
    work)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_work_targets)" -- "$cur"))
      ;;
    merge)
      compopt +o default 2>/dev/null
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      elif [[ $cword -eq 3 ]]; then
        COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      fi
      ;;
    exec)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$(_grov_list_branches)" -- "$cur"))
      elif [[ $cword -eq 3 && "$prev" != "--" ]]; then
        COMPREPLY=(--)
      fi
      ;;
    parent)
      case "$prev" in
        parent) COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur")) ;;
        --yes|--no-rebase) COMPREPLY=($(compgen -W "$(_grov_list_git_branches) --yes --no-rebase" -- "$cur")) ;;
        *) COMPREPLY=($(compgen -W "$(_grov_list_git_branches) --yes --no-rebase" -- "$cur")) ;;
      esac
      ;;
    base)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      ;;
    stack)
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "remove doctor" -- "$cur"))
      elif [[ $cword -eq 3 && "${words[2]}" == "remove" ]]; then
        COMPREPLY=($(compgen -W "$(_grov_list_git_branches)" -- "$cur"))
      fi
      ;;
    interactive) ;;
    scripts) ;;
    run)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_scripts)" -- "$cur"))
      ;;
    remove)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_branches)" -- "$cur"))
      ;;
    root) ;;
    branch) ;;
    branches) ;;
    path)
      [[ $cword -eq 2 ]] && COMPREPLY=($(compgen -W "$(_grov_list_branches)" -- "$cur"))
      ;;
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
