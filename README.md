# grov

A bash CLI for working in **git worktrees** with a stable `workspace/` mount, optional extra mounts, and lightweight **stacked-branch** metadata. One repo, many branches checked out at once, easy switching, and a sane mental model for stacks on top of plain git.

## Why

Switching branches with `git checkout` blows away your working tree and IDE state. Worktrees fix that, but managing a bunch of them by hand is annoying. `grov` lays out a project so:

- The bare repo lives at `.grov/repo.git`
- Every branch you touch becomes a worktree under `branches/<name>/`
- A required **`workspace`** mount points at your primary dev tree (IDE-friendly)
- Optional **named mounts** (e.g. `dock/`) point at other worktrees without moving `workspace`
- Stack relationships live in `.grov/stack.json` and drive `restack`, `push`, `pull`, and `status`

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
cd workspace              # primary dev tree
# ...edit, git add, git commit...
grov push --all           # push every pushable branch (no prompt)
```

## Mounts vs work vs checkout

| Goal | Command |
|------|---------|
| Live dev on branch A | `workspace` mount (`grov checkout A` moves it) |
| Second tree in IDE/files | `grov mount dock B` then open `dock/` |
| Terminal git session on B without moving workspace | `grov work B` (subshell; `exit` when done) |
| One-shot merge into linked branch | `grov merge other-branch` |

- **`checkout` / `switch`** — repoint only the **`workspace`** mount.
- **`mount` / `unmount`** — add or remove optional symlinks; `workspace` cannot be unmounted.
- **`work`** — ephemeral shell in a worktree; does not change any mount.

## Bulk scopes (`push`, `pull`, `restack`, `remove`)

Shared targeting rules:

| Invocation | `push` / `pull` / `restack` | `remove` |
|------------|---------------------------|----------|
| *(no branch)* | All pushable / all pullable / all stack rebases; **prompt** | *(not allowed)* |
| `--all` or `--yes` | Same scope; **no prompt** | `--yes` only (no `--all`) |
| `<branch>` | **That branch only** | **That branch only** (fails if stack children) |
| `<branch> --cascade` | Branch + stack **descendants** (parent-before-child) | Branch + descendants (**leaves first**) |
| `<from>..<to>` | Stack chain (from exclusive → to inclusive) | Same chain (**leaves first**) |
| `--cascade` *(no branch)* | Descendants from **workspace** mount branch | — |

Examples:

```bash
grov push interface-improvements --cascade    # push subtree
grov push interface-improvements              # push only that branch
grov pull stacked-diffs..interactive-interface
grov restack stacked-diffs..interactive-interface
grov remove interface-improvements --cascade  # tear down subtree
```

`--continue` / `--abort` on `restack` apply to an in-progress rebase only.

## Commands

| Command | What it does |
|---|---|
| `init` | Convert current git repo into the grov layout (bare at `.grov/repo.git`) |
| `checkout [-b] <branch>` | Ensure worktree exists, repoint **`workspace`** mount |
| `switch <branch>` | Repoint **`workspace`** mount only |
| `add [-b] <branch>` | Create a worktree without changing mounts |
| `status` | Worktrees, stack tree, mounts, git state |
| `remove [--yes] <branch>\|<a>..<b> [--cascade]` | Remove worktree(s); blocks **workspace** mount |
| `restack [--all] [--yes] [--continue\|--abort] [[branch\|<a>..<b>] [--cascade]]` | Rebase onto parents |
| `push [--all] [--yes] [--dry-run] [[branch\|<a>..<b>] [--cascade]]` | Push with `--force-with-lease` |
| `pull [--all] [--yes] [--dry-run] [[branch\|<a>..<b>] [--cascade]]` | `git pull` from upstream (parent-before-child) |
| `parent <child> [parent] [--yes] [--no-rebase]` | Add/move a branch in the stack |
| `base [<branch>]` | Show or set the global base (trunk) branch |
| `stack remove <branch>` | Same as `grov remove` (supports cascade/range) |
| `stack doctor` | Validate `stack.json` vs actual worktrees |
| `mount <name> <branch>` | Add optional mount symlink at repo root |
| `unmount <name>` | Remove optional mount (`workspace` is required) |
| `mounts` | List all mounts |
| `work [<target>]` | Subshell in a worktree (branch, folder, or mount name) |
| `merge [<branch-a>] [<branch-b>]` | Merge branch-a into branch-b (default target: workspace) |
| `exec <branch> -- <cmd...>` | Run any command in a branch worktree (no mount change) |
| `root` / `branch` / `branches` / `path [branch]` | Introspection helpers |
| `scripts` / `run <name> [args...]` | List and run custom scripts in `.grov/scripts/` |

## Interactive TUI

```bash
grov interactive          # or: grov-interactive
```

A curses dashboard showing all worktrees, the stack tree, dirty/ahead/behind state, and mounts. All mutations shell out to `grov` so behavior stays identical to the CLI.

## Layout

```
your-project/
├── .grov/
│   ├── repo.git/         # bare repository
│   ├── stack.json        # stacked-branch metadata
│   ├── mounts.json       # mount name -> worktree folder
│   └── scripts/          # optional user scripts: grov run <name>
├── branches/
│   ├── main/             # worktree
│   ├── feature-a/
│   └── feature-b/
├── workspace -> branches/feature-a   # required mount (live dev)
└── dock -> branches/feature-b        # optional mount
```

## Requirements

- bash
- git with worktree support
- python3 (used for `stack.json`, `mounts.json`, and the interactive TUI)

## License

MIT
