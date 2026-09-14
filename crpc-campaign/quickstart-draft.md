# Quickstart draft for cardano-rpc

Target home: a "Quickstart" section near the top of `cardano-rpc/README.md` (which already has the spec coverage table and security section; do not duplicate those).

Commands and code verified against live cluster runs on 2026-09-09/10; three persona reviews (editor, newcomer, dApp developer) applied on 2026-09-10.
Remaining follow-ups:

1. RESOLVED for the CLI path (2026-09-11, cardano-api PR #1334): the README's CLI examples (buf curl, grpcurl) now rely on gRPC server reflection and no longer pass `--schema` / `-proto` / `-import-path`, and the repository-checkout prerequisite is scoped down to the TypeScript example only.
   Not live-verified: the only cluster reachable here runs a released cardano-testnet build that predates PR #1334, so `grpcurl list` against it still fails ("server does not support the reflection API"), which is the expected result on that build, not a regression.
   Re-run the discovery commands against a cluster built from a post-#1334 cardano-api once one is available, and record the result here.
   The TypeScript example is unaffected and out of scope for this item: `@grpc/proto-loader` reads local proto files directly and has no reflection support of its own, so it keeps loading the vendored protos regardless of server-side reflection; it stays that way until the JS SDK's v1beta support lands (see item 4).
2. Candidate upstream fix: make cardano-testnet fall back to PATH for `CARDANO_NODE`/`CARDANO_CLI` (helps non-nix users).
   The TCP listener option for cardano-testnet is in flight as PR #6685 (`--enable-grpc-http`); once merged, replace the socat bridge with that flag and simplify the cluster section.
3. RESOLVED for the CLI path: reflection (item 1) makes the missing BSR module moot for buf curl/grpcurl, which now describe the server directly instead of needing a schema from buf.build or the checkout.
   The underlying fact stands and still matters for anything that would want a published schema (e.g. a future buf-based JS codegen path): there is no utxorpc module on buf.build (checked; the spec repo does not publish to the BSR).
4. The published JS u5c SDK stack speaks `utxorpc.v1alpha.*` only; cardano-rpc implements `v1beta`, so the off-the-shelf providers fail with UNIMPLEMENTED on every call.
   Root cause is `@utxorpc/spec`'s barrel exporting only v1alpha (the v1beta sources ship unreferenced); the fix is draft PR utxorpc/spec#209, with #208 stacked on it.
   The quickstart ships a small hand-rolled v1beta provider until that merges and the SDKs bump.
   Rust is not affected at the bindings level: `utxorpc-spec` 0.19.2 exposes v1beta (only the high-level `utxorpc` wrapper crate is v1alpha-only), which is what the Rust section uses.
5. The vendored `cardano.proto` has a small drift from the upstream v0.19.2 tag (`EvalReport`'s `purpose`/`index` are `optional` locally, plus a reworded comment) - looks like a local improvement not yet upstreamed; `sync.proto`/`query.proto` are byte-identical.
   Do not claim byte-for-byte proto parity anywhere until that is reconciled.
6. The JS example's `PROTO_ROOT` env-var override was added after verification (the verified run used the plain relative path); it is a trivial change but has not itself been executed.
7. TCP-first rewrite (2026-09-10): the socat bridge and a buf `ReadTip` over TCP were verified live earlier; the `ReadParams`/grpcurl TCP variants and the Rust/JS examples retargeted at `localhost:50051` are mechanical changes not yet re-run end to end.

---

## Quickstart

cardano-rpc is cardano-node's built-in gRPC interface, implementing the [UTxO RPC](https://utxorpc.org) spec.
It is part of cardano-node itself: you enable it with a configuration flag, there is no extra service to run, and it is built, tested, and released together with cardano-node.
Because UTxO RPC is a standard, the same client code also works against other servers that implement it, such as Dolos.
It serves live chain data: the tip, UTxO queries, protocol parameters, and transaction evaluation and submission.
It is not an indexer: there are no address-history queries; see the coverage table below for the full method status.
The same configuration works against any network, from the local cluster used here to mainnet.

### Prerequisites

1. [Nix](https://nixos.org/download/) with flakes enabled; every command below fetches its tools through it.
   The first invocations download the toolchain, which can take several minutes and a few gigabytes.
2. A checkout of this repository, for the vendored proto files the CLI and JS examples load:

   ```bash
   git clone https://github.com/IntersectMBO/cardano-api
   cd cardano-api
   ```

Work through "Start a local cluster" and "Make your first call" first; then pick the language section that matches your stack.

### Start a local cluster

The cardano-testnet command below bundles the matching cardano-node and cardano-cli binaries, so one command is enough:

```bash
nix run github:IntersectMBO/cardano-node#cardano-testnet -- \
  cardano --num-pool-nodes 1 --enable-grpc --output-dir /tmp/demo-cluster
```

This starts a testnet with a single block-producing cardano-node and its gRPC server enabled, and keeps running in the foreground until you press Ctrl+C.
The cluster is ready once it logs `Testnet started`; open a second terminal for everything below.
The cluster comes with funded test wallets, created at startup under `/tmp/demo-cluster/utxo-keys/utxo1` to `utxo3` (`utxo.skey`, `utxo.vkey`, `utxo.addr`); the transaction example below spends from `utxo1`.

The RPC endpoint is a Unix socket at `/tmp/demo-cluster/socket/node1/rpc.sock`, next to cardano-node's IPC socket.
Most gRPC tooling expects a TCP endpoint, so bridge the socket to `localhost:50051` with socat and leave it running (a second background process, alongside the cluster):

```bash
socat TCP-LISTEN:50051,fork,reuseaddr UNIX-CONNECT:/tmp/demo-cluster/socket/node1/rpc.sock
```

Every example below talks to `localhost:50051`.
Connecting to a cardano-node that listens on TCP directly (`--grpc-listen-port`, see the configuration reference) works the same way, without the bridge; cardano-testnet gets the same ability with `--enable-grpc-http` in [#6685](https://github.com/IntersectMBO/cardano-node/pull/6685).

> [!TIP]
> To use your own binaries instead of the bundled ones, export `CARDANO_NODE` and `CARDANO_CLI` with their paths before running.

> [!NOTE]
> Flag names differ between the two CLIs: `cardano-testnet` takes `--enable-grpc`, `cardano-node` itself takes `--grpc-enable`.

> [!WARNING]
> The output directory must not exist from a previous run; genesis creation fails on leftovers (`Genesis output directory already exists`).
> Run `rm -rf /tmp/demo-cluster` first when retrying, and make sure no cardano-node processes from an earlier attempt are still alive.
>
> Unix socket paths are capped at 108 bytes on Linux, and cardano-testnet fails at startup (`pokeSockAddr: path is too long`) when the output directory is nested too deep.
> Keep `--output-dir` shallow, e.g. under `/tmp`.

### Make your first call

The CLI examples use the proto files vendored in this repository, so run them from the repository root.
First enter a subshell that puts the tools on PATH (your prompt changes; run the commands below inside it):

```bash
nix shell nixpkgs#buf nixpkgs#grpcurl nixpkgs#socat
```

Read the chain tip (the most recently adopted block) with [buf](https://buf.build/docs/installation):

```bash
buf curl \
  --schema cardano-rpc/proto --protocol grpc --http2-prior-knowledge \
  http://localhost:50051/utxorpc.v1beta.sync.SyncService/ReadTip
```

It prints the tip as JSON: slot, hash, height, and timestamp.
Your values differ per run, and the tip advances between calls.

Then read the protocol parameters (the chain's current fee, size, and cost limits):

```bash
buf curl \
  --schema cardano-rpc/proto --protocol grpc --http2-prior-knowledge -d '{}' \
  http://localhost:50051/utxorpc.v1beta.query.QueryService/ReadParams
```

With grpcurl instead:

```bash
grpcurl -plaintext \
  -import-path cardano-rpc/proto -proto utxorpc/v1beta/sync/sync.proto \
  localhost:50051 \
  utxorpc.v1beta.sync.SyncService/ReadTip
```

### Call it from Rust

The Rust path is the simplest one: the published [`utxorpc-spec`](https://crates.io/crates/utxorpc-spec) crate already ships tonic-generated v1beta bindings, so no proto files and no protoc are needed, and the project can live anywhere (no repository checkout required).
Create a fresh project with `cargo new cardano-rpc-quickstart` and replace the two files below.
tonic can also connect straight to the Unix socket through a custom connector (`Endpoint::connect_with_connector` with a `tokio::net::UnixStream`), skipping the socat bridge; the TCP form below is the simpler one.

> [!IMPORTANT]
> Use `utxorpc-spec` directly, not the higher-level `utxorpc` SDK crate: that wrapper is hardwired to the older `utxorpc.v1alpha` services and cannot talk to cardano-rpc, which serves `v1beta` (v1beta packaging for the SDKs is tracked in utxorpc/spec#209).

`Cargo.toml`:

```toml
[package]
name = "cardano-rpc-quickstart"
version = "0.1.0"
edition = "2021"

[dependencies]
utxorpc-spec = { version = "0.19.2", default-features = false, features = [
    "utxorpc-v1beta-sync",
    "utxorpc-v1beta-query",
] }
tonic = "0.12.3"
tokio = { version = "1", features = ["macros", "rt-multi-thread"] }
hex = "0.4"
```

`src/main.rs`:

```rust
use tonic::transport::Endpoint;

use utxorpc_spec::utxorpc::v1beta::query::{
    any_chain_params::Params as AnyChainParamsVariant, query_service_client::QueryServiceClient,
    ReadParamsRequest,
};
use utxorpc_spec::utxorpc::v1beta::sync::{sync_service_client::SyncServiceClient, ReadTipRequest};

const RPC_URL: &str = "http://localhost:50051";

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let channel = Endpoint::try_from(RPC_URL)?.connect().await?;

    let mut sync_client = SyncServiceClient::new(channel.clone());
    let mut query_client = QueryServiceClient::new(channel);

    let tip = sync_client
        .read_tip(ReadTipRequest {})
        .await?
        .into_inner()
        .tip
        .expect("ReadTip response always carries a tip");
    println!(
        "Tip: slot {} height {} hash {}",
        tip.slot,
        tip.height,
        hex::encode(&tip.hash)
    );

    let params = query_client
        .read_params(ReadParamsRequest { field_mask: None })
        .await?
        .into_inner()
        .values
        .and_then(|v| v.params)
        .expect("cardano-rpc always returns Cardano parameters");
    match params {
        AnyChainParamsVariant::Cardano(pparams) => println!(
            "Protocol parameters: max_tx_size {} max_block_body_size {}",
            pparams.max_tx_size, pparams.max_block_body_size
        ),
    }

    Ok(())
}
```

Run it:

```bash
nix shell nixpkgs#cargo nixpkgs#rustc nixpkgs#gcc --command cargo run
```

Sample output (your values will differ):

```
Tip: slot 834 height 37 hash d76df679ffa93ca9d1224cff29b3479c7535a84ed3eb8c17ce1d34aaeb4e774d
Protocol parameters: max_tx_size 16384 max_block_body_size 65536
```

### Build and submit a transaction with MeshJS

The example sends 5 ADA from the cluster's `utxo1` wallet to the `utxo2` address, using [MeshJS](https://meshjs.dev) for wallet handling and transaction building, and cardano-rpc for UTxO queries, protocol parameters, and submission.
It talks to the socat bridge at `localhost:50051`; `@grpc/grpc-js` can also target the Unix socket directly with a `unix://` address, skipping the bridge.

> [!IMPORTANT]
> `@meshsdk/provider`'s off-the-shelf `U5CProvider` does not work against cardano-rpc: it is pinned to `@utxorpc/sdk` 0.6.x, which speaks the older `utxorpc.v1alpha` services, while cardano-rpc serves `v1beta` (v1beta packaging for the SDKs is tracked in utxorpc/spec#209).
> Until the SDKs move to v1beta, the small provider below talks v1beta directly by loading the proto files at runtime.
>
> The provider is demo scaffolding for plain ADA and native-asset payments: it maps oversized numeric values onto the `int` variant only, and it does not surface datums, inline datums, or reference scripts.
> Do not lift it unchanged into a dApp that touches script-locked UTxOs.

Create a fresh directory and install the dependencies (versions verified):

```bash
npm install @grpc/grpc-js@1.14.4 @grpc/proto-loader@0.8.1 @meshsdk/core@1.9.1 @meshsdk/core-cst@1.9.1
```

The provider loads the proto files vendored in this repository: run it from the repository root, or point `CARDANO_RPC_PROTO` at the `cardano-rpc/proto` directory of your checkout.

`cardano-rpc-provider.mjs`, a minimal MeshJS fetcher and submitter backed by cardano-rpc's v1beta gRPC API:

```js
// Implements the three MeshWallet/MeshTxBuilder hooks needed for building,
// signing, and submitting a plain payment transaction:
// fetchAddressUTxOs, fetchProtocolParameters, submitTx.

import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import { Address } from "@meshsdk/core-cst";
import { castProtocol } from "@meshsdk/core";

// Path to the UTxO RPC v1beta .proto sources vendored in this repository;
// override with CARDANO_RPC_PROTO when running from elsewhere.
const PROTO_ROOT = process.env.CARDANO_RPC_PROTO ?? "cardano-rpc/proto";

function loadService(protoFile, serviceLookup) {
  const packageDefinition = protoLoader.loadSync(protoFile, {
    keepCase: false,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
    includeDirs: [PROTO_ROOT],
  });
  const proto = grpc.loadPackageDefinition(packageDefinition);
  return serviceLookup(proto);
}

function promisify(client, method) {
  return (request) =>
    new Promise((resolve, reject) => {
      client[method](request, (err, response) => {
        if (err) reject(err);
        else resolve(response);
      });
    });
}

// BigInt fields are a oneof of {int, bigUInt, bigNInt}; testnet-scale values
// always fit in `int`.
function bigIntField(field) {
  return field?.int ?? "0";
}

function rationalToNumber(rational) {
  if (!rational || Number(rational.denominator) === 0) return 0;
  return Number(rational.numerator) / Number(rational.denominator);
}

export class CardanoRpcProvider {
  constructor(target) {
    const credentials = grpc.credentials.createInsecure();

    const QueryService = loadService(
      "utxorpc/v1beta/query/query.proto",
      (proto) => proto.utxorpc.v1beta.query.QueryService,
    );
    const SubmitService = loadService(
      "utxorpc/v1beta/submit/submit.proto",
      (proto) => proto.utxorpc.v1beta.submit.SubmitService,
    );

    this._query = new QueryService(target, credentials);
    this._submit = new SubmitService(target, credentials);
  }

  async fetchAddressUTxOs(bech32Address) {
    const addressBytes = Buffer.from(Address.fromBech32(bech32Address).toBytes(), "hex");
    const searchUtxos = promisify(this._query, "SearchUtxos");
    const response = await searchUtxos({
      predicate: { match: { cardano: { address: { exactAddress: addressBytes } } } },
    });
    return (response.items ?? []).map((item) => {
      const cardano = item.cardano;
      const amount = [{ unit: "lovelace", quantity: bigIntField(cardano.coin) }];
      for (const bundle of cardano.assets ?? []) {
        // @grpc/grpc-js hands back `bytes` fields as Buffers already; do not
        // re-decode them as base64: that corrupts the data.
        const policyId = Buffer.from(bundle.policyId).toString("hex");
        for (const asset of bundle.assets ?? []) {
          const assetName = Buffer.from(asset.name).toString("hex");
          amount.push({ unit: policyId + assetName, quantity: bigIntField(asset.outputCoin) });
        }
      }
      return {
        input: {
          txHash: Buffer.from(item.txoRef.hash).toString("hex"),
          outputIndex: Number(item.txoRef.index),
        },
        output: {
          address: bech32Address,
          amount,
        },
      };
    });
  }

  async fetchProtocolParameters() {
    const readParams = promisify(this._query, "ReadParams");
    const response = await readParams({});
    const p = response.values.cardano;
    return castProtocol({
      coinsPerUtxoSize: Number(bigIntField(p.coinsPerUtxoByte)),
      collateralPercent: Number(p.collateralPercentage),
      decentralisation: 0,
      keyDeposit: Number(bigIntField(p.stakeKeyDeposit)),
      maxBlockExMem: Number(p.maxExecutionUnitsPerBlock?.memory),
      maxBlockExSteps: Number(p.maxExecutionUnitsPerBlock?.steps),
      maxBlockHeaderSize: Number(p.maxBlockHeaderSize),
      maxBlockSize: Number(p.maxBlockBodySize),
      maxCollateralInputs: Number(p.maxCollateralInputs),
      maxTxExMem: Number(p.maxExecutionUnitsPerTransaction?.memory),
      maxTxExSteps: Number(p.maxExecutionUnitsPerTransaction?.steps),
      maxTxSize: Number(p.maxTxSize),
      maxValSize: Number(p.maxValueSize),
      minFeeA: Number(bigIntField(p.minFeeCoefficient)),
      minFeeB: Number(bigIntField(p.minFeeConstant)),
      minPoolCost: bigIntField(p.minPoolCost),
      poolDeposit: bigIntField(p.poolDeposit),
      priceMem: rationalToNumber(p.prices?.memory),
      priceStep: rationalToNumber(p.prices?.steps),
      minFeeRefScriptCostPerByte: rationalToNumber(p.minFeeScriptRefCostPerByte),
    });
  }

  async submitTx(txHex) {
    const submitTx = promisify(this._submit, "SubmitTx");
    const response = await submitTx({ tx: { raw: Buffer.from(txHex, "hex") } });
    return Buffer.from(response.ref).toString("hex");
  }
}
```

`send-lovelace.mjs`:

```js
import { readFileSync } from "node:fs";
import { MeshWallet, MeshTxBuilder } from "@meshsdk/core";
import { CardanoRpcProvider } from "./cardano-rpc-provider.mjs";

const RPC_URL = "localhost:50051";
const CLUSTER_DIR = "/tmp/demo-cluster";
const LOVELACE_TO_SEND = "5000000"; // 5 ADA (1 ADA = 1,000,000 lovelace)

function readCborHex(path) {
  const envelope = JSON.parse(readFileSync(path, "utf8"));
  return envelope.cborHex;
}

async function main() {
  const provider = new CardanoRpcProvider(RPC_URL);

  const paymentSkeyHex = readCborHex(`${CLUSTER_DIR}/utxo-keys/utxo1/utxo.skey`);
  const recipientAddress = readFileSync(`${CLUSTER_DIR}/utxo-keys/utxo2/utxo.addr`, "utf8").trim();

  const wallet = new MeshWallet({
    networkId: 0, // 0 = testnet
    fetcher: provider,
    submitter: provider,
    key: { type: "cli", payment: paymentSkeyHex },
  });
  await wallet.init();

  // cardano-testnet's genesis UTxO keys fund an ENTERPRISE address (payment
  // credential only). MeshWallet also derives a base address by pairing the
  // payment key with a placeholder stake key, and its address-lookup methods
  // default to that (unfunded) base address. Pass "enterprise" explicitly.
  const changeAddress = await wallet.getChangeAddress("enterprise");

  // Fetch UTxOs from the provider rather than wallet.getUnspentOutputs():
  // the wallet converts them to CSL-style objects that
  // MeshTxBuilder.selectUtxosFrom() does not accept.
  const utxos = await provider.fetchAddressUTxOs(changeAddress);

  console.log(`Sender address:    ${changeAddress}`);
  console.log(`Recipient address: ${recipientAddress}`);
  console.log(`Spendable UTxOs:   ${utxos.length}`);

  const protocolParams = await provider.fetchProtocolParameters();
  const txBuilder = new MeshTxBuilder({ params: protocolParams });

  const unsignedTx = await txBuilder
    .txOut(recipientAddress, [{ unit: "lovelace", quantity: LOVELACE_TO_SEND }])
    .changeAddress(changeAddress)
    .selectUtxosFrom(utxos)
    .complete();

  const signedTx = await wallet.signTx(unsignedTx);
  const txHash = await wallet.submitTx(signedTx);
  console.log(`Submitted tx: ${txHash}`);

  // Confirm by polling the recipient's UTxOs for the new output.
  const deadlineMs = Date.now() + 60_000;
  while (Date.now() < deadlineMs) {
    const recipientUtxos = await provider.fetchAddressUTxOs(recipientAddress);
    const newOutput = recipientUtxos.find((u) => u.input.txHash === txHash);
    if (newOutput) {
      const lovelace = newOutput.output.amount.find((a) => a.unit === "lovelace")?.quantity;
      console.log(
        `Confirmed: ${lovelace} lovelace landed at ${recipientAddress} (${txHash}#${newOutput.input.outputIndex})`,
      );
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }
  throw new Error("Timed out waiting for the new UTxO to appear at the recipient address");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
```

Run it (Node.js is available ad hoc via `nix shell nixpkgs#nodejs`):

```bash
node send-lovelace.mjs
```

Sample output (your addresses and hashes will differ):

```
Sender address:    addr_test1vp0cg0r2w9xczav4g0txn6suy9z0g24er7h25eqk639hwfgcmtj72
Recipient address: addr_test1vp0fsh3r9t3zmsfkv27qkwh66vudurnttpy80f8yjagxqyqz27px0
Spendable UTxOs:   1
Submitted tx: c8f9332364a81e687599a0b1c4599cd8bff0213c3a4c23a45a7d525ccc124018
Confirmed: 5000000 lovelace landed at addr_test1vp0fsh3r9t3zmsfkv27qkwh66vudurnttpy80f8yjagxqyqz27px0 (c8f9332364a81e687599a0b1c4599cd8bff0213c3a4c23a45a7d525ccc124018#0)
```

### Clean up

Stop the cluster and the socat bridge with Ctrl+C in their terminals, then remove the cluster directory:

```bash
rm -rf /tmp/demo-cluster
```

### Configuration reference

The gRPC server is off by default.
Enable it with `--grpc-enable` or `EnableRpc: true` in the cardano-node configuration; a node socket path must also be configured.

Exactly one transport is active at a time:

1. Unix socket (default): `rpc.sock` next to the node socket, or `--grpc-socket-path` / `RpcSocketPath`.
2. HTTP/2 cleartext: `--grpc-listen-port` / `RpcListenPort`, optionally `--grpc-listen-address` / `RpcListenAddress` (default `127.0.0.1`).
3. HTTP/2 with TLS: add `--grpc-tls-certificate` and `--grpc-tls-private-key` (`RpcTlsCertificateFile`, `RpcTlsPrivateKeyFile`), optionally repeatable `--grpc-tls-chain-certificate` (`RpcTlsChainCertificateFiles`).

The three transports are mutually exclusive.
TLS additionally requires a listen port, and its certificate and key must be set together; see the Security section below before exposing an endpoint beyond localhost.

Clients connect over TCP the same way as in the examples above: replace the Unix-socket connector or `unix://` target with the node's address and port.
