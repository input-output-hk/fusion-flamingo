#!/usr/bin/env bash
set -euo pipefail

output_file="${1:-tags}"
dirs_file="$(dirname "$0")/haskdogs-dirs.txt"

if [[ ! -f "$dirs_file" ]]; then
  echo "File not found: $dirs_file" >&2
  exit 1
fi

mapfile -t dirs < <(grep -v '^$' "$dirs_file")

orig_file="$(mktemp)"

cleanup() {
  echo "Restoring original branches..."
  while IFS=$'\t' read -r dir branch; do
    if [[ "$branch" == "HEAD" ]]; then
      echo "[$dir] was in detached HEAD, leaving as-is" >&2
      continue
    fi
    git -C "$dir" checkout "$branch" 2>&1 | sed "s/^/[$dir] /" || true
  done < "$orig_file"

  if [[ -f tags.bak ]]; then
    mv tags.bak tags
  fi

  rm -f "$orig_file"
}
trap cleanup EXIT

for dir in "${dirs[@]}"; do
  if [[ ! -e "$dir/.git" ]]; then
    echo "[$dir] not a git repo, skipping" >&2
    continue
  fi
  branch="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
  printf '%s\t%s\n' "$dir" "$branch" >> "$orig_file"
done

if [[ -f tags ]]; then
  mv tags tags.bak
fi

update_repo() {
  local dir="$1"
  if [[ ! -e "$dir/.git" ]]; then
    echo "[$dir] not a git repo, skipping" >&2
    return
  fi
  local default_branch
  default_branch="$(git -C "$dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')" || {
    echo "[$dir] origin/HEAD not set, skipping" >&2
    return
  }
  echo "[$dir] checking out $default_branch and pulling..."
  git -C "$dir" checkout "$default_branch" 2>&1 | sed "s/^/[$dir] /"
  git -C "$dir" pull 2>&1 | sed "s/^/[$dir] /"
}
export -f update_repo

parallel -j "$(nproc)" update_repo ::: "${dirs[@]}"

haskdogs -d "$dirs_file"
mv tags "$output_file"
