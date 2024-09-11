import {
  BlockPraos,
  C,
  Data,
  Datum,
  fromHex,
  fromText,
  OutRef,
  paymentCredentialOf,
  PolicyId,
  Signatory,
  toLabel,
  toText,
  Transaction,
  TransactionOutput,
} from "../../deps.ts";
import { assetsToAsssetsWithNumber, pipe } from "./utils.ts";
import { toAssets, toOwner } from "../../common/utils.ts";
import {
  AssetsWithNumber,
  BuyEventType,
  CancelBidEventType,
  CancelListingEventType,
  MarketplaceEventType,
  PointDB,
  SellEventType,
} from "./types.ts";
import { config } from "./flags.ts";
import { db } from "./db.ts";
import * as D from "../../common/contract.types.ts";
import { NebulaSpend } from "../../contract/src/nebula/plutus.ts";

function getDatum(tx: Transaction, output: TransactionOutput): Datum | null {
  if (output.datum) return output.datum;
  return tx.datums?.[output.datumHash!] || null;
}

function watchListingsAndBids(tx: Transaction, point: PointDB) {
  for (const [outputIndex, output] of tx.outputs.entries()) {
    if (!output.datumHash && !output.datum) continue;

    const outRef: OutRef = { txHash: tx.id, outputIndex };

    if (
      Boolean(output.value[config.bidPolicyId]) &&
      paymentCredentialOf(output.address).hash ===
        config.scriptHash
    ) {
      // Check bid
      const tradeDatum = Data.from(
        getDatum(tx, output)!,
        NebulaSpend.datum,
      );

      if (!("Bid" in tradeDatum)) continue;

      const bidDetails = tradeDatum.Bid[0];
      const owner = toOwner({
        data: bidDetails.owner,
      });
      const lovelace = parseInt(output.value.ada.lovelace.toString());

      const addBidAssets: AssetsWithNumber = Object.entries(output.value)
        .filter((
          [policyId, _],
        ) => policyId !== config.bidPolicyId || policyId !== "ada")
        .reduce(
          (acc, [policyId, assets]) => {
            for (const [name, quantity] of Object.entries(assets)) {
              acc[policyId + name] = Number(quantity);
            }
            return acc;
          },
          {} as AssetsWithNumber,
        );

      // We only track valid addBidAssets. We allow combinations of whitelisted project policy ids.
      if (
        !Object.keys(addBidAssets).every((unit) =>
          config.projects.some((projectPolicyId) =>
            unit.startsWith(projectPolicyId)
          )
        )
      ) continue;

      if ("SpecificValue" in bidDetails.requestedOption) {
        const assets: AssetsWithNumber = assetsToAsssetsWithNumber(
          Object.fromEntries(
            Object.entries(toAssets(
              bidDetails.requestedOption.SpecificValue[0],
            )).filter(([unit, _]) => unit !== "lovelace"),
          ),
        );

        const units = Object.keys(assets);

        // We only track valid specific bids. We allow combinations of whitelisted project policy ids.
        if (
          !units.every((unit) =>
            config.projects.some((projectPolicyId) =>
              unit.startsWith(projectPolicyId)
            )
          )
        ) continue;

        const type: MarketplaceEventType = Object.keys(addBidAssets).length > 0
          ? "BidSwap"
          : units.length > 1
          ? "BidBundle"
          : "BidSingle";

        db.addBid({
          outRef,
          point,
          type,
          assets,
          owner,
          lovelace,
          addBidAssets,
        });
        db.registerEvent({
          type,
          data: {
            txHash: outRef.txHash,
            slot: point.slot,
            assets: assets,
            owner,
            lovelace,
            addBidAssets,
          },
        }, point);
      } else if (
        "SpecificPolicyIdWithConstraints" in bidDetails.requestedOption
      ) {
        const policyId: PolicyId =
          bidDetails.requestedOption.SpecificPolicyIdWithConstraints[0];
        // We only track valid open bids.
        if (
          !config.projects.some((projectPolicyId) =>
            projectPolicyId === policyId
          )
        ) continue;

        const types = bidDetails.requestedOption
          .SpecificPolicyIdWithConstraints[1].map((
            bytes,
          ) => toText(bytes));
        const traits =
          bidDetails.requestedOption.SpecificPolicyIdWithConstraints[2]?.map((
            trait,
          ) =>
            "Included" in trait
              ? { negation: false, trait: toText(trait.Included[0]) }
              : { negation: true, trait: toText(trait.Excluded[0]) }
          ) || null;

        const type: MarketplaceEventType = "BidOpen";

        const constraints = { types, traits };

        db.addBid({
          outRef,
          point,
          type,
          policyId,
          constraints,
          owner,
          lovelace,
          addBidAssets,
        });

        db.registerEvent({
          type,
          data: {
            txHash: outRef.txHash,
            slot: point.slot,
            policyId,
            constraints,
            owner,
            lovelace,
            addBidAssets,
          },
        }, point);
      }
      db.updateCheckpoint("Bid", point);
    } else if (
      config.projects.some((projectPolicyId) =>
        Boolean(output.value[projectPolicyId])
      ) &&
      paymentCredentialOf(output.address).hash ===
        config.scriptHash
    ) {
      // Check listing
      const tradeDatum = Data.from(
        getDatum(tx, output)!,
        NebulaSpend.datum,
      );
      if (!("Listing" in tradeDatum)) continue;

      const listingDetails = tradeDatum.Listing[0];

      const assets: AssetsWithNumber = Object.entries(output.value)
        .filter(([policyId, _]) => policyId !== "ada")
        .reduce(
          (acc, [policyId, assets]) => {
            for (const [name, quantity] of Object.entries(assets)) {
              if (name.endsWith(toLabel(2) + fromText("ScriptOwner"))) continue;
              acc[policyId + name] = Number(quantity);
            }
            return acc;
          },
          {} as AssetsWithNumber,
        );

      const units = Object.keys(assets);

      // We only track valid listings. We allow combinations of whitelisted project policy ids.
      if (
        !units.every((unit) =>
          config.projects.some((projectPolicyId) =>
            unit.startsWith(projectPolicyId)
          )
        )
      ) continue;

      const type: MarketplaceEventType = units.length > 1
        ? "ListingBundle"
        : "ListingSingle";

      const owner = toOwner({
        data: listingDetails.owner,
      });
      const lovelace = parseInt(
        listingDetails.requestedLovelace.toString(),
      );
      const privateListing = listingDetails.privateListing
        ? toOwner({ data: listingDetails.privateListing })
        : null;

      db.addListing({
        outRef,
        point,
        type,
        assets,
        owner,
        lovelace,
        privateListing,
      });

      db.registerEvent({
        type,
        data: {
          txHash: outRef.txHash,
          slot: point.slot,
          assets,
          owner,
          lovelace,
        },
      }, point);

      db.updateCheckpoint("Listing", point);
    }
  }
}

