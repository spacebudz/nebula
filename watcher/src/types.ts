import { Json, OutRef } from "lucid";
import { Point, PolicyId, Slot } from "@cardano-ogmios/schema";

export type Config = {
  /**  Hash of the marketplace contract address. */
  scriptHash: string;
  /** The policy id of the bid tokens. */
  bidPolicyId: string;
  /** The policy ids of the NFT collections. */
  projects: PolicyId[];
  /** Start point is only required to initialize the DB and won't overwrite the DB point at a later time. */
  startPoint?: Point;
};

export type PointDB = { hash: string; slot: number };

/**
 * We cannot and do not need to store asset quantities in bigint format.
 * Number is sufficient enough and can easily be converted from and to json and stored in the sqlite database.
 */
export type AssetsWithNumber = Record<string, number>;

export type MarketplaceEvent = {
  type: MarketplaceEventType;
  data: Json;
};

export type ListingEventType = "ListingSingle" | "ListingBundle";
export type BidEventType = "BidSingle" | "BidBundle" | "BidOpen" | "BidSwap";
export type BuyEventType = "BuySingle" | "BuyBundle";
export type SellEventType = "SellSingle" | "SellBundle" | "SellSwap";
export type CancelBidEventType =
  | "CancelBidSingle"
  | "CancelBidBundle"
  | "CancelBidOpen"
  | "CancelBidSwap";
export type CancelListingEventType =
  | "CancelListingSingle"
  | "CancelListingBundle";

export type MarketplaceEventType =
  | ListingEventType
  | BidEventType
  | BuyEventType
  | SellEventType
  | CancelBidEventType
  | CancelListingEventType;

export type CheckpointType =
  | "Sale"
  | "Cancel"
  | "Bid"
  | "Listing"
  | "Rollback"
  | "Sync"
  | "Cleanup";

export type ListingDB = {
  outRef: OutRef;
  point: PointDB;
  type: ListingEventType;
  assets: AssetsWithNumber;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  /** Bech32 payment credential */
  privateListing?: string | null;
};

export type BidDB = {
  outRef: OutRef;
  point: PointDB;
  type: BidEventType;
  assets?: AssetsWithNumber | null;
  policyId?: PolicyId | null;
  constraints?: Json | null;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  addBidAssets?: AssetsWithNumber | null;
};

export type SaleDB = {
  txHash: string;
  point: PointDB;
  type: BuyEventType | SellEventType;
  assets: AssetsWithNumber;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  addBidAssets?: AssetsWithNumber | null;
  /** Bech32 payment credential */
  buyer: string;
  /** Bech32 payment credential */
  seller: string;
};

export type CancellationDB = {
  txHash: string;
  point: PointDB;
  type: CancelListingEventType | CancelBidEventType;
  assets?: AssetsWithNumber | null;
  policyId?: PolicyId | null;
  constraints?: Json | null;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  addBidAssets?: AssetsWithNumber | null;
};

export type BidAndListingEventData = {
  txHash: string;
  slot: Slot;
  assets: AssetsWithNumber;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
};

export type BidOpenEventData = {
  txHash: string;
  slot: Slot;
  policyId: PolicyId;
  constraints?: Json;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
};

export type BidSwapEventData = {
  txHash: string;
  slot: Slot;
  policyId: PolicyId;
  constraints?: Json;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  addBidAssets: AssetsWithNumber;
};

export type SaleEventData = {
  txHash: string;
  slot: Slot;
  assets: AssetsWithNumber;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  addBidAssets?: AssetsWithNumber | null;
  /** Bech32 payment credential */
  seller: string;
  /** Bech32 payment credential */
  buyer: string;
};
