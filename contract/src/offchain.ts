import {
  Address,
  applyParamsToScript,
  Constr,
  Data,
  Datum,
  fromUnit,
  Lovelace,
  Lucid,
  MintingPolicy,
  OutRef,
  PlutusData,
  PolicyId,
  ScriptHash,
  SpendingValidator,
  toLabel,
  toUnit,
  Tx,
  TxHash,
  utf8ToHex,
  UTxO,
} from "../../deps.ts";
import { BidOption, TradeAction, TradeDatum } from "../../common/types.ts";
import scripts from "./ghc/scripts.json" assert { type: "json" };
import {
  addressToData,
  assetsToData,
  dataToAddress,
  dataToAssets,
  sortDesc,
  unwrapMaybe,
  wrapMaybe,
} from "../../common/utils.ts";
import { toAction } from "./utils.ts";
import { ContractConfig, RoyaltyRecipient } from "./types.ts";

export class Contract {
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
  constructor(
    lucid: Lucid,
    config: ContractConfig,
  ) {
    this.lucid = lucid;
    this.config = config;

    const { policyId, assetName } = fromUnit(this.config.royaltyToken);

    this.fundProtocol = this.lucid.network === "Mainnet"
      ? this.config.fundProtocol ||
          typeof this.config.fundProtocol === "undefined"
        ? true
        : false
      : false;

    const protocolKey = this.lucid.utils.getAddressDetails(
      PROTOCOL_FUND_ADDRESS,
    ).paymentCredential?.hash;

    if (this.fundProtocol && !protocolKey) throw "Invalid protocol key!";

    this.tradeValidator = {
      type: "PlutusV2",
      script: applyParamsToScript(
        scripts.trade,
        wrapMaybe(
          this.fundProtocol ? protocolKey : null,
        ),
        new Constr(0, [
          utf8ToHex(this.config.metadataKeyNames?.type || "type"),
          utf8ToHex(this.config.metadataKeyNames?.traits || "traits"),
        ]),
        toLabel(100),
        new Constr(0, [policyId, assetName || ""]),
      ),
    };
    this.tradeHash = lucid.utils.validatorToScriptHash(this.tradeValidator);
    this.tradeAddress = lucid.utils.credentialToAddress(
      lucid.utils.scriptHashToCredential(this.tradeHash),
    );

    this.mintPolicy = lucid.utils.nativeScriptFromJson({
      type: "any",
      scripts: [
        { type: "after", slot: 0 },
        { type: "sig", keyHash: this.tradeHash },
      ],
    });
    this.mintPolicyId = lucid.utils.mintingPolicyToId(this.mintPolicy);
  }

