# Project Instructions

<!-- Keep this file lean. Only add things that are NOT inferrable from reading
     the source code: surprising gotchas, easy-to-make mistakes, external facts,
     local workstation details, and behavioural rules for AI agents. Everything else
     (host configs, services, modules, flake inputs, etc.) lives in the code. -->

# Rules for AI agents
- NEVER assume the default branch is called `main`.
  Check via `git symbolic-ref refs/remotes/origin/HEAD` or `git remote show origin | grep 'HEAD branch'` before targeting it for PRs, rebases, or diffs.
  Use `gh api repos/OWNER/REPO --jq '.default_branch'` when SSH is unavailable.
- When you discover a surprising gotcha, easy-to-make mistake, or non-obvious fact about this project, add it to this file (AGENTS.md) - NOT to private memory.
  This file is the shared knowledge base for the project.
- Keep all git remotes using SSH (e.g. `git@github.com:org/repo.git`), never HTTPS.
  Never add HTTPS remotes as a workaround when SSH fails - ask the user to fix SSH access instead.
  Use `gh api` for read-only GitHub queries (PRs, comments, etc.) when SSH is unavailable.
- Do NOT push to any remote - always ask the user for confirmation first.

# Directory structure
- Always execute nix commands in each subproject's root directory.
- Never modify the nix store.
- Worktrees ALWAYS reside in each subproject's `@worktree`.
  Each worktree has a separate folder e.g. `cardano-api/@worktree/my-feature`.
- **Always create worktrees on a branch**, never detached HEAD.
  Use `git worktree add -b <branch> <path> <start-point>` to create a local branch tracking the remote.
  Never use `git worktree add <path> <remote-ref>` without `-b` - it creates a detached HEAD.

# Tool preferences for code navigation
- **Semantic tools** for references and type info.
  For "find references", "who calls X", "find consumers/producers", or "show me the type of X" queries, prefer semantic tools over grep.
- **Serena** (any language): use `find_referencing_symbols` for reference lookups, `get_symbols_overview` and `find_symbol` for exploring types and signatures without reading whole files.
- **Grep**: reserve for text-level searches - comments, string literals, non-code patterns, or when semantic tools are unavailable.
- Language-specific rules in `.claude/rules/<lang>.md` may add additional navigation tooling (e.g. ctags) on top of the above.
