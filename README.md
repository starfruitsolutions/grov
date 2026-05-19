# grov

A bash CLI for working in **git worktrees** with a stable `workspace/` symlink and lightweight **stacked-branch** metadata. One repo, many branches checked out at once, easy switching, and a sane mental model for stacks on top of plain git.

## Why

Switching branches with `git checkout` blows away your working tree and IDE state. Worktrees fix that, but managing a bunch of them by hand is annoying. `grov` lays out a project so:

- The bare repo lives at `.grov/repo.git`
- Every branch you touch becomes a worktree under `branches/<name>/`
- A `workspace` symlink always points at the branch you're currently working on — open your editor on `workspace/` once and forget about it
- Stack relationships (which branch is on top of which) live in `.grov/stack.json` and drive `restack`, `push`, and `status`

## Install

```bash
git clone <this repo> grov
cd grov
./install                 # copies grov, grov-interactive, completion into ~/.local/bin
```

The installer offers to add `~/.local/bin` to your `PATH` and source the bash completion from `~/.bashrc`.

## Quick start

```bash
cd path/to/your/git/repo
grov init                 # convert existing repo into the grov layout
grov checkout -b feature  # create branch, worktree, point workspace at it
cd workspace              # always your current branch
# ...edit, commit...
grov push                 # push subtree of stacked branches with --force-with-lease
```

## Commands

| Command | What it does |
|---|---|
| `init` | Convert current git repo into the grov layout (bare at `.grov/repo.git`) |
| `checkout [-b] <branch>` | Ensure worktree exists, point `workspace` at it |
| `switch <branch>` | Just repoint `workspace` at an existing worktree |
| `add [-b] <branch>` | Create a worktree without changing the link |
| `status` | Worktrees, stack tree, linked branch, git state |
| `remove <branch>` | Remove a worktree (stack leaf only if branch is in a stack) |
| `restack [--continue\|--abort]` | Rebase stacked branches onto their parents in order |
| `push [--yes] [--dry-run] [--from <b>]` | Push linked branch subtree with `--force-with-lease` |
| `parent <child> [parent] [--yes] [--no-rebase]` | Add/move a branch in the stack |
| `base [<branch>]` | Show or set the global base (trunk) branch |
| `stack remove <branch>` | Remove leaf from stack metadata + worktree |
| `stack doctor` | Validate `stack.json` vs actual worktrees |
| `root` / `branch` / `branches` / `path [branch]` | Introspection helpers |
| `scripts` / `run <name> [args...]` | List and run custom scripts in `.grov/scripts/` |

## Interactive TUI

```bash
grov interactive          # or: grov-interactive
```

A curses dashboard showing all worktrees, the stack tree, dirty/ahead/behind state, and the linked branch. All mutations shell out to `grov` so behavior stays identical to the CLI.

## Layout

```
your-project/
├── .grov/
│   ├── repo.git/         # bare repository
│   ├── stack.json        # stacked-branch metadata
│   └── scripts/          # optional user scripts: grov run <name>
├── branches/
│   ├── main/             # worktree
│   ├── feature-a/
│   └── feature-b/
└── workspace -> branches/feature-a   # always points at active branch
```

## Requirements

- bash
- git with worktree support
- python3 (used for `stack.json` reads/writes and the interactive TUI)

## License

MIT
