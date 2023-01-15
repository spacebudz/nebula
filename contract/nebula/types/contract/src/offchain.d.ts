import { Address, Lovelace, Lucid, MintingPolicy, OutRef, PolicyId, ScriptHash, SpendingValidator, TxHash, Unit, UTxO } from "../../deps.js";
import * as D from "../../common/contract.types.js";
import { ContractConfig, RoyaltyRecipient } from "./types.js";
export declare class Contract {
    lucid: Lucid;
    tradeValidator: SpendingValidator;
    tradeHash: ScriptHash;
    tradeAddress: Address;
    mintPolicy: MintingPolicy;
    mintPolicyId: PolicyId;
    config: ContractConfig;
    fundProtocol: boolean;
    /**
     * **NOTE**: config.royaltyToken and config.fundProtocol are parameters of the marketplace contract.
     * Changing these parameters changes the plutus script and so the script hash!
     */
    constructor(lucid: Lucid, config?: ContractConfig);
    buy(listingUtxos: UTxO[]): Promise<TxHash>;
    /**
     * Accept specific bids.
     * Optionally you can accept open bids that demand any NFT from the collection for a certain lovelace amount.
     * Specify in this case the asset you are willing to sell for this price.
     */
    sell(sellOptions: {
        bidUtxo: UTxO;
        assetName?: string;
    }[]): Promise<TxHash>;
    list(assetName: string, lovelace: Lovelace, privateListing?: Address | null): Promise<TxHash>;
    changeListing(listingUtxo: UTxO, lovelace: Lovelace, privateListing?: Address | null): Promise<TxHash>;
    /** Create a bid on a specific token within the collection. */
    bid(assetName: string, lovelace: Lovelace): Promise<TxHash>;
    /** Create a bid on any token within the collection. Optionally add constraints. */
    bidOpen(lovelace: Lovelace, constraints?: {
        types?: string[];
        traits?: {
            negation?: boolean;
            trait: string;
        }[];
    }): Promise<TxHash>;
    changeBid(bidUtxo: UTxO, lovelace: Lovelace): Promise<TxHash>;
    cancelListing(listingUtxo: UTxO): Promise<TxHash>;
    cancelBid(bidUtxo: UTxO): Promise<TxHash>;
    cancelListingAndSell(listingUtxo: UTxO, bidUtxo: UTxO, assetName?: string): Promise<TxHash>;
    cancelBidAndBuy(bidUtxo: UTxO, listingUtxo: UTxO): Promise<TxHash>;
    /** Get a specific listing or bid. */
    getListingOrBid(outRef: OutRef): Promise<UTxO | null>;
    /** Return the current listings for a specific asset sorted in ascending order by price. */
    getListings(assetName: string): Promise<UTxO[]>;
    /**
     * Return the current bids for a specific token sorted in descending order by price.
     * Or return the open bids on any token within the collection (use 'open' as arg instead of an asset name).
     */
    getBids(assetName: "Open" | string): Promise<UTxO[]>;
    /**
     * Create a royalty token and lock it in a script controlled by the specified owner.
     * The output the royalty token is in holds the royalty info (fees, recipients) in the datum.\
     * minAda is the threshold that decides to pay fee as percentage or fixed.
     */
    static createRoyalty(lucid: Lucid, royaltyRecipients: RoyaltyRecipient[], owner: Address, minAda?: Lovelace): Promise<{
        txHash: TxHash;
        royaltyToken: Unit;
    }>;
    /** Deploy necessary scripts to reduce tx costs heavily. */
    deployScripts(): Promise<TxHash>;
    /** Return the datum of the UTxO the royalty token is locked in. */
    getRoyalty(): Promise<{
        utxo: UTxO;
        royaltyInfo: D.RoyaltyInfo;
    }>;
    getDeployedScripts(): Promise<{
        trade: UTxO | null;
    }>;
    getContractHashes(): {
        scriptHash: ScriptHash;
        nftPolicyId: PolicyId;
        bidPolicyId: PolicyId;
    };
    /**
     * Update royalty info like fees and recipients.\
     * minAda is the threshold that decides to pay fee as percentage or fixed.
     */
    updateRoyalty(royaltyRecipients: RoyaltyRecipient[], minAda?: Lovelace): Promise<TxHash>;
    private _cancelListing;
    private _sell;
    private _cancelBid;
    private _buy;
    private _payFee;
}
