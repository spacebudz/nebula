<p align="center">
  <img width="190px" src="./assets/nebula.svg" align="center"/>
  <h1 align="center">Nebula</h1>
  <p align="center">A Cardano NFT marketplace contract including chain indexer and event listener for individual projects.</p>
</p>

## Requirements

- [Deno](https://deno.land/) $\ge$ Version 1.28.3
- [Aiken](https://github.com/aiken-lang/aiken.git) (`cargo install --git https://github.com/aiken-lang/aiken.git --rev ae981403c67adf6399695c0832e854865c621fcb`)

## Installation (Contract)

### Deno
```js
import { Contract } from "https://deno.land/x/nebula@1.1.0/contract/mod.ts";
```

### NPM
```
npm install @spacebudz/nebula
```

## Quick start

1. Import `Contract` and `Lucid` and create royalty/fee token.
**Note**: The ideal way to handle the royalty token is to have it under the same `policy id` as the collection. This will make the authentication process smoother and more efficient. However, Nebula allows for specifying a different `policy id` if necessary. If you have a royalty token already you can skip the step of the royalty token creation.

```ts
import { Contract } from "https://deno.land/x/nebula@1.1.0/contract/mod.ts"
import { Lucid, Blockfrost } from "https://deno.land/x/lucid@0.10.6/mod.ts"

const lucid = await Lucid.new(
  new Blockfrost(
    "https://cardano-preprod.blockfrost.io/api/v0",
    "<project_id>",
  ),
  "Preprod",
);

lucid.selectWalletFromSeed(
  "<seed_phrase>",
);

const owner = "addr...";

const txHash = await Contract.createRoyalty(
  lucid,
  [{
    address:
      "addr...",
    fee: 0.016, // 1.6%
  }], 
  owner,
);
console.log(txHash);
```

This creates a unique royalty token and sends it to a script address controlled by the owner. The output contains the royalty/fee information. After calling `Contract.createRoyalty(..)` you should see a message in the terminal including the `royalty token`. Paste it into the Contract config as described in the next step.

2. Instantiate the contract and deploy reference scripts.

```ts
const contract = new Contract(lucid, {
  royaltyToken: "<royalty_token>",
  owner, // Make sure you use the same owner here as in Contract.createRoyalty(..)!
  policyId: "<policy_id_of_your_nft_project>",
});

console.log(await contract.deployScripts());
```

After calling `contract.deployScripts()` you should see a message in the terminal including the `tx hash` of the deployment of the scripts. Paste it into the Contract config as described in the next step.

3. Re-instantiate the contract with reference scripts.

```ts
const contract = new Contract(lucid, {
  royaltyToken: "<royalty_token>",
  owner, // Make sure you use the same owner here as the one in Contract.createRoyalty(..)!
  policyId: "<policy_id_of_your_nft_project>",
  deployHash: "<deploy_hash>",
});
```

Now the contract is initialised.\
**Make sure you don't change the configuration as it could change the script hashes!**

Time to play with the marketplace!

Place a bid (on SpaceBud #10):
```ts
console.log(await contract.bid([idToBud(10)], 5000000000n));
```

Accept bid (sell):
```ts
const [bid] = await contract.getBids(idToBud(10));
console.log(await contract.sell([{ bidUtxo: bid }]));
```

List an NFT (SpaceBud #10):
```ts
console.log(await contract.list([idToBud(10)], 6000000000n));
```

Buy:
```ts
const [listing] = await contract.getListings(idToBud(10));
console.log(await contract.buy([listing]));
```

Place a floor/open bid with optional constraints (this only works if your NFT is CIP-0068 compliant):
```ts
console.log(
  await contract.bidOpen(10000000000n, {
    types: ["Bear"],
    traits: [{ trait: "Hockey Stick" }],
  }),
);
```

Accept open bid (with SpaceBud #650 as it is a Bear and has a Hockey Stick):
```ts
const [bid] = await contract.getBids("Open");
console.log(await contract.sell([{ bidUtxo: bid, assetName: idToBud(650) }]));
```

And much more is possible!

## Nebula Watcher

If you want to keep track of historic data or want to index marketplace data or want to listen to certain events, then you may want to run the watcher.\
It is not a requirement to run the core of the marketplace.

### Requirements

- [Deno](https://deno.land/) $\ge$ Version 1.28.3
- [Ogmios](https://ogmios.dev/) $\ge$ Version 5.5.7
- Active connection to a Cardano node with Ogmios as bridge.

1. Set up the `config.ts` file:

**Tip**: Call `contract.getContractHashes()` on your Contract instance to get all the relevant hashes you need for the config.

```ts
import {
  BidAndListingEventData,
  BidOpenEventData,
  BidSwapEventData,
  Config,
  MarketplaceEvent,
  SaleEventData,
} from "https://deno.land/x/nebula@1.1.0/watcher/src/types.ts";


/** 
 * Run 'contract.getContractHashes()' on your Contract instance to get all the relevant hashes you need for the config.
 */
export const config: Config = {
  scriptHash: "<script_hash>",
  bidPolicyId: "<bid_policy_id>",
  projects: ["<nft_policy_id>"],
};

// optionally handle events
export function eventsHandler(events: MarketplaceEvent[]) {
  for (const event of events) {
    switch (event.type) {
      case "BidBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "BidOpen": {
        const eventData: BidOpenEventData = event.data;
        // Your logic here
        break;
      }
      case "BidSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "ListingBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "ListingSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "BuyBundle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "BuySingle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "SellBundle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "SellSingle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "SellSwap": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidOpen": {
        const eventData: BidOpenEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelListingBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelListingSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidSwap": {
        const eventData: BidSwapEventData = event.data;
        // Your logic here
        break;
      }
    }
  }
}

export function onChange() {
  // optionally handle db changes
}
```

2. Start the watcher:

```
deno run -A https://deno.land/x/nebula@1.1.0/watcher/mod.ts --ogmios-url ws://localhost:1337 --database ./marketplace.sqlite --config ./config.ts
```

<img width="100%" src="./assets/watcher.png" align="center"/>

## Nebula Querier

Run the querier: 

```
deno run -A https://deno.land/x/nebula@1.1.0/watcher/querier.ts --database ./marketplace.sqlite
```

Runs on port `3000` by default. It hosts the database and allows you to make simple queries. The API will likely be extended and improved over time.

## Nebula Contract

To execute the below listed commands you need to be in the `contract` directory.

### Compile contract

```
deno task build:contract
```

### Bundle for NPM/Node

```
deno task build
```
Outputs a `dist` folder at `./contract/dist`.

### Test off-chain endpoints

```
deno task test
```

### Test contract

```
deno task test:contract
```

### Royalty info specification

The ideal way to handle the royalty token is to have it under the same `policy id` as the collection. This will make the authentication process smoother and more efficient. However, Nebula allows for specifying a different `policy id` if necessary.\
The `asset name` **must** be `001f4d70526f79616c7479` (hex encoded), it contains the [CIP-0067](https://github.com/cardano-foundation/CIPs/blob/master/CIP-0067/README.md) label `500`.

The royalty info datum is specified as follows (CDDL):

```cddl
big_int = int / big_uint / big_nint
big_uint = #6.2(bounded_bytes)
big_nint = #6.3(bounded_bytes)

optional_big_int = #6.121([big_int]) / #6.122([])

royalty_recipient = #6.121([
              address,                    ; definition can be derived from: 
                                          ; https://github.com/input-output-hk/plutus/blob/master/plutus-ledger-api/src/PlutusLedgerApi/V1/Address.hs#L31
              int,                        ; variable fee ( calculation: ⌊1 / (fee / 10)⌋ ); integer division with precision 10
              optional_big_int,           ; min fee (absolute value in lovelace)
              optional_big_int,           ; max fee (absolute value in lovelace)
            ])

royalty_recipients = [ * royalty_recipient ]

; version is of type int, we start with version 1
version = 1  

; Custom user defined plutus data.
; Setting data is optional, but the field is required
; and needs to be at least Unit/Void: #6.121([])
extra = plutus_data

royalty_info = #6.121([royalty_recipients, version, extra])
```

### Collection offer constraints specification

To take advantage of collection offers with constraints, your NFT collection needs to comply with [CIP-0068](https://github.com/cardano-foundation/CIPs/blob/master/CIP-0068/README.md). The metadata **must** contain two additional key/value pairs (CDDL):
```
{ 
  ...
  type => bounded_bytes, ; UTF-8
  traits => [ * bounded_bytes ] ; UTF-8
}
```
Example (JSON):
```json
{
  "image": "ipfs://..",
  "name": "SpaceBud #650",
  "type": "Bear",
  "traits": ["Chestplate", "Belt"]
}
```

### Protocol fee

Nebula charges by default a protocol fee for each sale, which is currently about `0.9 ADA` (the minimum ADA by protocol parameters and it is adjusted automatically when the protocol parameters change). We appreciate all support to fund the development of Nebula. If you want to disable the protocol fee set the flag `fundProtocol` to `false` when instantiating the `Contract`.


## Todo

- [ ] Improve and extend documentation.
