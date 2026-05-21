---
name: user-story
description: Create or refine a user story with testable acceptance criteria for TDD implementation.
argument-hint: <feature-name-or-description>
---

Create or refine a user story using the product-analyst agent.

Arguments: $ARGUMENTS

## Procedure

1. **Parse arguments**: the argument is a short feature name or description (e.g. "version-file support", "init discovers monorepo projects").
   If no argument is given, ask the user what feature they want a story for.

2. **Launch the product-analyst agent** with a prompt that includes:
   - The feature name/description from the argument.
   - Instructions to scan the codebase for relevant context (existing types, tests, config, related modules).
   - The output location: stories go in `/work/cardano-dev/herald/stories/` as `<feature-slug>.md`.
   - Whether this is a new story or a refinement of an existing one (check if the file already exists).

3. **Review the agent's output**: read the story file and verify it follows the format defined in the product-analyst agent (Problem, Why, User value, numbered ACs with test type tags, Out of scope, Definition of done, Notes).

4. **Show the story to the user** and ask if they want any changes.
