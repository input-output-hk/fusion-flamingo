# Quickstart draft for cardano-rpc

Target home: a "Quickstart" section near the top of `cardano-rpc/README.md` (which already has the spec coverage table and security section; do not duplicate those).

Every command and code block below was verified against live cluster runs on 2026-09-09 (the transaction example three times end to end).
Remaining follow-ups:

1. Once server reflection lands, drop the `--schema` / `-proto` / `-import-path` flags and the checkout requirement from the call examples.
2. The cluster snippet uses the `mgalazyn/cardano-testnet-nix-wrapper` branch, whose cardano-testnet package bundles the node and CLI binaries (verified working three times on a clean output dir); swap the ref to plain `github:IntersectMBO/cardano-node` once the wrapper lands on master.
   An earlier one-off failure (`genesis-input.conway.json: openBinaryFile: does not exist`) was traced to stale state from a previous run, not the wrapper.
3. Candidate upstream fixes: make cardano-testnet fall back to PATH for `CARDANO_NODE`/`CARDANO_CLI` (helps non-nix users), and a TCP listener option for `--enable-grpc`.
4. There is no utxorpc module on buf.build (checked; the spec repo does not publish to the BSR), so local protos are required until reflection ships.
5. The published JS u5c SDK stack speaks `utxorpc.v1alpha.*` only; cardano-rpc implements `v1beta`, so the off-the-shelf providers fail with UNIMPLEMENTED on every call.
   Root cause is `@utxorpc/spec`'s barrel exporting only v1alpha (the v1beta sources ship unreferenced); the fix is draft PR utxorpc/spec#209, with #208 stacked on it.
   The quickstart ships a small hand-rolled v1beta provider until that merges and the SDKs bump.

---

## Quickstart

cardano-rpc is cardano-node's built-in gRPC interface, implementing the [UTxO RPC](https://utxorpc.org) spec.
The examples use the proto files vendored in this repository, so clone it and run everything from the repository root.

### Start a local cluster

The cardano-testnet package below bundles the matching cardano-node and cardano-cli binaries, so one command is enough:

```bash
nix run "github:IntersectMBO/cardano-node/mgalazyn/cardano-testnet-nix-wrapper#cardano-testnet" -- \
  cardano --num-pool-nodes 1 --enable-grpc --output-dir /tmp/demo-cluster
```

This starts a testnet with a single block-producing cardano-node, gRPC server enabled, and keeps it running until Ctrl+C.
The RPC endpoint is a unix socket at `/tmp/demo-cluster/socket/node1/rpc.sock`, next to cardano-node's IPC socket.
The cluster comes with funded genesis wallets under `/tmp/demo-cluster/utxo-keys/utxo{1,2,3}/` (`utxo.skey`, `utxo.vkey`, `utxo.addr`); the transaction example below spends from `utxo1`.
To use your own binaries instead of the bundled ones, export `CARDANO_NODE` and `CARDANO_CLI` with their paths before running.

Three things to mind:

1. Flag names differ between the two CLIs: `cardano-testnet` takes `--enable-grpc`, `cardano-node` itself takes `--grpc-enable`.
2. The output directory must not exist from a previous run; genesis creation fails on leftovers (`Genesis output directory already exists`).
   Run `rm -rf /tmp/demo-cluster` first when retrying, and make sure no cardano-node processes from an earlier attempt are still alive.
3. Unix socket paths are capped at 108 bytes on Linux, and cardano-testnet fails at startup (`pokeSockAddr: path is too long`) when the output directory is nested too deep.
   Keep `--output-dir` shallow, e.g. under `/tmp`.

### Make your first call

