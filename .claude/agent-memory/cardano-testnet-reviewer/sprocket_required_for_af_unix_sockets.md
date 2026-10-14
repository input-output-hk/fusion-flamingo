---
name: sprocket-required-for-af-unix-sockets
description: cardano-testnet's established pattern for any new AF_UNIX socket (not just node N2C sockets) is the Sprocket abstraction, not a raw FilePath; a new process-starter that skips it breaks on Windows and loses the length guard
metadata:
  type: reference
---

Every existing socket-creating call site in cardano-testnet (`startNode` and `startKESAgent` in `cardano-testnet/src/Testnet/Runtime.hs`) builds its socket path via `Hedgehog.Extras.Stock.IO.Network.Sprocket.Sprocket base name`, then passes `sprocketArgumentName sprocket` on the command line and checks `List.length (sprocketArgumentName sprocket) <= maxSprocketArgumentNameLength` up front (throwing `MaxSprocketLengthExceededError` with a clear message otherwise).
This matters for two independent reasons, both invisible if you only read one call site:
1. **Windows**: `sprocketArgumentName`/`sprocketSystemName` have an `isWin32` branch that renders the socket as a named-pipe string (`sprocketNamedPipeName`, `\\.\pipe\...`) instead of a filesystem path. A raw `FilePath </> name` construction skips this entirely and will not work as a Windows named pipe.
2. **AF_UNIX length**: `maxSprocketArgumentNameLength = 104` (POSIX) vs `256` (Windows) in `hedgehog-extras`'s `Sprocket.hs`, deliberately just under the 108-byte `sun_path` kernel limit (see the `/tmp` output-dir gotcha in `/work/AGENTS.md`). The check operates on the *relative* argument string (processes are launched with `cwd = tempBaseAbsPath` via `IO.cwd`), which is exactly why long absolute testnet output directories don't blow the limit as long as every socket argument goes through this path.

Found violated in IntersectMBO/cardano-node PR #6710 ("Add prometheus support to cardano-testnet"): the new `Testnet.CardanoTracer.startCardanoTracer` builds its listening/connecting socket as a bare `makeSocketDir tmpPath </> defaultSocketName` `FilePath`, with neither the Windows branch nor the length guard. Low practical risk for the length guard specifically (the tracer's path is always shorter than any node's own socket path, which does carry the check, so a too-long workspace fails on the first node first) — but the Windows gap is real since the new `EnableTracer` integration test is `ignoreOnMacAndWindows`, so nothing in CI would ever catch a Windows regression here.

Checklist for reviewing any future code that opens a new local/Unix socket in cardano-testnet: does it go through `Sprocket`, or at minimum mirror both the Windows named-pipe branch and the `maxSprocketArgumentNameLength` guard?
