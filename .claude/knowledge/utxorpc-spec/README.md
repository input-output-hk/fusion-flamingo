# utxorpc-spec

Domain knowledge about the `/work/utxorpc-spec` fork, moved out of AGENTS.md.

- `/work/utxorpc-spec` is the user's fork (`carbolymer/utxorpc-spec`) of `utxorpc/spec`; the Haskell package `utxorpc` lives in `gen/haskell` and only its skeleton (`utxorpc.cabal`, `cabal.project`, `stack.yaml`, lock, README) is tracked - the `Proto/**` modules are generated in CI by `buf generate proto` (plugin `proto-lens-protoc`) and never committed, for any language.
  To check that `exposed-modules` matches the protos, generate into the scratchpad with `protoc -I proto -I <protobuf>/include --plugin=protoc-gen-haskell=proto-lens-protoc --haskell_out=<scratch> $(find proto -name '*.proto')` and build the copy there (never a `cabal build` inside `/work/utxorpc-spec`).
- **The `codegen/<lang>` working directories in `.github/actions/publish-*` are correct, not stale** (misjudged 2026-09-23): `generate.yml` uploads `gen/**` as artifact `codegen` (upload-artifact strips the common `gen/` prefix) and `publish-all.yml` downloads it to `./codegen`, so `codegen/haskell` exists in the publish job even though the repo has `gen/haskell`.
  Upstream pr-check and release runs for Haskell were green as of 2026-09-14, so treat those paths as working before "fixing" them.
