This file is an index. Full memory files live alongside this one in
`/work/.claude/agent-memory/cardano-testnet-reviewer/`.

- [rpc_http_port_failure_detection.md](rpc_http_port_failure_detection.md) — cardano-testnet's stderr-scan retry mechanism cannot detect or recover from a bind failure on a port owned by cardano-node's RPC server (started via a discarded `withAsync`, exceptions silently swallowed); only the main N2C port has a working probe+retry path.
