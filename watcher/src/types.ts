import {
  Json,
  OutRef,
  Point,
  PolicyId,
  Slot,
  TxHash,
  Unit,
} from "../../deps.ts";

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

export type MarketplaceEvent = {
  type: MarketplaceEventType;
  data: Json;
};

export type ListingEventType = "ListingSingle" | "ListingBundle";
export type BidEventType = "BidSingle" | "BidBundle" | "BidOpen";
export type BuyEventType = "BuySingle" | "BuyBundle";
export type SellEventType = "SellSingle" | "SellBundle";
export type CancelBidEventType =
  | "CancelBidSingle"
  | "CancelBidBundle"
  | "CancelBidOpen";
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
  point: Point;
  type: ListingEventType;
  nfts: Unit | Unit[];
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  /** Bech32 payment credential */
  privateListing?: string | null;
};

export type BidDB = {
  outRef: OutRef;
  point: Point;
  type: BidEventType;
  nfts?: Unit | Unit[] | null;
  policyId?: PolicyId | null;
  constraints?: Json | null;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
};

export type SaleDB = {
  txHash: TxHash;
  point: Point;
  type: BuyEventType | SellEventType;
  nfts: Unit | Unit[];
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  /** Bech32 payment credential */
  buyer: string;
  /** Bech32 payment credential */
  seller: string;
};

export type CancellationDB = {
  txHash: TxHash;
  point: Point;
  type: CancelListingEventType | CancelBidEventType;
  nfts?: Unit | Unit[] | null;
  policyId?: PolicyId | null;
  constraints?: Json | null;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
};

export type BidAndListingSingleEventData = {
  txHash: TxHash;
  slot: Slot;
  nfts: Unit;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
};

export type BidAndListingBundleEventData = {
  txHash: TxHash;
  slot: Slot;
  nfts: Unit | Unit[];
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
};

export type BidOpenEventData = {
  txHash: TxHash;
  slot: Slot;
  policyId: PolicyId;
  constraints?: Json;
  /** Bech32 payment credential */
  owner: string;
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
};

export type SaleSingleEventData = {
  txHash: TxHash;
  slot: Slot;
  nfts: Unit | Unit[];
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  /** Bech32 payment credential */
  seller: string;
  /** Bech32 payment credential */
  buyer: string;
};

export type SaleBundleEventData = {
  txHash: TxHash;
  slot: Slot;
  nfts: Unit | Unit[];
  /** We can savely use number here and don't need bigint. */
  lovelace: number;
  /** Bech32 payment credential */
  seller: string;
  /** Bech32 payment credential */
  buyer: string;
};
