export type ContractConfig = {
  royaltyToken: string;
  policyId: string;
  fundProtocol?: boolean;
  owner?: string;
  deployHash?: string;
  aggregatorFee?: RoyaltyRecipient[];
};

export type RoyaltyRecipient = {
  address: string;
  /** Variable fee. e.g.: 0.04 (4%) */
  fee: number;
  /** Optionally set a minimum absolute fee. */
  minFee?: bigint | null;
  /** Optionally set a maximum absolute fee. */
  maxFee?: bigint | null;
};

export type Constraints = {
  types?: string[];
  traits?: { negation?: boolean; trait: string }[];
};

export type AssetName = string;
export type NameAndQuantity = Record<AssetName, bigint>;
