---
name: ghci
description: Interactive GHCi REPL - type lookup, kind evaluation, Haddock docs, reload, test execution, code exploration, debugging.
argument-hint: "<ghci-command> | start [component] | stop | test [pattern]"
---

Interact with a persistent `cabal repl` session via tmux.
One startup cost, then instant queries.

Arguments: $ARGUMENTS

Helper script: `/work/.claude/skills/ghci/ghci-session`

## Interpreting arguments

Parse `$ARGUMENTS` to determine the action:

| Pattern | Action |
|---|---|
| `start [component]` | Start a new session |
| `stop [name]` | Stop a session |
| `stop-all` | Stop all sessions |
| `status [name]` | Check session status |
| `list` | List active sessions |
| `test [pattern]` | Run Tasty tests (optionally filtered) |
| `test-list` | List available Tasty tests |
| `:type expr`, `:info name`, `:kind type`, `:doc name`, `:browse mod`, etc. | Send verbatim to GHCi |
| `eval <expr>` | Evaluate a Haskell expression |
| Any other `:` command | Send verbatim to GHCi |
| Empty / no args | Show status of all sessions |

## Session management

### Starting a session

```bash
/work/.claude/skills/ghci/ghci-session start <name> <cabal-component>
```

Pick a short session name based on the component:

| Component | Session name | Start command |
|---|---|---|
| `lib:cardano-rpc` | `rpc` | `start rpc lib:cardano-rpc` |
| `lib:cardano-api` | `api` | `start api lib:cardano-api` |
| `lib:cardano-cli` | `cli` | `start cli lib:cardano-cli` |
| `test:cardano-rpc-test` | `rpc-test` | `start rpc-test test:cardano-rpc-test` |
| `test:cardano-api-test` | `api-test` | `start api-test test:cardano-api-test` |
| `test:cardano-cli-test` | `cli-test` | `start cli-test test:cardano-cli-test` |
| `exe:cardano-node` | `node` | `start node exe:cardano-node` |

The first start compiles dependencies and may take minutes.
Subsequent starts (or `:reload`) only recompile changed modules.

If the user does not specify a component, infer it from context:
- If recent edits are in `cardano-rpc/`, use `lib:cardano-rpc`
- If recent edits are in `cardano-api/`, use `lib:cardano-api`
- If talking about tests, use the test component

If truly ambiguous, ask.

### Stopping

```bash
/work/.claude/skills/ghci/ghci-session stop <name>
/work/.claude/skills/ghci/ghci-session stop-all
```

### Checking status

```bash
/work/.claude/skills/ghci/ghci-session list
/work/.claude/skills/ghci/ghci-session status <name>
```

### Auto-start

If the user sends a GHCi command but no session is running, start one first.
Infer the component from context.

## Sending GHCi commands

```bash
/work/.claude/skills/ghci/ghci-session send <name> "<ghci-command>"
```

**Always quote the GHCi command** to prevent shell interpretation of special characters (`>>=`, `$`, `|`, `'`, `"`, `*`, etc.):

```bash
/work/.claude/skills/ghci/ghci-session send rpc ":type fmap"
/work/.claude/skills/ghci/ghci-session send rpc ':info Monad'
/work/.claude/skills/ghci/ghci-session send rpc ':kind! Rep Int'
```

For multi-line input (e.g. `:{` ... `:}`):

```bash
/work/.claude/skills/ghci/ghci-session multi <name> <<'EOF'
:{
let f x = x + 1
    g x = x * 2
:}
f (g 3)
EOF
```

## GHCi command reference

### Type and kind inspection

| GHCi command | What it does | Example |
|---|---|---|
| `:type expr` | Show type of expression | `:type fmap` |
| `:type +d expr` | Show type with defaulted type variables | `:type +d show` |
| `:type +v expr` | Show type with visible forall | `:type +v id` |
| `:info name` | Definition, instances, where defined | `:info Monad` |
| `:info! name` | Same but show ALL instances (unfiltered) | `:info! Functor` |
| `:kind type` | Show kind of a type | `:kind Maybe` |
| `:kind! type` | Evaluate type families, show normalised kind | `:kind! Rep Int` |
| `:instances type` | List class instances available for a type | `:instances Int` |

### Documentation and browsing

