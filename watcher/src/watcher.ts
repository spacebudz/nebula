import {
  BlockShelleyCompatible,
  C,
  Data,
  Datum,
  fromHex,
  getAddressDetails,
  OutRef,
  Point,
  PolicyId,
  toText,
  TxShelleyCompatible,
} from "../../deps.ts";
import { pipe, transformArrayToString } from "./utils.ts";
import { toAssets, toOwner } from "../../common/utils.ts";
import {
  BuyEventType,
  CancelBidEventType,
  CancelListingEventType,
  MarketplaceEventType,
  SellEventType,
} from "./types.ts";
import { config } from "./flags.ts";
import { db } from "./db.ts";
import * as D from "../../common/contract.types.ts";

// deno-lint-ignore no-explicit-any
function getDatum(tx: TxShelleyCompatible, output: any): Datum | null {
  if (output.datum) return output.datum;
  return tx.witness.datums?.[output.datumHash] || null;
}

function watchListingsAndBids(tx: TxShelleyCompatible, point: Point) {
  for (const [outputIndex, output] of tx.body.outputs.entries()) {
    if (!output.datumHash && !output.datum) continue;

    const outRef: OutRef = { txHash: tx.id, outputIndex };

    if (
      Object.keys(output.value.assets || {}).find((unit) =>
        unit.startsWith(config.bidPolicyId)
      ) &&
      getAddressDetails(output.address).paymentCredential?.hash ===
        config.scriptHash
    ) {
      // Check bid
      const tradeDatum = Data.from<D.TradeDatum>(
        getDatum(tx, output)!,
        D.TradeDatum,
      );

      if (!("Bid" in tradeDatum)) continue;

      const bidDetails = tradeDatum.Bid[0];
      const owner = toOwner({
        data: bidDetails.owner,
      });
      const lovelace = parseInt(output.value.coins.toString());

      if ("SpecificValue" in bidDetails.requestedOption) {
        const nfts = Object.keys(toAssets(
          bidDetails.requestedOption.SpecificValue[0],
        )).filter((unit) => unit !== "lovelace");

        // We only track valid specific bids. We allow combinations of whitelisted project policy ids.
        if (
          !nfts.every((unit) =>
            config.projects.some((projectPolicyId) =>
              unit.startsWith(projectPolicyId)
            )
          )
        ) continue;

        const type: MarketplaceEventType = nfts.length > 1
          ? "BidBundle"
          : "BidSingle";

        db.addBid({
          outRef,
          point,
          type,
          nfts,
          owner,
          lovelace,
        });
        db.registerEvent({
          type,
          data: {
            txHash: outRef.txHash,
            slot: point.slot,
            nfts: transformArrayToString(nfts),
            owner,
            lovelace,
          },
        }, point);
      } else if (
        "SpecificSymbolWithConstraints" in bidDetails.requestedOption
      ) {
        const policyId: PolicyId =
          bidDetails.requestedOption.SpecificSymbolWithConstraints[0];
        // We only track valid open bids.
        if (
          !config.projects.some((projectPolicyId) =>
            projectPolicyId === policyId
          )
        ) continue;

        const types =
          (bidDetails.requestedOption.SpecificSymbolWithConstraints[1]).map((
            bytes,
          ) => toText(bytes));
        const traits =
          (bidDetails.requestedOption.SpecificSymbolWithConstraints[2]).map((
            trait,
          ) =>
            "Included" in trait
              ? { negation: false, trait: toText(trait.Included[0]) }
              : { negation: true, trait: toText(trait.Excluded[0]) }
          );

        const type: MarketplaceEventType = "BidOpen";

        const constraints = { types, traits };

        db.addBid({
          outRef,
          point,
          type: "BidOpen",
          policyId,
          constraints,
          owner,
          lovelace,
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
          },
        }, point);
      }
      db.updateCheckpoint("Bid", point);
    } else if (
      Object.keys(output.value.assets || {}).find((unit) =>
        config.projects.some((projectPolicyId) =>
          unit.startsWith(projectPolicyId)
        )
      ) &&
      getAddressDetails(output.address).paymentCredential?.hash ===
        config.scriptHash
    ) {
      // Check listing
      const tradeDatum = Data.from<D.TradeDatum>(
        getDatum(tx, output)!,
        D.TradeDatum,
      );
      if (!("Listing" in tradeDatum)) continue;

      const listingDetails = tradeDatum.Listing[0];

      const nfts = Object.keys(output.value.assets!).map((unit) =>
        unit.replace(".", "")
      ).filter((unit) => !unit.endsWith("ScriptOwner"));

      // We only track valid listings. We allow combinations of whitelisted project policy ids.
      if (
        !nfts.every((unit) =>
          config.projects.some((projectPolicyId) =>
            unit.startsWith(projectPolicyId)
          )
        )
      ) continue;

      const type: MarketplaceEventType = nfts.length > 1
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
        nfts,
        owner,
        lovelace,
        privateListing,
      });

      db.registerEvent({
        type,
        data: {
          txHash: outRef.txHash,
          slot: point.slot,
          nfts: transformArrayToString(nfts),
          owner,
          lovelace,
        },
      }, point);

      db.updateCheckpoint("Listing", point);
    }
  }
}