function watchSalesAndCancellations(tx: Transaction, point: PointDB) {
  if (!tx.redeemers) return;

  for (const { redeemer, validator: { purpose, index } } of tx.redeemers) {
    if (purpose !== "spend") continue;

    const outRef: OutRef = {
      txHash: tx.inputs[index].transaction.id,
      outputIndex: tx.inputs[index].index,
    };

    const action = (() => {
      try {
        return Data.from(redeemer, NebulaSpend.action);
      } catch (_e) {
        return null;
      }
    })();

    switch (action) {
      case "Sell": {
        const bid = db.getBid(outRef);
        if (!bid) break;
        const type: SellEventType = (() => {
          switch (bid.type) {
            case "BidSingle":
              return "SellSingle";
            case "BidBundle":
              return "SellBundle";
            case "BidOpen":
              return "SellSingle";
            case "BidSwap":
              return "SellSwap";
          }
        })();

        const paymentDatum = Data.to({
          outRef: {
            transactionId: { hash: outRef.txHash },
            outputIndex: BigInt(outRef.outputIndex),
          },
        }, D.PaymentDatum);

        const assets = bid.policyId
          ? tx.outputs.reduce((acc, utxo) => {
            const assets = utxo.value[bid.policyId!];
            if (!assets || utxo.datum !== paymentDatum) return acc;
            for (const [name, quantity] of Object.entries(assets)) {
              if (quantity > 0n) acc[bid.policyId! + name] = Number(quantity);
            }
            return acc;
          }, bid.assets || {})
          : bid.assets;

        /**
         * If there is no vkey signature then we cannot identify the seller. For now we leave it as null/unknown.
         */
        const seller = pipe(
          Object.keys(tx.signatories),
          (vkeys: Signatory[]) =>
            vkeys.length <= 0 ? null : C.Vkey.from_bytes(
              fromHex(vkeys[0].key),
            ).public_key().hash().to_bech32("addr_vkh"),
        );

        db.addSale({
          txHash: tx.id,
          point,
          type,
          assets: assets!,
          lovelace: bid.lovelace,
          addBidAssets: bid.addBidAssets,
          seller,
          buyer: bid.owner,
        });
        db.registerEvent({
          type: type,
          data: {
            txHash: tx.id,
            slot: point.slot,
            assets,
            lovelace: bid.lovelace,
            addBidAssets: bid.addBidAssets,
            seller,
            buyer: bid.owner,
          },
        }, point);
        db.spendBid(outRef);
        db.updateCheckpoint("Sale", point);
        break;
      }
      case "Buy": {
        const listing = db.getListing(outRef);
        if (!listing) break;
        const type: BuyEventType = (() => {
          switch (listing.type) {
            case "ListingSingle":
              return "BuySingle";
            case "ListingBundle":
              return "BuyBundle";
          }
        })();

        /**
         * If there is no signature then we cannot identify the buyer. For now we leave it as null/unknown.
         * If there is one signature we can precisely identify the buyer.
         */

        const buyer = pipe(
          Object.keys(tx.signatories),
          (vkeys: Signatory[]) =>
            vkeys.length <= 0 ? null : C.Vkey.from_bytes(
              fromHex(vkeys[0].key),
            ).public_key().hash().to_bech32("addr_vkh"),
        );

        db.addSale({
          txHash: tx.id,
          point,
          type,
          assets: listing.assets,
          lovelace: listing.lovelace,
          seller: listing.owner,
          buyer,
        });
        db.registerEvent({
          type: type,
          data: {
            txHash: tx.id,
            slot: point.slot,
            assets: listing.assets,
            lovelace: listing.lovelace,
            seller: listing.owner,
            buyer,
          },
        }, point);
        db.spendListing(outRef);
        db.updateCheckpoint("Sale", point);
        break;
      }
      case "Cancel": {
        const listing = db.getListing(outRef);
        if (listing) {
          const type: CancelListingEventType = (() => {
            switch (listing.type) {
              case "ListingSingle":
                return "CancelListingSingle";
              case "ListingBundle":
                return "CancelListingBundle";
            }
          })();
          db.addCancellation({
            txHash: tx.id,
            point,
            type,
            assets: listing.assets,
            owner: listing.owner,
            lovelace: listing.lovelace,
          });
          db.registerEvent({
            type: type,
            data: {
              txHash: tx.id,
              slot: point.slot,
              owner: listing.owner,
              assets: listing.assets,
              lovelace: listing.lovelace,
            },
          }, point);
          db.spendListing(outRef);
          db.updateCheckpoint("Cancel", point);
          break;
        }
        const bid = db.getBid(outRef);
        if (bid) {
          const type: CancelBidEventType = (() => {
            switch (bid.type) {
              case "BidSingle":
                return "CancelBidSingle";
              case "BidBundle":
                return "CancelBidBundle";
              case "BidOpen":
                return "CancelBidOpen";
              case "BidSwap":
                return "CancelBidSwap";
            }
          })();
          db.addCancellation({
            txHash: tx.id,
            point,
            type,
            assets: bid.assets,
            policyId: bid.policyId,
            constraints: bid.constraints,
            owner: bid.owner,
            lovelace: bid.lovelace,
            addBidAssets: bid.addBidAssets,
          });
          db.registerEvent({
            type: type,
            data: {
              txHash: tx.id,
              slot: point.slot,
              owner: bid.owner,
              assets: bid.assets,
              policyId: bid.policyId,
              constraints: bid.constraints,
              lovelace: bid.lovelace,
              addBidAssets: bid.addBidAssets,
            },
          }, point);
          db.spendBid(outRef);
          db.updateCheckpoint("Cancel", point);
          break;
        }
        break;
      }
    }
  }
}

/** In case of malformed listings/bids we want to make sure the watcher does not go down. */
function tryWatch(
  tx: Transaction,
  point: PointDB,
  watcher: (tx: Transaction, point: PointDB) => unknown,
) {
  try {
    watcher(tx, point);
  } catch (e) {
    console.log(e);
  }
}

export function watchBlock(block: BlockPraos) {
  const transactions = block.transactions || [];
  const point: PointDB = {
    hash: block.id,
    slot: block.slot,
  };
  for (const tx of transactions) {
    tryWatch(tx, point, watchSalesAndCancellations);
    tryWatch(tx, point, watchListingsAndBids);
  }
}