| GHCi command | What it does | Example |
|---|---|---|
| `:doc name` | Show Haddock documentation | `:doc fmap` |
| `:browse Mod` | List exported names of a module | `:browse Data.Map` |
| `:browse! Mod` | More details (types, classes) | `:browse! Cardano.Api` |
| `:browse *Mod` | All top-level names (including non-exported) | `:browse *Cardano.Api.Internal` |
| `:list name` | Show source code around a definition | `:list submitTxToNodeLocal` |
| `:list line` | Show source code around line number | `:list 42` |
| `:list [mod] line` | Show source in specific module | `:list Cardano.Api 100` |

### Module management

| GHCi command | What it does | Example |
|---|---|---|
| `:load mod` | Load module(s) and dependencies | `:load Cardano.Api` |
| `:load! mod` | Load with deferred type errors | `:load! Cardano.Api` |
| `:reload` | Reload all changed modules | `:reload` |
| `:reload!` | Reload with deferred type errors | `:reload!` |
| `:add mod` | Add module to current target set | `:add Cardano.Api.Ledger` |
| `:unadd mod` | Remove module from target set | `:unadd Cardano.Api.Ledger` |
| `:module +Mod` | Bring module into scope for evaluation | `:module +Data.Map` |
| `:module -Mod` | Remove module from evaluation scope | `:module -Data.Map` |

### Expression evaluation

| GHCi command | What it does | Example |
|---|---|---|
| `expr` | Evaluate and print | `1 + 2` |
| `:main args` | Run `main` with command-line arguments | `:main --pattern Foo` |
| `:run fn args` | Run a function with arguments | `:run myFn "hello"` |
| `:force expr` | Evaluate fully (force thunks) and print | `:force myThunk` |
| `:print name` | Print without forcing evaluation | `:print myVal` |
| `:sprint name` | Simplified print (shows unevaluated as `_`) | `:sprint myVal` |

### Session information

| GHCi command | What it does |
|---|---|
| `:show modules` | List currently loaded modules |
| `:show imports` | Show current import context |
| `:show language` | Show active language extensions |
| `:show targets` | Show current compilation targets |
| `:show packages` | Show active package flags |
| `:show bindings` | Show let-bindings from the prompt |
| `:show breaks` | Show active breakpoints |
| `:show paths` | Show search paths |

### Settings

| GHCi command | What it does |
|---|---|
| `:set -XOverloadedStrings` | Enable a language extension |
| `:set -Wall` | Enable all warnings |
| `:set +s` | Show timing and memory after each evaluation |
| `:set +t` | Print type after each evaluation |
| `:set +c` | Collect type/location info after loading |
| `:set +m` | Allow multi-line commands without `:{`/`:}` |
| `:set +r` | Revert top-level expressions after each eval |
| `:set -fobject-code` | Compile to object code (faster reloads, slower initial) |
| `:unset +s` | Disable a setting |

### Debugging

| GHCi command | What it does | Example |
|---|---|---|
| `:break mod line [col]` | Set breakpoint at location | `:break Cardano.Api 42` |
| `:break name` | Set breakpoint on function entry | `:break submitTx` |
| `:continue` | Resume execution after breakpoint | `:continue` |
| `:continue N` | Resume, skip next N hits | `:continue 5` |
| `:step` | Single-step into next expression | `:step` |
| `:step expr` | Single-step into expression | `:step myFn 42` |
| `:steplocal` | Step within current top-level binding | `:steplocal` |
| `:stepmodule` | Step within current module only | `:stepmodule` |
| `:trace` | Resume with tracing enabled | `:trace` |
| `:trace expr` | Evaluate with tracing | `:trace myFn 42` |
| `:history [n]` | Show last N steps of execution trace | `:history 20` |
| `:back [n]` | Go back N steps in history | `:back` |
| `:forward [n]` | Go forward N steps in history | `:forward` |
| `:delete N` | Delete breakpoint N | `:delete 1` |
| `:delete *` | Delete all breakpoints | `:delete *` |
| `:disable N` | Disable breakpoint N | `:disable 1` |
| `:enable N` | Enable breakpoint N | `:enable 1` |
| `:show breaks` | List all breakpoints | `:show breaks` |
| `:show context` | Show breakpoint context | `:show context` |
| `:abandon` | Abandon current computation at breakpoint | `:abandon` |
| `:ignore N count` | Ignore breakpoint N for count hits | `:ignore 1 10` |

