---
name: changelog
description: Write a herald changelog fragment for the current branch's changes.
argument-hint: "[project] [description]"
---

Write a herald changelog fragment for the current branch.

Arguments: $ARGUMENTS

## Procedure

### 1. Find the herald config

Look for `.herald.yml` in the repo root of the subproject the user is working in.
Read it to discover:
- Available **projects** and their cabal files
- Available **kinds** and their PVP bump levels

If no `.herald.yml` exists, tell the user and stop.

### 2. Determine the project

If the user specified a project, use it. Otherwise infer from the changed files:
```bash
git diff --name-only HEAD~1  # or appropriate range
```
Match changed paths against the `projects:` entries in `.herald.yml`.
If ambiguous, ask the user.

### 3. Determine the PR number

Try to discover an existing PR for the current branch on the origin remote:
```bash
BRANCH=$(git branch --show-current)
REMOTE_REPO=$(gh api repos --jq '.full_name' 2>/dev/null || git remote get-url origin | sed 's|.*github.com[:/]||;s|\.git$||')
gh pr list --head "$BRANCH" --repo "$REMOTE_REPO" --json number --jq '.[0].number' 2>/dev/null
```

If no PR is found, ask the user for the PR number.

### 4. Determine the change kind

Read the PVP specification to understand version bump semantics:
```
WebFetch https://pvp.haskell.org/
```

Analyse the branch diff to classify the change:
- **breaking** (bumps A.B): removed or renamed public API, changed types of public functions, narrowed type class constraints, bumped a publicly re-exported dependency's major version
- **feature** (bumps A.B.C): new public functions/types/modules, new type class instances
- **compatible** (bumps A.B.C): widened dependency bounds, added optional parameters, new re-exports that don't clash
- **bugfix** (bumps A.B.C.D): fixed incorrect behaviour without API change
- **optimisation** (bumps A.B.C.D): measurable performance improvement
- **refactoring** (bumps A.B.C.D): internal code changes, no API change
- **test** (bumps A.B.C.D): test additions or fixes
- **documentation** (bumps A.B.C.D): haddock or doc changes only
- **maintenance** (bumps A.B.C.D): CI, build system, dependency pins that don't affect public API
- **release** (bumps A.B.C.D): release preparation

Key PVP rules for dependency bumps:
- Bumping a dependency's **major version** (A.B) when that dependency's types appear in the public API is a **breaking** change, because consumers pinning the old version will fail to build.
- Bumping a dependency's **minor or patch version** is typically **maintenance** or **compatible**.
- If the dependency is internal-only (not re-exported), the bump is **maintenance**.

If unsure, present the options with the PVP reasoning and ask the user.

### 5. Write the description

Write a concise single-line description. If the change involves dependency bumps, mention the old and new versions and link relevant release notes.

Never wrap the description text across multiple lines. Keep it on a single line after `description: |`.

### 6. Write the fragment file

File naming convention: `YYYYMMDD_<project>_<short_slug>.yml`
- Date is today's date
- Project and slug use underscores
- Place in the `changes-dir` from `.herald.yml` (usually `.changes/`)

Fragment format:
```yaml
project: <project-name>
pr: <number>
kind:
  - <kind>
description: |
  <single line description>
```

### 7. Report

Show the user the fragment content and file path.

## Important rules
- Always read `.herald.yml` first to get the valid projects and kinds for this repo.
- Always read PVP (https://pvp.haskell.org/) when deciding the change kind for dependency bumps or API changes.
- Classify against the last released version, not the previous commit.
  Changes to API that has never been released, and changes to `Internal.*` modules, are NOT breaking - use refactoring/compatible instead.
- Never wrap description text across multiple lines.
- Never guess the PR number - discover it from the remote or ask.
- The `kind:` field is a YAML list even for a single kind.
- Files starting with `_` are ignored by herald.
