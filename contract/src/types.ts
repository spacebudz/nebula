import { Address, Lovelace, PolicyId, TxHash, Unit } from "../../deps.ts";

export type ContractConfig = {
  royaltyToken: Unit;
  owner: Address;
  policyId: PolicyId;
  deployTxHash?: TxHash;
  /**
   * This allows you to change the default keys 'type' and 'traits' to key names of your choice.
   * Note: 'type' is a single string (e.g. SpaceBudz 'Cat'). 'traits' is an array of strings (e.g. SpaceBudz ['Axe', 'Umbrella']).
   * The Nebula Watcher will still store bids/sales with the 'type' and 'traits' name properties regardless of what names you set here.
   * Your NFTs need to be CIP-0068 compliant.
   *
   * Example metadata:
   * ```json
   *  {
   *    "image": "ipfs://..",
   *    "name": "SpaceBud #650",
   *    "type": "Bear",
   *    "traits": ["Chestplate", "Belt", "..."]
   *  }
   * ```
   */
  metadataKeyNames?: {
    type?: string;
    traits?: string;
  };
  fundProtocol?: boolean;
};

export type RoyaltyRecipient = {
  address: Address;
  /** e.g.: 0.04 (4%) */
  fee: number;
  fixedFee: Lovelace;
};
