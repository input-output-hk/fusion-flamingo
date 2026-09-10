---
name: release-to-chap
description: Release a package version to CHaP (cardano-haskell-packages) from a source-repo release PR or a git ref, open the CHaP PR, and link it back.
argument-hint: <release-pr-url-or-number> | <repo> <git-ref>
---

Release one or more packages to [CHaP](https://github.com/IntersectMBO/cardano-haskell-packages) using the local checkout at `/work/cardano-haskell-packages`.

Arguments: $ARGUMENTS

## Inputs

The skill accepts either:

- **A release PR** in the source repo - a URL (`https://github.com/IntersectMBO/cardano-api/pull/1234`), or a bare number plus the repo.
  The release commit is the PR's head commit; the CHaP PR link is posted back as a comment on this PR at the end.
- **A git ref** - a commit sha, tag, or branch in the source repo, with no source PR to link back to.
  Resolve it to a full 40-char sha before use.

If the input is ambiguous (bare number, no repo), ask which source repo it belongs to.

## Procedure

### 1. Resolve the release ref - ALWAYS PIN THE TAG

**The release is always pinned at the release TAG, never at the PR head commit.**
**But the rev handed to the script is the tag's resolved COMMIT SHA, never the tag name** - `rev` in `meta.toml`
must be an immutable sha, since a tag can be moved or deleted.
So: find the tag, resolve it to a sha, pass the sha.

For a release PR:

```bash
gh pr view <pr> --repo <owner>/<repo> --json headRefOid,headRefName,url,state,title
```

The head branch is normally `release/<pkg>-<version>`; the matching tag is `<pkg>-<version>`.
Confirm the tag exists and see where it points:

```bash
gh api repos/<owner>/<repo>/git/matching-refs/tags/<pkg>-<version> \
  --jq '.[] | "\(.ref)\t\(.object.sha)"'
```

If no such tag exists yet, **stop and ask** - the release tag has to be pushed before CHaP can pin it.

Compare the tag against the PR head and report any gap, because they routinely differ
(a release PR usually carries a trailing "Add release changelog fragment" commit that the tag predates):

```bash
gh api repos/<owner>/<repo>/compare/<tag-sha>...<headRefOid> \
  --jq '{status:.status, ahead:.ahead_by, behind:.behind_by, commits:[.commits[].commit.message|split("\n")[0]]}'
```

Show the user what the tag excludes and carry on with the tag - only stop if the PR head is *behind* the tag,
which means the tag points at something that is not in this PR.

Warn (do not block) if the PR is not merged.

For a bare git ref input: if it is already a tag, use it as-is.
If the user gives a sha or branch, find the tag pointing at it and use that instead;
ask before proceeding if there is no such tag.

### 2. Determine packages and subdirs

List the cabal files at that exact commit:

```bash
gh api "repos/<owner>/<repo>/git/trees/<sha>?recursive=1" \
  --jq '.tree[] | select(.path | endswith(".cabal")) | .path'
```

Map each cabal file's directory to a subdir argument (a cabal file at the repo root means "no subdirs").
Read each candidate's `version:` field to know the version that will be released:

```bash
gh api "repos/<owner>/<repo>/contents/<path>?ref=<sha>" --jq .content | base64 -d | grep -iE '^(name|version):'
```

Present the detected packages and versions and **ask the user which ones to release** unless they already said.
A release often covers several subdirs at once (e.g. `cardano-api cardano-api-gen`) - one `add-from-github.sh` invocation handles them all and makes one commit per package.

Pick the **primary package** (the first one the user names, or the one matching the repo name) - its name and version form the branch name.

### 3. Prepare the CHaP branch

```bash
git -C /work/cardano-haskell-packages status --short
```

Stop and ask if the tree is dirty - never stash or discard the user's work.

```bash
cd /work/cardano-haskell-packages \
  && git fetch origin \
  && git checkout main \
  && git reset --hard origin/main
```

The CHaP default branch is `main` (not `master`); confirm with `git symbolic-ref refs/remotes/origin/HEAD` if in doubt.

**CHaP `main` moves fast - several merges an hour.**
`git fetch origin` immediately before branching is mandatory, never branch off a stale local `main`,
and **re-check right before step 6** (and again whenever the user takes a while over step 5):

```bash
git fetch origin && git rev-list --count HEAD..origin/main
```

Any non-zero count means the branch is out of date and the PR would open behind `main`.
Rebase before going further:

```bash
GIT_AUTHOR_NAME="Mateusz Galazyn" GIT_COMMITTER_NAME="Mateusz Galazyn" \
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false \
  git rebase origin/main
```

A rebase drops the user's signature, so it always sends them back to step 5 to re-sign and force-push.
Check timestamp monotonicity first - compare the branch's `timestamp` against the newest one on `origin/main`
(`git show origin/main --name-only --format= | grep meta.toml`, then `git show origin/main:<path>`).
If ours is older, the CI `check` job fails and the fix is `./scripts/update-timestamps-and-fixup.sh <rev>`
followed by `git rebase main --autosquash`.

Create the release branch, named `mgalazyn/<primary-pkg>-<version>` (e.g. `mgalazyn/cardano-api-10.19.0.0`):

```bash
git -C /work/cardano-haskell-packages checkout -b "mgalazyn/<pkg>-<version>"
```

The prefix is literally `mgalazyn` - it matches the existing CHaP branches, and does NOT match this machine's `gh` login (`carbolymer`), so never derive it from `gh api user`.

If the branch already exists, stop and ask - it may be an earlier attempt at the same release.

### 4. Run the CHaP release script

```bash
cd /work/cardano-haskell-packages \
  && GIT_AUTHOR_NAME="Mateusz Galazyn" GIT_COMMITTER_NAME="Mateusz Galazyn" \
     GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false \
     ./scripts/add-from-github.sh https://github.com/<owner>/<repo> <tag> [<subdir>...]
```

Both env prefixes are required in this environment and neither may be persisted into git config:

- `user.name` is **unset** globally and in the CHaP checkout (only `user.email` is set), so the script's
  internal `git commit` dies with `empty ident name` and leaves `meta.toml` written-and-staged but uncommitted.
- `commit.gpgsign` is `true` and the script commits without `--no-gpg-sign`; the commits get signed for real in step 5.

Set both prefixes on the FIRST invocation - a failed internal commit leaves `meta.toml` written and staged,
and there is no clean way forward from that state that does not involve touching the generated file.

`meta.toml` is the script's file, start to finish.
Never hand-write it, never hand-commit it, never delete or edit it to retry.
If the script fails for any reason, reset the whole branch (`git reset --hard origin/main`) and run the
script again from a clean tree.

Facts about the script:

- The URL **must** be `https://github.com/...` - it rejects `git@github.com:` SSH URLs.
- The rev argument is the release tag's **resolved commit sha** (step 1), and lands in `meta.toml` as `rev = "<sha>"`.
  Never pass the tag name - the script accepts it and writes it verbatim, producing a mutable pin.
- It writes `_sources/<pkg>/<version>/meta.toml` and **commits it itself, ONE commit per invocation** -
  `Added <pkg>-<version>` for a single package, or `Added packages from <repo>` with a bulleted list for several.
  It is not one commit per package.
- It **skips with a warning** (does not fail) if a `meta.toml` already exists for that package version - check the
  output for skips and report them; a fully-skipped run means nothing to release, and it then aborts on the
  "all subdirs produced a package" assertion with no output of its own.
- `Error: A placeholder already exists for <pkg>` is **benign** - the script only creates a Hackage candidate
  placeholder for packages entirely new to CHaP, and shrugs off the collision.
  If the run ends with `**** New Hackage candidates were created ****`, relay its
  `hackage-candidates/upload-placeholders.sh ...` instruction to the user verbatim.
- `-f <version>` force-overrides the version, and is only valid with exactly one subdir.
- All packages in one invocation share one timestamp.

Verify the result before going further:

```bash
git -C /work/cardano-haskell-packages log --oneline --name-status origin/main..HEAD
```

Every commit must add exactly one `_sources/<pkg>/<version>/meta.toml` and touch nothing else.

### 5. Hand signing and pushing to the user

CHaP requires linear history and monotonically increasing timestamps, so the branch must be force-pushed after any rebase.
**Do not sign or push yourself** - ask the user to run it.
`N` is the number of new commits from step 4, which is **1** for a single `add-from-github.sh` invocation
however many packages it covered; confirm against the `origin/main..HEAD` log rather than counting packages:

Print them **without** `git -C <path>` - the user runs them in their own shell, already in the CHaP checkout:

```
git rebase --gpg-sign --force-rebase HEAD~N
git push --force-with-lease -u origin <branch>
```

Tell the user they can run these in-session by prefixing with `!`.
Wait for confirmation before continuing - the PR cannot be created until the branch exists on the remote.

### 6. Open the CHaP PR

**Do not write a title or body.** Let `gh` derive both from the commits:

```bash
cd /work/cardano-haskell-packages \
  && gh pr create --repo IntersectMBO/cardano-haskell-packages --base main --fill
```

`--fill` reproduces the house style seen in CHaP history: a single-commit release gets `Added <pkg>-<version>`, a multi-commit one gets the branch-derived title.
Never pass `-t`/`-b`, and never edit the PR afterwards.

Capture the URL:

```bash
CHAP_PR=$(gh pr view --repo IntersectMBO/cardano-haskell-packages --json url --jq .url)
```

Show it to the user.

### 7. Link back to the source release PR

Only when the input was a release PR.
Post the CHaP link as a **single-element markdown list** - GitHub renders a bare list item as the linked PR's title:

```bash
gh pr comment <source-pr> --repo <owner>/<repo> --body "- $CHAP_PR"
```

Nothing else in the comment body - no heading, no prose.
Before posting, check the PR's existing comments for an identical link and skip if it is already there.

Report the CHaP PR URL and the source-repo comment URL.

## Important rules

- Never modify `/work/cardano-haskell-packages` outside this branch, and never touch `main` beyond the reset in step 3.
- Never hand-edit `meta.toml` - `add-from-github.sh` owns that file's format (`timestamp`, `github = { repo, rev }`, optional `subdir`).
- Never sign, push or force-push on the user's behalf; step 5 is always theirs to run.
- **Any command printed for the user to run is written bare - no `git -C <path>`, no `cd <path> &&` prefix.**
  They are already in the right checkout. Path prefixes belong only in commands the skill runs itself.
- Never pass an SSH remote URL to the release script, even though CHaP's own `origin` is SSH.
- If CI later reports a timestamp-ordering conflict after a rebase onto `main`, the fix is
  `./scripts/update-timestamps-and-fixup.sh <rev>` followed by `git rebase main --autosquash` - then re-sign and force-push again.
- Metadata-only revisions of an already-released version are a different workflow (`./scripts/add-revision.sh`, which does not commit) - this skill does not cover them.