function watchSalesAndCancellations(tx: TxShelleyCompatible, point: Point) {
  if (!tx.witness.redeemers) return;

  for (const [purpose, redeemer] of Object.entries(tx.witness.redeemers)) {
    const [tag, index]: [string, number] = pipe(
      purpose.split(":"),
      ([tag, index]: [string, string]) => [tag, parseInt(index)],
    );

    if (tag !== "spend") continue;

    const outRef: OutRef = {
      txHash: tx.body.inputs[index].txId,
      outputIndex: tx.body.inputs[index].index,
    };

    const action = (() => {
      try {
        return Data.from<D.TradeAction>(redeemer.redeemer, D.TradeAction);
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
          }
        })();

        const paymentDatum = Data.to<D.PaymentDatum>({
          outRef: {
            txHash: { hash: outRef.txHash },
            outputIndex: BigInt(outRef.outputIndex),
          },
        }, D.PaymentDatum);

        const nfts = bid.policyId
          ? tx.body.outputs.reduce((nfts, utxo) => {
            const unit = Object.keys(utxo!.value.assets || {}).find((unit) =>
              unit.startsWith(bid.policyId!) &&
              utxo!.value.assets![unit] > 0 &&
              utxo.datum === paymentDatum
            );
            return unit ? unit.replace(".", "") : nfts;
          }, bid.nfts)
          : bid.nfts;

        /**
         * If there is no vkey signature then we cannot identify the seller. For now we leave it as null/unknown.
         */
        const seller = pipe(
          Object.keys(tx.witness.signatures),
          (publicKeys: string[]) =>
            publicKeys.length <= 0 ? null : C.PublicKey.from_bytes(
              fromHex(publicKeys[0]),
            ).hash().to_bech32("addr_vkh"),
        );

        db.addSale({
          txHash: tx.id,
          point,
          type,
          nfts: nfts!,
          lovelace: bid.lovelace,
          seller,
          buyer: bid.owner,
        });
        db.registerEvent({
          type: type,
          data: {
            txHash: tx.id,
            slot: point.slot,
            nfts,
            lovelace: bid.lovelace,
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
          Object.keys(tx.witness.signatures),
          (publicKeys: string[]) =>
            publicKeys.length <= 0 ? null : C.PublicKey.from_bytes(
              fromHex(publicKeys[0]),
            ).hash().to_bech32("addr_vkh"),
        );

        db.addSale({
          txHash: tx.id,
          point,
          type,
          nfts: listing.nfts,
          lovelace: listing.lovelace,
          seller: listing.owner,
          buyer,
        });
        db.registerEvent({
          type: type,
          data: {
            txHash: tx.id,
            slot: point.slot,
            nfts: listing.nfts,
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
            nfts: listing.nfts,
            owner: listing.owner,
            lovelace: listing.lovelace,
          });
          db.registerEvent({
            type: type,
            data: {
              txHash: tx.id,
              slot: point.slot,
              owner: listing.owner,
              nfts: listing.nfts,
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
            }
          })();
          db.addCancellation({
            txHash: tx.id,
            point,
            type,
            nfts: bid.nfts,
            policyId: bid.policyId,
            constraints: bid.constraints,
            owner: bid.owner,
            lovelace: bid.lovelace,
          });
          db.registerEvent({
            type: type,
            data: {
              txHash: tx.id,
              slot: point.slot,
              owner: bid.owner,
              nfts: bid.nfts,
              policyId: bid.policyId,
              constraints: bid.constraints,
              lovelace: bid.lovelace,
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
  tx: TxShelleyCompatible,
  point: Point,
  watcher: (tx: TxShelleyCompatible, point: Point) => unknown,
) {
  try {
    watcher(tx, point);
  } catch (e) {
    console.log(e);
  }
}

export function watchBlock(blockShelley: BlockShelleyCompatible) {
  const transactions = blockShelley.body;
  const point: Point = {
    hash: blockShelley.headerHash,
    slot: blockShelley.header.slot,
  };
  for (const tx of transactions) {
    tryWatch(tx, point, watchSalesAndCancellations);
    tryWatch(tx, point, watchListingsAndBids);
  }
}
