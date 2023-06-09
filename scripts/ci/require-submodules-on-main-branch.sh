#!/usr/bin/env bash
#
# This script checks that all submodules are on the main branch when the main branch of the repository is main.
#
# The script exits with a non-zero exit code if any submodules are not on the main branch.

# TODO: Use this initialisation of main_branch once the repository is made public
# main_branch=$(gh repo view --json defaultBranchRef | jq -r .defaultBranchRef.name)

main_branch=main
mismatches=0
toplevel="$(git rev-parse --show-toplevel)"

if [ "$main_branch" == "main" ]; then
  for submodule in $(git submodule -q foreach --recursive 'echo "$name"'); do
    (
      cd "$submodule"
      submodule_branch="$(git config --file "$toplevel/.gitmodules" "submodule.$submodule.branch")"
      submodule_main_branch="$(gh repo view --json defaultBranchRef | jq -r .defaultBranchRef.name)"
      if [ "$submodule_branch" != "$submodule_main_branch" ]; then
        echo -e "\e[31mSubmodule $submodule is not on main branch. ($submodule_branch != $submodule_main_branch)\e[0m"
        mismatches=$((mismatches + 1))
      else
        echo -e "\e[32mSubmodule $submodule is on main branch\e[0m"
      fi
    )
  done

  echo

  if [ "$mismatches" -gt 0 ]; then
    echo -e "\e[31mThere are $mismatches submodules not on main branch\e[0m"
    exit 1
  else
    echo -e "\e[32mAll submodules are on main branch\e[0m"
  fi
fi
