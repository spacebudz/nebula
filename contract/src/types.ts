import { Address, Lovelace, PolicyId, TxHash, Unit } from "../../deps.ts";

export type ContractConfig = {
  royaltyToken: Unit;
  policyId: PolicyId;
  fundProtocol?: boolean;
  owner?: Address;
  deployHash?: TxHash;
  aggregatorFee?: RoyaltyRecipient[];
};

export type RoyaltyRecipient = {
  address: Address;
  /** Variable fee. e.g.: 0.04 (4%) */
  fee: number;
  /** Optionally set a minimum absolute fee. */
  minFee?: Lovelace;
  /** Optionally set a maximum absolute fee. */
  maxFee?: Lovelace;
};

export type Constraints = {
  types?: string[];
  traits?: { negation?: boolean; trait: string }[];
};

export type AssetName = string;
export type NameAndQuantity = Record<AssetName, bigint>;
