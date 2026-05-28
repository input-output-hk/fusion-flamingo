---
name: discover
description: Fast project discovery - produces a compact profile (~150 lines) of any project for agent consumption.
argument-hint: "[path/to/project]"
---

Generate a compact project profile for agent consumption.

Arguments: $ARGUMENTS

If no path argument is given, use the current working directory.
Let `$PROJECT` be the resolved absolute path.

## Procedure

Run this single bash command and print the output. That's it. Do not run anything else.

```bash
PROJECT="${PROJECT:-$(pwd)}" && _d=$(mktemp -d) && {

# --- parallel data gathering into temp files ---
{
  # Adaptive tree: L1 for big projects, L2 for small ones
  ndirs=$(find "$PROJECT" -maxdepth 1 -type d | wc -l)
  if [ "$ndirs" -gt 15 ]; then
    tree -L 1 -d --noreport "$PROJECT" 2>/dev/null | head -50
  else
    tree -L 2 -d --noreport "$PROJECT" 2>/dev/null | head -50
  fi
} > "$_d/shape" &

{
  if command -v tokei >/dev/null 2>&1; then
    tokei "$PROJECT" --sort lines 2>/dev/null | head -25
  else
    nix run nixpkgs#tokei -- "$PROJECT" --sort lines 2>/dev/null | head -25 ||
    fd -t f "$PROJECT" | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15
  fi
} > "$_d/langs" &

{
  for cabal in "$PROJECT"/*.cabal "$PROJECT"/*/*.cabal; do
    [ -f "$cabal" ] || continue
    echo "**$(basename "$cabal" .cabal):**"
    grep -E '^\s*(name:|executable |test-suite |benchmark |library)' "$cabal" \
      | sed 's/^[[:space:]]*/  /' | sed 's/  name:[[:space:]]*/  name: /' | head -20
  done
  if [ -f "$PROJECT/package.json" ]; then
    echo "**npm scripts:**"
    jq -r '.scripts | keys[]' "$PROJECT/package.json" 2>/dev/null | head -10
  fi
  if [ -f "$PROJECT/Cargo.toml" ]; then
    echo "**cargo targets:**"
    grep -E '^\[(bin|lib|bench|test|example)\]|^name\s*=' "$PROJECT/Cargo.toml" | head -10
  fi
} > "$_d/build" &

{
  echo "**Root:**"
  fd -t f -d 1 . "$PROJECT" 2>/dev/null | sed "s|.*/||" | sort | head -20
  if [ -d "$PROJECT/.github" ]; then
    echo "**CI:**"
    fd -t f '\.(yml|yaml)$' "$PROJECT/.github" 2>/dev/null | sed "s|.*/||" | sort | head -10
  fi
} > "$_d/files" &

wait

# --- sequential assembly ---
echo "## Project: $(basename "$PROJECT")"
echo "**Path:** $PROJECT"

# Detect type
types=""
fd -e cabal -d 2 . "$PROJECT" 2>/dev/null | grep -q . && types="$types Haskell(cabal)"
[ -f "$PROJECT/package.yaml" ] && types="$types Haskell(hpack)"
[ -f "$PROJECT/stack.yaml" ] && types="$types Haskell(stack)"
[ -f "$PROJECT/flake.nix" ] && types="$types Nix"
[ -f "$PROJECT/package.json" ] && types="$types JS/TS"
[ -f "$PROJECT/Cargo.toml" ] && types="$types Rust"
[ -f "$PROJECT/pyproject.toml" ] && types="$types Python"
[ -f "$PROJECT/go.mod" ] && types="$types Go"
echo "**Type:**${types:- unknown}"
echo

echo "### Description"
if [ -f "$PROJECT/README.md" ]; then
  sed -n '/^[^#!\[<[:space:]]/{p; :l; n; /^$/q; p; b l}' "$PROJECT/README.md" | head -8
fi
echo -n "**Docs:** "
for f in CLAUDE.md AGENTS.md CONTRIBUTING.md CHANGELOG.md LICENSE RELEASING.md; do
  [ -f "$PROJECT/$f" ] && echo -n "$f "
done
echo; echo

echo "### Shape"
cat "$_d/shape"
echo

echo "### Languages"
cat "$_d/langs"
echo

echo "### Build targets"
cat "$_d/build"
echo

echo "### Key files"
cat "$_d/files"

rm -rf "$_d"
}
```

Replace `$PROJECT` with the actual path before running.

## Important rules
- Run the SINGLE command above. Do not add extra steps, reads, or analysis.
- Do not activate Serena, HLS, or any language server.
- Do not run builds or tests.
- Print the raw output. Do not summarise or reformat it.