  async buy(listingUtxos: UTxO[]): Promise<TxHash> {
    const buyOrders = (await Promise.all(
      listingUtxos.map((listingUtxo) => this._buy(listingUtxo)),
    ))
      .reduce(
        (prevTx, tx) => prevTx.compose(tx),
        this.lucid.newTx(),
      );

    const tx = await this.lucid.newTx()
      .compose(buyOrders)
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  /**
   * Accept specific bids.
   * Optionally you can accept open bids that demand any NFT from the collection for a certain lovelace amount.
   * Specify in this case the asset you are willing to sell for this price.
   */
  async sell(
    sellOptions: { bidUtxo: UTxO; assetName?: string }[],
  ): Promise<TxHash> {
    const sellOrders = (await Promise.all(
      sellOptions.map(({ bidUtxo, assetName }) =>
        this._sell(bidUtxo, assetName)
      ),
    ))
      .reduce(
        (prevTx, tx) => prevTx.compose(tx),
        this.lucid.newTx(),
      );

    const tx = await this.lucid.newTx()
      .compose(sellOrders)
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  async list(
    assetName: string,
    lovelace: Lovelace,
    privateListing?: Address | null,
  ): Promise<TxHash> {
    const ownerAddress = await this.lucid.wallet.address();
    const { stakeCredential } = this.lucid.utils.getAddressDetails(
      ownerAddress,
    );

    const adjustedTradeAddress = stakeCredential
      ? this.lucid.utils.credentialToAddress(
        this.lucid.utils.scriptHashToCredential(this.tradeHash),
        stakeCredential,
      )
      : this.tradeAddress;

    const listingDatum = Data.to(
      new Constr(TradeDatum.Listing, [
        new Constr(0, [
          addressToData(ownerAddress),
          lovelace,
          wrapMaybe(privateListing ? addressToData(privateListing) : null),
        ]),
      ]),
    );

    const tx = await this.lucid.newTx().payToContract(adjustedTradeAddress, {
      inline: listingDatum,
    }, { [toUnit(this.config.policyId, assetName)]: 1n })
      .complete();

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  async changeListing(
    listingUtxo: UTxO,
    lovelace: Lovelace,
    privateListing?: Address | null,
  ): Promise<TxHash> {
    const newDatum = Data.from(await this.lucid.datumOf(listingUtxo)) as Constr<
      PlutusData
    >;
    if (newDatum.index !== TradeDatum.Listing) {
      throw new Error("Not a listing UTxO");
    }
    const listingDetails = newDatum.fields[0] as Constr<PlutusData>;

    const owner: Address = dataToAddress(
      listingDetails.fields[0] as Constr<PlutusData>,
      this.lucid,
    );

    listingDetails.fields[1] = lovelace;
    listingDetails.fields[2] = wrapMaybe(
      privateListing ? addressToData(privateListing) : null,
    );

    const address: Address = await this.lucid.wallet.address();

    if (owner !== address) throw new Error("You are not the owner.");

    const refScripts = await this.getDeployedScripts();

    const tx = await this.lucid.newTx()
      .collectFrom([listingUtxo], toAction(TradeAction.Cancel))
      .payToContract(listingUtxo.address, {
        inline: Data.to(newDatum),
      }, listingUtxo.assets)
      .addSigner(owner)
      .readFrom([refScripts.trade])
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  /** Create a bid on a specific token within the collection. */
  async bid(assetName: string, lovelace: Lovelace): Promise<TxHash> {
    const ownerAddress = await this.lucid.wallet.address();
    const { stakeCredential } = this.lucid.utils.getAddressDetails(
      ownerAddress,
    );

    const adjustedTradeAddress = stakeCredential
      ? this.lucid.utils.credentialToAddress(
        this.lucid.utils.scriptHashToCredential(this.tradeHash),
        stakeCredential,
      )
      : this.tradeAddress;

    const biddingDatum = Data.to(
      new Constr(TradeDatum.Bid, [
        new Constr(0, [
          addressToData(ownerAddress),
          new Constr(0, [
            assetsToData({ [toUnit(this.config.policyId, assetName)]: 1n }),
          ]),
        ]),
      ]),
    );

    const tx = await this.lucid.newTx()
      .mintAssets({
        [toUnit(this.mintPolicyId, utf8ToHex("Bid") + assetName)]: 1n,
      })
      .payToContract(adjustedTradeAddress, {
        inline: biddingDatum,
      }, {
        lovelace,
        [toUnit(this.mintPolicyId, utf8ToHex("Bid") + assetName)]: 1n,
      })
      .validFrom(this.lucid.utils.slotToUnixTime(1000))
      .attachMintingPolicy(this.mintPolicy)
      .complete();

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  /** Create a bid on any token within the collection. Optionally add constraints. */
  async bidOpen(
    lovelace: Lovelace,
    constraints?: {
      types?: string[];
      traits?: { negation?: boolean; trait: string }[];
    },
  ): Promise<TxHash> {
    const ownerAddress = await this.lucid.wallet.address();
    const { stakeCredential } = this.lucid.utils.getAddressDetails(
      ownerAddress,
    );

    const adjustedTradeAddress = stakeCredential
      ? this.lucid.utils.credentialToAddress(
        this.lucid.utils.scriptHashToCredential(this.tradeHash),
        stakeCredential,
      )
      : this.tradeAddress;

    const biddingDatum = Data.to(
      new Constr(TradeDatum.Bid, [
        new Constr(0, [
          addressToData(ownerAddress),
          new Constr(1, [
            this.config.policyId,
            constraints?.types ? constraints.types.map(utf8ToHex) : [],
            constraints?.traits
              ? constraints.traits.map(({ negation, trait }) =>
                new Constr(0, [negation ? -1n : 0n, utf8ToHex(trait)])
              )
              : [],
          ]),
        ]),
      ]),
    );

    const tx = await this.lucid.newTx()
      .mintAssets({
        [toUnit(this.mintPolicyId, utf8ToHex("OpenBid"))]: 1n,
      })
      .payToContract(adjustedTradeAddress, {
        inline: biddingDatum,
      }, {
        lovelace,
        [toUnit(this.mintPolicyId, utf8ToHex("OpenBid"))]: 1n,
      })
      .validFrom(this.lucid.utils.slotToUnixTime(1000))
      .attachMintingPolicy(this.mintPolicy)
      .complete();

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  async changeBid(bidUtxo: UTxO, lovelace: Lovelace): Promise<TxHash> {
    const datum = Data.from(await this.lucid.datumOf(bidUtxo)) as Constr<
      PlutusData
    >;
    if (datum.index !== TradeDatum.Bid) {
      throw new Error("Not a bidding UTxO");
    }
    const bidDetails = datum.fields[0] as Constr<PlutusData>;

    const owner: Address = dataToAddress(
      bidDetails.fields[0] as Constr<PlutusData>,
      this.lucid,
    );

    const address: Address = await this.lucid.wallet.address();

    if (owner !== address) throw new Error("You are not the owner.");

    const refScripts = await this.getDeployedScripts();

    const tx = await this.lucid.newTx().collectFrom(
      [bidUtxo],
      toAction(TradeAction.Cancel),
    ).payToContract(bidUtxo.address, {
      inline: bidUtxo.datum!,
    }, { ...bidUtxo.assets, lovelace })
      .addSigner(owner)
      .readFrom([refScripts.trade])
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  async cancelListing(listingUtxo: UTxO): Promise<TxHash> {
    const tx = await this.lucid.newTx().compose(
      await this._cancelListing(listingUtxo),
    )
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  async cancelBid(bidUtxo: UTxO): Promise<TxHash> {
    const tx = await this.lucid.newTx().compose(await this._cancelBid(bidUtxo))
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  async cancelListingAndSell(
    listingUtxo: UTxO,
    bidUtxo: UTxO,
    assetName?: string,
  ): Promise<TxHash> {
    const tx = await this.lucid.newTx()
      .compose(await this._cancelListing(listingUtxo))
      .compose(await this._sell(bidUtxo, assetName))
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  async cancelBidAndBuy(
    bidUtxo: UTxO,
    listingUtxo: UTxO,
  ): Promise<TxHash> {
    const tx = await this.lucid.newTx()
      .compose(await this._cancelBid(bidUtxo))
      .compose(await this._buy(listingUtxo))
      .complete({ nativeUplc: false });

    const txSigned = await tx.sign().complete();
    return txSigned.submit();
  }

  /** Get a specific listing or bid. */
  async getListingOrBid(outRef: OutRef): Promise<UTxO | null> {
    const [utxo] = await this.lucid.utxosByOutRef([outRef]);
    return utxo || null;
  }

  /** Return the current listings for a specific asset sorted in descending order by price. */
  async getListings(assetName: string): Promise<UTxO[]> {
    return (await this.lucid.utxosAtWithUnit(
      this.tradeAddress,
      toUnit(
        this.config.policyId,
        assetName,
      ),
    )).filter((utxo) => Object.keys(utxo.assets).length === 2).sort(sortDesc);
  }

  /**
   * Return the current bids for a specific token sorted in descending order by price.
   * Or return the open bids on any token within the collection (use 'open' as arg instead of an asset name).
   */
  async getBids(assetName: string | "open"): Promise<UTxO[]> {
    return (await this.lucid.utxosAtWithUnit(
      this.tradeAddress,
      toUnit(
        this.mintPolicyId,
        assetName === "open"
          ? utf8ToHex("OpenBid")
          : utf8ToHex("Bid") + assetName,
      ),
    )).filter((utxo) => Object.keys(utxo.assets).length === 2).sort(sortDesc);
  }

  /**
   * Create a royalty token and lock it in a script controlled by the specified owner.
   * The output the royalty token is in holds the royalty info (fees, recipients) in the datum.\
   * minAda is the threshold that decides to pay fee as percentage or fixed.
   */
  static async createRoyalty(
    lucid: Lucid,
    royaltyRecipients: RoyaltyRecipient[],
    owner: Address,
    minAda: Lovelace = 1000000n,
  ): Promise<TxHash> {
    const ownerKeyHash = lucid.utils.getAddressDetails(owner).paymentCredential
      ?.hash!;

    const ownersScript = lucid.utils.nativeScriptFromJson({
      type: "sig",
      keyHash: ownerKeyHash,
    });
    const ownersAddress = lucid.utils.validatorToAddress(ownersScript);

    const [utxo] = await lucid.wallet.getUtxos();

    const royaltyMintingPolicy: MintingPolicy = {
      type: "PlutusV2",
      script: applyParamsToScript(
        scripts.oneShot,
        new Constr(0, [
          new Constr(0, [
            utxo.txHash,
          ]),
          BigInt(utxo.outputIndex),
        ]),
      ),
    };

    const royaltyPolicyId = lucid.utils.mintingPolicyToId(
      royaltyMintingPolicy,
    );

    const royaltyUnit = toUnit(royaltyPolicyId, utf8ToHex("Royalty"), 500);

    const royaltyDatum = Data.to(
      new Constr(0, [
        royaltyRecipients.map((r) =>
          new Constr(0, [
            addressToData(
              r.recipient,
            ),
            BigInt(Math.floor(1 / (r.fee / 10))),
            r.fixedFee,
          ])
        ),
        minAda,
      ]),
    );

    const tx = await lucid.newTx()
      .collectFrom([utxo], Data.empty())
      .mintAssets({
        [royaltyUnit]: 1n,
      }, Data.empty()).payToAddressWithData(
        ownersAddress,
        { inline: royaltyDatum },
        { [royaltyUnit]: 1n },
      )
      .validFrom(lucid.utils.slotToUnixTime(1000))
      .attachMintingPolicy(royaltyMintingPolicy)
      .complete();

    const txSigned = await tx.sign().complete();

    console.log("\n💰 Royalty Token:", royaltyUnit);
    console.log(
      "You can now paste the Royalty Token into the Contract config.\n",
    );

    return txSigned.submit();
  }

  /** Deploy necessary scripts to reduce tx costs heavily. */
  async deployScripts(): Promise<TxHash> {
    const deployScript = this.lucid.utils.nativeScriptFromJson({
      type: "sig",
      keyHash: this.lucid.utils.getAddressDetails(this.config.owner)
        .paymentCredential
        ?.hash!,
    });

    const ownerAddress = this.lucid.utils.validatorToAddress(deployScript);

    const tx = await this.lucid.newTx()
      .payToAddressWithData(ownerAddress, {
        scriptRef: this.tradeValidator,
      }, {}).complete();

    const txSigned = await tx.sign().complete();

    console.log("\n⛓ Deploy Tx Hash:", txSigned.toHash());
    console.log(
      "You can now paste the Tx Hash into the Contract config.\n",
    );

    return txSigned.submit();
  }

  /** Return the UTxO the royalty token is locked in. */
  async getRoyalty(): Promise<UTxO> {
    const utxo = await this.lucid.utxoByUnit(
      this.config.royaltyToken,
    );
    if (!utxo) throw new Error("Royalty info not found.");
    await this.lucid.datumOf(utxo);
    return utxo;
  }

  async getDeployedScripts(): Promise<{ trade: UTxO }> {
    if (!this.config.deployTxHash) throw new Error("Scripts are not deployed.");
    const [trade] = await this.lucid.utxosByOutRef([{
      txHash: this.config.deployTxHash,
      outputIndex: 0,
    }]);
    return { trade };
  }

  getContractHashes(): {
    scriptHash: ScriptHash;
    nftPolicyId: PolicyId;
    bidPolicyId: PolicyId;
  } {
    return {
      scriptHash: this.tradeHash,
      nftPolicyId: this.config.policyId,
      bidPolicyId: this.mintPolicyId,
    };
  }

  /**
   * Update royalty info like fees and recipients.\
   * minAda is the threshold that decides to pay fee as percentage or fixed.
   */
  async updateRoyalty(
    royaltyRecipients: RoyaltyRecipient[],
    minAda: Lovelace = 1000000n,
  ): Promise<TxHash> {
    const ownersScript = this.lucid.utils.nativeScriptFromJson({
      type: "sig",
      keyHash: this.lucid.utils.getAddressDetails(this.config.owner)
        .paymentCredential?.hash!,
    });
    const ownerAddress = this.lucid.utils.validatorToAddress(ownersScript);

    const utxos = await this.lucid.utxosAt(ownerAddress);
    const royaltyUtxo = utxos.find((utxo) =>
      utxo.assets[this.config.royaltyToken]
    );

    if (!royaltyUtxo) throw new Error("NoUTxOError");

    const royaltyDatum = Data.to(
      new Constr(0, [
        royaltyRecipients.map((r) =>
          new Constr(0, [
            addressToData(
              r.recipient,
            ),
            BigInt(Math.floor(1 / (r.fee / 10))),
            r.fixedFee,
          ])
        ),
        minAda,
      ]),
    );

    const tx = await this.lucid.newTx()
      .collectFrom([royaltyUtxo])
      .payToAddressWithData(
        ownerAddress,
        { inline: royaltyDatum },
        royaltyUtxo.assets,
      )
      .attachSpendingValidator(ownersScript)
      .complete();

    const txSigned = await tx.sign().complete();

    return txSigned.submit();
  }

  private async _cancelListing(listingUtxo: UTxO): Promise<Tx> {
    const datum = Data.from(await this.lucid.datumOf(listingUtxo)) as Constr<
      PlutusData
    >;
    if (datum.index !== TradeDatum.Listing) {
      throw new Error("Not a listing UTxO");
    }
    const listingDetails = datum.fields[0] as Constr<PlutusData>;
    const owner: Address = dataToAddress(
      listingDetails.fields[0] as Constr<PlutusData>,
      this.lucid,
    );

    const address: Address = await this.lucid.wallet.address();

    if (owner !== address) throw new Error("You are not the owner.");

    const refScripts = await this.getDeployedScripts();

    return this.lucid.newTx().collectFrom(
      [listingUtxo],
      toAction(TradeAction.Cancel),
    )
      .addSigner(owner)
      .readFrom([refScripts.trade]);
  }

  private async _sell(
    bidUtxo: UTxO,
    assetName?: string,
  ): Promise<Tx> {
    const datum = Data.from(await this.lucid.datumOf(bidUtxo)) as Constr<
      PlutusData
    >;
    if (datum.index !== TradeDatum.Bid) {
      throw new Error("Not a bidding UTxO");
    }

    const bidDetails = datum.fields[0] as Constr<PlutusData>;

    const { lovelace } = bidUtxo.assets;
    const bidToken = Object.keys(bidUtxo.assets).find((unit) =>
      unit.startsWith(this.mintPolicyId)
    );
    if (!bidToken) throw new Error("No bid token found.");

    const owner: Address = dataToAddress(
      bidDetails.fields[0] as Constr<PlutusData>,
      this.lucid,
    );

    const assetsRequest = bidDetails.fields[1] as Constr<PlutusData>;

    const { requestedAssets, refNFT } = (() => {
      if (assetsRequest.index === BidOption.SpecificValue) {
        return {
          requestedAssets: dataToAssets(
            assetsRequest.fields[0] as Map<string, Map<string, bigint>>,
          ),
          refNFT: null,
        };
      } else if (
        assetsRequest.index === BidOption.SpecificPolicyIdOnly && assetName
      ) {
        const policyId = assetsRequest.fields[0] as PolicyId;
        const refNFT = toUnit(
          policyId,
          fromUnit(toUnit(policyId, assetName)).name,
          100,
        );
        const types = assetsRequest.fields[1] as PlutusData[];
        const traits = assetsRequest.fields[2] as PlutusData[];

        return {
          requestedAssets: {
            [toUnit(policyId, assetName)]: 1n,
          },
          refNFT: types.length > 0 || traits.length > 0 ? refNFT : null,
        };
      }
      throw new Error("No variant matched.");
    })();

    const paymentDatum = Data.to(
      new Constr(0, [
        new Constr(0, [
          new Constr(0, [bidUtxo.txHash]),
          BigInt(bidUtxo.outputIndex),
        ]),
      ]),
    );

    const refScripts = await this.getDeployedScripts();

    return this.lucid.newTx().collectFrom(
      [bidUtxo],
      toAction(TradeAction.Sell),
    )
      .applyIf(!!refNFT, async (thisTx) => {
        const refUtxo = await this.lucid.utxoByUnit(refNFT!);
        if (!refUtxo) throw new Error("This NFT doesn't support CIP-0068");
        thisTx.readFrom([refUtxo]);
      })
      .apply((thisTx) =>
        this._payFee(
          thisTx,
          lovelace,
          paymentDatum,
        )
      ).payToAddressWithData(owner, { inline: paymentDatum }, requestedAssets)
      .mintAssets({ [bidToken]: -1n })
      .applyIf(
        this.fundProtocol,
        (thisTx) => thisTx.payToAddress(PROTOCOL_FUND_ADDRESS, {}),
      )
      .validFrom(this.lucid.utils.slotToUnixTime(1000))
      .readFrom([refScripts.trade])
      .attachMintingPolicy(this.mintPolicy);
  }

  private async _cancelBid(bidUtxo: UTxO): Promise<Tx> {
    const datum = Data.from(await this.lucid.datumOf(bidUtxo)) as Constr<
      PlutusData
    >;
    if (datum.index !== TradeDatum.Bid) {
      throw new Error("Not a bidding UTxO");
    }
    const bidDetails = datum.fields[0] as Constr<PlutusData>;
    const owner: Address = dataToAddress(
      bidDetails.fields[0] as Constr<PlutusData>,
      this.lucid,
    );

    const address: Address = await this.lucid.wallet.address();

    if (owner !== address) throw new Error("You are not the owner.");

    const [bidToken] = Object.keys(bidUtxo.assets).filter((unit) =>
      unit !== "lovelace"
    );

    const refScripts = await this.getDeployedScripts();

    return this.lucid.newTx().collectFrom(
      [bidUtxo],
      toAction(TradeAction.Cancel),
    )
      .mintAssets({ [bidToken]: -1n })
      .validFrom(this.lucid.utils.slotToUnixTime(1000))
      .addSigner(owner)
      .readFrom([refScripts.trade])
      .attachMintingPolicy(this.mintPolicy);
  }

  private async _buy(listingUtxo: UTxO): Promise<Tx> {
    const datum = Data.from(await this.lucid.datumOf(listingUtxo)) as Constr<
      PlutusData
    >;
    if (datum.index !== TradeDatum.Listing) {
      throw new Error("Not a listing UTxO");
    }
    const listingDetails = datum.fields[0] as Constr<PlutusData>;

    const owner: Address = dataToAddress(
      listingDetails.fields[0] as Constr<PlutusData>,
      this.lucid,
    );
    const requestedLovelace: Lovelace = listingDetails.fields[1] as Lovelace;
    const privateListing = unwrapMaybe(
      listingDetails.fields[2] as Constr<PlutusData>,
    ) as Constr<PlutusData> | null;

    const paymentDatum = Data.to(
      new Constr(0, [
        new Constr(0, [
          new Constr(0, [listingUtxo.txHash]),
          BigInt(listingUtxo.outputIndex),
        ]),
      ]),
    );

    const refScripts = await this.getDeployedScripts();

    return this.lucid.newTx().collectFrom(
      [listingUtxo],
      toAction(TradeAction.Buy),
    )
      .apply(async (thisTx) => {
        const remainingLovelace = await this._payFee(
          thisTx,
          requestedLovelace,
          paymentDatum,
        );
        thisTx.payToAddressWithData(owner, { inline: paymentDatum }, {
          lovelace: remainingLovelace,
        });
      })
      .applyIf(!!privateListing, (thisTx) =>
        thisTx.addSigner(
          dataToAddress(privateListing!, this.lucid),
        ))
      .applyIf(
        this.fundProtocol,
        (thisTx) => thisTx.payToAddress(PROTOCOL_FUND_ADDRESS, {}),
      )
      .readFrom([refScripts.trade]);
  }

  private async _payFee(
    thisTx: Tx,
    lovelace: Lovelace,
    paymentDatum: Datum,
  ): Promise<Lovelace> {
    const royaltyInfo = await this.getRoyalty();
    let remainingLovelace = lovelace;

    const datum = Data.from(await this.lucid.datumOf(royaltyInfo)) as Constr<
      PlutusData
    >;
    if (datum.index !== 0) throw new Error("Invalid royalty info.");

    const recipients = datum.fields[0] as [Constr<PlutusData>];
    const minAda = datum.fields[1] as Lovelace;

    for (const recipient of recipients) {
      const address: Address = dataToAddress(
        recipient.fields[0] as Constr<PlutusData>,
        this.lucid,
      );
      const fee = recipient.fields[1] as bigint;
      const fixedFee = recipient.fields[2] as Lovelace;

      const feeToPay = (lovelace * 10n) / fee;
      const adjustedFee = feeToPay < minAda ? fixedFee : feeToPay;

      remainingLovelace -= adjustedFee;
      if (remainingLovelace <= 0n) {
        throw new Error("No lovelace left for recipient.");
      }

      thisTx.payToAddressWithData(address, { inline: paymentDatum }, {
        lovelace: adjustedFee,
      });
    }

    thisTx.readFrom([royaltyInfo]);

    return remainingLovelace;
  }
}

const PROTOCOL_FUND_ADDRESS =
  "addr1vxuj4yyqlz0k9er5geeepx0awh2t6kkes0nyp429hsttt3qrnucsx";
