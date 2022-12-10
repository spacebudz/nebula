import {
  BlockShelleyCompatible,
  C,
  Constr,
  Data,
  Datum,
  fromHex,
  getAddressDetails,
  hexToUtf8,
  Lovelace,
  OutRef,
  PlutusData,
  Point,
  PolicyId,
  TxShelleyCompatible,
} from "../../deps.ts";
import { pipe, toOwner } from "./utils.ts";
import { dataToAssets, unwrapMaybe } from "../../common/utils.ts";
import { BidOption, TradeAction, TradeDatum } from "../../common/types.ts";
import {
  BuyEventType,
  CancelBidEventType,
  CancelListingEventType,
  MarketplaceEventType,
  SellEventType,
} from "./types.ts";
import { config } from "./flags.ts";
import { db } from "./db.ts";

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
      const datum = Data.from(getDatum(tx, output)!) as Constr<PlutusData>;

      if (datum.index !== TradeDatum.Bid) continue;

      const bidDetails = datum.fields[0] as Constr<PlutusData>;
      const owner = toOwner({
        data: bidDetails.fields[0] as Constr<PlutusData>,
      });
      const lovelace = parseInt(output.value.coins.toString());

      const bidOption = bidDetails.fields[1] as Constr<PlutusData>;

      if (bidOption.index === BidOption.SpecificValue) {
        const nfts = Object.keys(dataToAssets(
          bidOption.fields[0] as Map<string, Map<string, bigint>>,
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
            nfts,
            owner,
            lovelace,
          },
        }, point);
      } else if (bidOption.index === BidOption.SpecificPolicyIdOnly) {
        const policyId = bidOption.fields[0] as PolicyId;
        // We only track valid open bids.
        if (
          !config.projects.some((projectPolicyId) =>
            projectPolicyId === policyId
          )
        ) continue;

        const types = (bidOption.fields[1] as string[]).map((bytes) =>
          hexToUtf8(bytes)
        );
        const traits = (bidOption.fields[2] as Constr<PlutusData>[]).map((
          constr,
        ) => ({
          negation: constr.fields[0] < 0n,
          trait: hexToUtf8(constr.fields[1] as string),
        }));

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
      const datum = Data.from(getDatum(tx, output)!) as Constr<PlutusData>;
      if (datum.index !== TradeDatum.Listing) continue;

      const listingDetails = datum.fields[0] as Constr<PlutusData>;

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
        data: listingDetails.fields[0] as Constr<PlutusData>,
      });
      const lovelace = parseInt(
        (listingDetails.fields[1] as Lovelace).toString(),
      );
      const privateListing = pipe(
        unwrapMaybe(
          listingDetails.fields[2] as Constr<PlutusData>,
        ),
        (data: Constr<PlutusData>) => data ? toOwner({ data }) : null,
      );

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
          nfts,
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

    const action =
      (Data.from(redeemer.redeemer) as Constr<PlutusData>)?.index ?? null;

    switch (action) {
      case TradeAction.Sell: {
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

        const paymentDatum = Data.to(
          new Constr(0, [
            new Constr(0, [
              new Constr(0, [outRef.txHash]),
              BigInt(outRef.outputIndex),
            ]),
          ]),
        );

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
         * If there is no signature or more than one then we cannot identify the seller. For now we leave it as null/unknown.
         * If there is one signature we can precisely identify the seller.
         */
        const seller = pipe(
          Object.keys(tx.witness.signatures),
          (publicKeys: string[]) =>
            publicKeys.length <= 0 || publicKeys.length > 1
              ? null
              : C.PublicKey.from_bytes(
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
      case TradeAction.Buy: {
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
         * If there is no signature or more than one then we cannot identify the buyer. For now we leave it as null/unknown.
         * If there is one signature we can precisely identify the buyer.
         */
        const buyer = pipe(
          Object.keys(tx.witness.signatures),
          (publicKeys: string[]) =>
            publicKeys.length <= 0 || publicKeys.length > 1
              ? null
              : C.PublicKey.from_bytes(
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
      case TradeAction.Cancel: {
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
