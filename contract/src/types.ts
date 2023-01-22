import { Address, Lovelace, PolicyId, TxHash, Unit } from "../../deps.ts";

export type ContractConfig = {
  royaltyToken: Unit;
  policyId: PolicyId;
  fundProtocol?: boolean;
  owner?: Address;
  deployHash?: TxHash;
};

export type RoyaltyRecipient = {
  address: Address;
  /** e.g.: 0.04 (4%) */
  fee: number;
  /** Optionally set a maximum absolute fee. */
  maxFee?: Lovelace;
};
