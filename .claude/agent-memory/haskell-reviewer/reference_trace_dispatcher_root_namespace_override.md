---
name: trace-dispatcher-root-namespace-override
description: cardano-node's trace-dispatcher merges a node config's TraceOptions over Cardano.Node.Tracing.DefaultTraceConfig.defaultCardanoConfig per-namespace, but a config that DOES specify the root "" namespace replaces defaultCardanoConfig's root entry wholesale rather than merging field-by-field
metadata:
  type: reference
---

`cardano-node/src/Cardano/Node/Tracing/DefaultTraceConfig.hs`'s `defaultCardanoConfig` sets the root namespace (`tcOptions` key `[]`, i.e. the config file's `TraceOptions.""`) to `ConfSeverity Notice, ConfDetail DNormal, ConfBackend [Stdout MachineFormat, EKGBackend]`. `Cardano.Node.Tracing.API.initTraceDispatcher` calls `readConfigurationWithDefault (FromFile configPath) defaultCardanoConfig`, which fills in anything the node's own config file doesn't specify.

So a node config with `TraceOptions: {}` (no `""` key at all - this is what cardano-testnet's own `Testnet.Defaults.defaultYamlHardforkViaConfig` always generates) falls through entirely to `defaultCardanoConfig`'s root settings, i.e. `Stdout MachineFormat`. But a config that DOES populate `TraceOptions.""` (even partially) overrides that whole namespace's backends/severity/detail as specified - there is no per-field merge against `defaultCardanoConfig` once a namespace entry exists in the file's config.

This matters for anything that writes/rewrites `TraceOptions` into a generated node config (e.g. cardano-testnet's `--enable-tracer` support, PR #6710's `enableTraceForwarding`): writing a root-namespace entry with `backends: [Forwarder, EKGBackend, "Stdout HumanFormatColoured"]` doesn't *add* forwarding to the node's existing `Stdout MachineFormat` default, it *replaces* the whole backend list, silently swapping the node's stdout log format from machine-readable to human-coloured as a side effect. See [[feedback_check_insertWith_arg_order]] for the related merge-logic bug found alongside this.