With [buf](https://buf.build/docs/installation), from the repository root:

```bash
buf curl --unix-socket /tmp/demo-cluster/socket/node1/rpc.sock \
  --schema cardano-rpc/proto --protocol grpc --http2-prior-knowledge \
  http://localhost/utxorpc.v1beta.sync.SyncService/ReadTip
```

Then read the protocol parameters:

```bash
buf curl --unix-socket /tmp/demo-cluster/socket/node1/rpc.sock \
  --schema cardano-rpc/proto --protocol grpc --http2-prior-knowledge -d '{}' \
  http://localhost/utxorpc.v1beta.query.QueryService/ReadParams
```

With grpcurl instead:

```bash
grpcurl -unix -plaintext \
  -import-path cardano-rpc/proto -proto utxorpc/v1beta/sync/sync.proto \
  /tmp/demo-cluster/socket/node1/rpc.sock \
  utxorpc.v1beta.sync.SyncService/ReadTip
```

### Build and submit a transaction with MeshJS

The example sends 5 ADA from the cluster's `utxo1` genesis wallet to the `utxo2` address, using [MeshJS](https://meshjs.dev) for wallet handling and transaction building and cardano-rpc for UTxO queries, protocol parameters and submission.
`@grpc/grpc-js` connects straight to the unix socket, so no TCP bridge is needed.

Mind that `@meshsdk/provider`'s off-the-shelf `U5CProvider` does not work against cardano-rpc: it is pinned to `@utxorpc/sdk` 0.6.x, which speaks the older `utxorpc.v1alpha` services, while cardano-rpc serves `v1beta`.
Until the SDKs move to v1beta, the small provider below talks v1beta directly by loading the proto files at runtime.

Dependencies (versions verified):

```json
{
  "@grpc/grpc-js": "1.14.4",
  "@grpc/proto-loader": "0.8.1",
  "@meshsdk/core": "1.9.1",
  "@meshsdk/core-cst": "1.9.1"
}
```

`cardano-rpc-provider.mjs`, a minimal MeshJS fetcher and submitter backed by cardano-rpc's v1beta gRPC API:

```js
// Implements the three MeshWallet/MeshTxBuilder hooks needed for building,
// signing and submitting a plain payment transaction:
// fetchAddressUTxOs, fetchProtocolParameters, submitTx.

import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import { Address } from "@meshsdk/core-cst";
import { castProtocol } from "@meshsdk/core";

// Path to the UTxORPC v1beta .proto sources vendored in this repository.
const PROTO_ROOT = "cardano-rpc/proto";

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
  constructor(socketPath) {
    const target = `unix://${socketPath}`;
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
        // re-decode them as base64, that corrupts the data.
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

const RPC_SOCKET = "/tmp/demo-cluster/socket/node1/rpc.sock";
const CLUSTER_DIR = "/tmp/demo-cluster";
const LOVELACE_TO_SEND = "5000000"; // 5 ADA

function readCborHex(path) {
  const envelope = JSON.parse(readFileSync(path, "utf8"));
  return envelope.cborHex;
}

async function main() {
  const provider = new CardanoRpcProvider(RPC_SOCKET);

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

  // cardano-rpc does not implement WaitForTx yet, so confirm by polling the
  // recipient's UTxOs for the new output instead of Mesh's onTxConfirmed.
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

Sample output from a real run:

```
Sender address:    addr_test1vp0cg0r2w9xczav4g0txn6suy9z0g24er7h25eqk639hwfgcmtj72
Recipient address: addr_test1vp0fsh3r9t3zmsfkv27qkwh66vudurnttpy80f8yjagxqyqz27px0
Spendable UTxOs:   1
Submitted tx: c8f9332364a81e687599a0b1c4599cd8bff0213c3a4c23a45a7d525ccc124018
Confirmed: 5000000 lovelace landed at addr_test1vp0fsh3r9t3zmsfkv27qkwh66vudurnttpy80f8yjagxqyqz27px0 (c8f9332364a81e687599a0b1c4599cd8bff0213c3a4c23a45a7d525ccc124018#0)
```

For tools that need a TCP endpoint instead of the unix socket, bridge with `socat TCP-LISTEN:50051,fork,reuseaddr UNIX-CONNECT:/tmp/demo-cluster/socket/node1/rpc.sock`.

### Configuration reference

The gRPC server is off by default.
Enable it with `--grpc-enable` or `EnableRpc: true` in the cardano-node configuration; a node socket path must also be configured.

Exactly one transport is active at a time:

1. Unix socket (default): `rpc.sock` next to the node socket, or `--grpc-socket-path` / `RpcSocketPath`.
2. HTTP/2 cleartext: `--grpc-listen-port` / `RpcListenPort`, optionally `--grpc-listen-address` / `RpcListenAddress` (default `127.0.0.1`).
3. HTTP/2 with TLS: add `--grpc-tls-certificate` and `--grpc-tls-private-key` (`RpcTlsCertificateFile`, `RpcTlsPrivateKeyFile`), optionally repeatable `--grpc-tls-chain-certificate` (`RpcTlsChainCertificateFiles`).

The socket options are mutually exclusive with the port and TLS options; TLS requires a listen port; certificate and key must be set together.