## Tasty test execution

### Running tests from the REPL

Start a session with the test component, then use `:main`:

```bash
# Start test session
/work/.claude/skills/ghci/ghci-session start rpc-test test:cardano-rpc-test

# Run all tests
/work/.claude/skills/ghci/ghci-session send rpc-test ':main'

# Run tests matching a pattern
/work/.claude/skills/ghci/ghci-session send rpc-test ':main --pattern "Pagination"'

# List all test names
/work/.claude/skills/ghci/ghci-session send rpc-test ':main --list-tests'

# Run with specific options
/work/.claude/skills/ghci/ghci-session send rpc-test ':main --num-threads 1'
/work/.claude/skills/ghci/ghci-session send rpc-test ':main --quiet'
/work/.claude/skills/ghci/ghci-session send rpc-test ':main --hedgehog-tests 1000'
```

**Note:** `*** Exception: ExitSuccess` in test output is normal - Tasty calls `exitSuccess` which GHCi reports as an exception.
Check `*** Exception: ExitFailure 1` to detect actual test failures.

### Tasty pattern syntax

Tasty `--pattern` uses AWK-like expressions:
- `--pattern "TestName"` - substring match on test name
- `--pattern "/Group/SubGroup/"` - match by test group path
- `--pattern "$1 == \"Group\" && $2 == \"Test\""` - AWK expression (field = group depth)

### Test iteration workflow

1. Start a test session once: `start rpc-test test:cardano-rpc-test`
2. Edit source files
3. Reload: `send rpc-test ':reload'`
4. Run specific test: `send rpc-test ':main --pattern "MyTest"'`
5. Repeat 2-4

This is much faster than `cabal test` because GHCi only recompiles changed modules.

## Common workflows

### Type exploration workflow

```bash
# What type is this function?
send rpc ':type submitTxToNodeLocal'

# What's this type class? What instances exist?
send rpc ':info IsShelleyBasedEra'

# What does this type family evaluate to?
send rpc ':kind! Rep (TxBody ConwayEra)'

# What instances does this type have?
send rpc ':instances TxBody ConwayEra'

# Read the Haddock docs
send rpc ':doc submitTxToNodeLocal'
```

### Module exploration workflow

```bash
# What does this module export?
send rpc ':browse Cardano.Api.Ledger'

# Including non-exported internals
send rpc ':browse *Cardano.Api.Internal'

# Bring a module into scope for experiments
send rpc ':module +Data.Map.Strict'
send rpc 'Data.Map.Strict.fromList [(1, "a"), (2, "b")]'
```

### Edit-reload-check workflow

```bash
# After editing Haskell files:
send rpc ':reload'

# Check if a function's type changed
send rpc ':type myFunction'

# Try calling it
send rpc 'myFunction exampleArg'
```

### Debug a function

```bash
# Load with debugging support (interpreted mode)
send rpc ':load *MyModule'

# Set a breakpoint
send rpc ':break myFunction'

# Call the function - execution stops at breakpoint
send rpc 'myFunction testInput'

# Inspect local variables
send rpc ':show bindings'
send rpc ':print localVar'

# Step through
send rpc ':step'
send rpc ':steplocal'

# Show execution trace
send rpc ':history 10'

# Continue
send rpc ':continue'

# Clean up
send rpc ':delete *'
```

## Handling the `test` shorthand

When `$ARGUMENTS` starts with `test`:

1. If no test session is running, start one (infer component from context).
2. If a pattern follows `test`, run `:main --pattern "<pattern>"`.
3. If no pattern, run `:main`.
4. Report results.

When `$ARGUMENTS` is `test-list`:

1. Ensure test session is running.
2. Run `:main --list-tests`.

## Important rules

- **Always run from `/work`** - the helper script handles this.
- **Always quote GHCi commands** in the bash call to avoid shell metacharacter issues.
- **Report output faithfully** - show the GHCi response to the user. Don't summarise type signatures or truncate error messages.
- **Prefer `:reload` over restarting** - it's much faster. Only restart if the session is broken.
- **Use 600000ms timeout** for the `start` command (compilation can be slow).
- **Use 300000ms timeout** for `send` commands (tests can run long).
- The output includes echoed GHCi commands - that's expected context, not noise.
- If a command times out, show whatever partial output is available and suggest checking with `status` or `log`.
