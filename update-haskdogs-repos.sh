#!/usr/bin/env bash
set -euo pipefail

dirs_file="$(dirname "$0")/haskdogs-dirs.txt"

if [[ ! -f "$dirs_file" ]]; then
  echo "File not found: $dirs_file" >&2
  exit 1
fi

update_repo() {
  local dir="$1"
  if [[ ! -e "$dir/.git" ]]; then
    echo "[$dir] not a git repo, skipping" >&2
    return
  fi
  echo "[$dir] checking out master and pulling..."
  git -C "$dir" checkout master 2>&1 | sed "s/^/[$dir] /"
  git -C "$dir" pull 2>&1 | sed "s/^/[$dir] /"
}

export -f update_repo

parallel -j "$(nproc)" update_repo :::: "$dirs_file"
