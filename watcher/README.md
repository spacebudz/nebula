# Nebula Watcher

Nebula Watcher indexes data from the chain for the marketplace in an sqlite
database. It handles rollbacks and emits events. Additionaly there is a small
query server (Nebula Querier), which lets you query the sqlite database as file,
but also allows you to make queries directly to retrieve data from the
marketplace (Right now it's very basic, but it will be extended over time).

## Requirements

- [Ogmios](https://ogmios.dev/) $\ge$ Version 6.5.0

## SQL Schema

- We store lovelace as `number` not as `bigint` in JavaScript since sqlite
  doesn't support bigints. And `number` is sufficient for now.

```sql
CREATE TABLE IF NOT EXISTS listings (
    outputReference TEXT PRIMARY KEY, -- tx hash + output index
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    spent BOOLEAN DEFAULT FALSE,
    listingType TEXT NOT NULL, -- SingleListing | BundleListing
    assets TEXT NOT NULl, -- { [policy id + asset name] : quantity } (nft or semi fungible) - offered
    owner TEXT NOT NULL, -- payment credential bech32
    lovelace INTEGER NOT NULL, -- requested
    privateListing TEXT -- ? payment credential bech32
);

CREATE TABLE IF NOT EXISTS bids (
    outputReference TEXT PRIMARY KEY, -- tx hash + output index
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    spent BOOLEAN DEFAULT FALSE,
    bidType TEXT NOT NULL, -- BidSingle | BidBundle | BidOpen
    assets TEXT, -- ? { [policy id + asset name] : quantity } (nft or semi fungible) - requested
    policyId TEXT, -- ? only policy id (open bid) - requested
    constraints TEXT, -- ? constraints (open bid) e.g. {types: ["Lion"], traits: ["Axe", "Jo-Jo"]}
    owner TEXT NOT NULL, -- payment credential bech32
    lovelace INTEGER NOT NULL,
    addBidAssets TEXT -- ? Additional assets stored next to lovelace in the bid UTxO. This could be used for NFT <> NFT trades - offered
);

CREATE TABLE IF NOT EXISTS sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    txHash TEXT, -- tx hash
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    saleType TEXT NOT NULL, -- BuySingle | BuyBundle | SellSingle | SellBundle | SellSwap
    assets TEXT NOT NULL, -- { [policy id + asset name] : quantity } (nft or semi fungible)
    lovelace INTEGER NOT NULL,
    addBidAssets TEXT, -- ? (SellSwap only) Additional assets stored next to lovelace in the bid UTxO. This could be used for NFT <> NFT trades - offered
    buyer TEXT, -- ? payment credential bech32
    seller TEXT -- ? payment credential bech32
);

CREATE TABLE IF NOT EXISTS cancellations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    txHash TEXT, -- tx hash
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    cancelType TEXT NOT NULL, -- CancelBidSingle | CancelBidBundle | CancelBidOpen | CancelListingSingle | CancelListingBundle | CancelBidSwap
    assets TEXT, -- ? { [policy id + asset name] : quantity } (nft or semi fungible)
    policyId TEXT, -- ? policy id (open bid)
    constraints TEXT, -- ? constraints (open bid) e.g. {types: ["Lion"], traits: ["Axe", "Jo-Jo"]}
    owner TEXT NOT NULL, -- payment credential bech32
    lovelace INTEGER NOT NULL,
    addBidAssets TEXT -- ? (CancelBidSwap only) Additional assets stored next to lovelace in the bid UTxO. This could be used for NFT <> NFT trades - offered
);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    eventType TEXT NOT NULL,
    eventData TEXT NOT NULL
);

CREATE VIEW IF NOT EXISTS activity AS SELECT * FROM (
SELECT slot, SUBSTRING(outputReference, 0, 65) AS txHash, assets, listingType AS activityType, lovelace, NULL AS policyId, NULL AS addBidAssets FROM listings
UNION 
SELECT slot, SUBSTRING(outputReference, 0, 65) AS txHash, assets, bidType AS activityType, lovelace, policyId, addBidAssets FROM bids
UNION
SELECT slot, txHash, assets, saleType AS activityType, lovelace, NULL AS policyId, addBidAssets FROM sales
UNION
SELECT slot, txHash, assets, cancelType AS activityType, lovelace, policyId, addBidAssets FROM cancellations
) ORDER BY slot DESC limit 100;

CREATE TABLE IF NOT EXISTS checkpoint (
    id INTEGER PRIMARY KEY,
    point TEXT NOT NULL,
    cleanupPoint TEXT NOT NULL
);
```
