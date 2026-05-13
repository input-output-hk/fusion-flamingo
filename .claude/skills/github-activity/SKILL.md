---
name: github-activity
description: Retrieve and summarise a GitHub user's activity for a given time period.
argument-hint: <github-username> [<period>]
---

Retrieve and summarise GitHub activity for a user over a time period.

Arguments: $ARGUMENTS

## Argument parsing

Parse the arguments as `<github-username> [<period>]`.

- `github-username` is required.
  If omitted, resolve it in this order:
  1. `gh api user --jq '.login'` - the authenticated GitHub user.
  2. `git log --format='%ae' -1` - look for a `users.noreply.github.com` email and extract the username prefix.
  3. If both fail, ask the user.
- `period` is optional and defaults to "today".
  Interpret natural language: "today", "yesterday", "this week", "last 3 days", "2026-04-10 to 2026-04-14", etc.
  Convert to a start date (YYYY-MM-DD) and end date (YYYY-MM-DD) inclusive.

## Procedure

### 1. Fetch events

Use `gh api` (NOT `--paginate` - it breaks jq, see AGENTS.md) to fetch events page by page:

```bash
gh api "users/${USERNAME}/events?per_page=100&page=${PAGE}" 2>/dev/null
```

Filter events whose `created_at` falls within the date range.
Fetch additional pages only if the last event on the current page is still within range.

### 2. Extract and classify events

Run all extraction queries **in parallel** - use a single message with multiple Bash tool calls, one per event type.
Use jq with **defensive null handling** (`//`, `?`, `[]?`) throughout - GitHub event payloads frequently contain null fields.

Group events by type:

- **PullRequestEvent**: action (opened/closed/merged/reopened), repo, PR number.
  PR titles in event payloads are often null - fetch the real title with `gh pr view <number> --repo <owner/repo> --json title`.
  Fetch all PR titles **in parallel** (one Bash call per PR).
- **PushEvent**: repo, branch, commit messages (use `[.payload.commits[]?.message]`).
  Deduplicate: omit pushes to branches that already appear under PRs merged/opened/reviewed (same repo + branch matches the PR's head branch).
  Keep pushes to default branches (e.g. `master`/`main`) only if they are NOT merge commits from an already-listed PR - i.e. skip merge pushes for PRs already shown.
- **IssueCommentEvent**: repo, issue number, issue title.
- **PullRequestReviewEvent**: repo, PR number, review state.
- **CreateEvent / DeleteEvent**: ref type, ref name, repo.
- **IssuesEvent**: action, repo, issue number, title.
- **MemberEvent**: member added, repo.
- **ForkEvent**, **WatchEvent**, **ReleaseEvent**: note briefly.
- Other event types: list them with repo and timestamp.

### 3. Present the summary

Output a single compact nested list.
Use full GitHub URLs for PRs and issues (e.g. `https://github.com/owner/repo/pull/123`).
Omit empty categories.
Sort chronologically (earliest first) within each category.

After each item, append a very short description (few words) of what it does or what changed.
If a category has only one item, collapse it into a single line: `- Category: item`.

```
- PRs merged
  - [title](https://github.com/owner/repo/pull/N) - short description
- PRs opened / reviewed
  - [title](https://github.com/owner/repo/pull/N) - opened/reviewed, short description
- Code pushed
  - [owner/repo](https://github.com/owner/repo) `branch` - short description
- Issues / comments
  - [title](https://github.com/owner/repo/issues/N) - closed/commented, short description
- Repo admin (skip branch created/deleted events; keep member additions, repo transfers, etc.)
  - added `user` to [owner/repo](https://github.com/owner/repo)
- Other
  - event type, [owner/repo](https://github.com/owner/repo), timestamp

N PRs merged, N opened, N pushes across N repos.
```

## Important rules

- **Every mention of a PR or issue MUST be a hyperlink**, not just the first one. Use full GitHub URLs (e.g. `https://github.com/owner/repo/pull/123`). If you reference "PR 1185" in prose, it must be `[PR 1185](https://github.com/owner/repo/pull/1185)`.
- **Do not list branch activity for PRs already mentioned.** Pushes, branch creations, and branch deletions for branches tied to a PR in the output are already implied by the PR entry - omit them. Only list push/branch activity for branches NOT tied to any listed PR (e.g. pushes to `master`/`main`, or to standalone branches).
- Do not invent categories outside the template. Stick to: PRs merged, PRs opened / reviewed, Code pushed, Issues / comments, Repo admin, Other.
- Never use `gh api --paginate` piped to jq - it produces broken JSON. See AGENTS.md.
- Always use `[]?` and `// ""` in jq for nullable fields in event payloads.
- Fetch PR titles separately with `gh pr view` - do not rely on event payload titles.
- If `gh` is not authenticated, tell the user to run `! gh auth login`.
- In output text, use a single `-` as separator, never `--`.
