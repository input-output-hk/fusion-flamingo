# fusion-flamingo
Development repository for the fusion-flamingo team

## Tools and configurations

### `inotifywait.sh`
Constantly watches the directory, and exits when changes are made.
Useful for rebuilding on file change for example:
```bash
while :; do cabal test cardano-cli-test-golden; sleep 0.5; ./inotifywait.sh ; done
```

### `haskdogs.txt`
List of directories useful for generating ctags

```bash
haskdogs -d haskdogs.txt
```

### `.envrc`
`direnv` configuration.
Adds prefixes for building the projects with crypto libraries.
Downloads GHC configured in `cabal.project.local` **if** `ghcup` is present.

### `hie.yaml`
Generic HLS configuration to make it work everywhere.
