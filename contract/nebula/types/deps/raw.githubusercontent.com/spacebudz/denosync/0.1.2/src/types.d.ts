import { AuxiliaryData, BlockAllegra, BlockAlonzo, BlockBabbage, BlockByron, BlockMary, BlockShelley, BootstrapWitness, Certificate, Datum, DigestBlake2BBlockBody, DigestBlake2BScriptIntegrity, DigestBlake2BVerificationKey, Lovelace, Network, Null, Point, ProtocolParametersAlonzo, ProtocolParametersBabbage, ProtocolParametersShelley, Redeemer, Script, Signature, StandardBlock, TxIn, TxOut, UpdateAlonzo, UpdateBabbage, UpdateShelley, ValidityInterval, Value, Withdrawals } from "../../../../CardanoSolutions/ogmios/v5.5.7/clients/TypeScript/packages/schema/src/index.js";
export type { Point, ProtocolParametersAlonzo, ProtocolParametersBabbage, ProtocolParametersShelley, StandardBlock, };
export declare type BlockHeaderShelleyCompact = {
    blockHash: string;
    blockHeight: number;
    blockSize: number;
    prevHash: string;
    slot: number;
};
export declare type TxShelleyCompatible = {
    id: DigestBlake2BBlockBody;
    inputSource?: "inputs" | "collaterals";
    body: {
        inputs: TxIn[];
        references?: TxIn[];
        collaterals?: TxIn[];
        collateralReturn?: TxOut | null;
        totalCollateral?: Lovelace | null;
        outputs: TxOut[];
        certificates: Certificate[];
        withdrawals: Withdrawals;
        fee: Lovelace;
        validityInterval: ValidityInterval;
        update: UpdateShelley | UpdateAlonzo | UpdateBabbage;
        mint?: Value;
        network?: Network | null;
        scriptIntegrityHash?: DigestBlake2BScriptIntegrity | null;
        requiredExtraSignatures?: DigestBlake2BVerificationKey[];
    };
    witness: {
        signatures: {
            [k: string]: Signature;
        };
        scripts: {
            [k: string]: Script;
        };
        bootstrap: BootstrapWitness[];
        datums?: {
            [k: string]: Datum;
        };
        redeemers?: {
            [k: string]: Redeemer;
        };
    };
    metadata: AuxiliaryData | Null;
    /**
     * The raw serialized transaction, as found on-chain.
     */
    raw: string;
};
export declare type BlockShelleyCompatible = {
    body: TxShelleyCompatible[];
    header: BlockHeaderShelleyCompact;
    headerHash: string;
};
export declare type Era = "byron" | "shelley" | "allegra" | "mary" | "alonzo" | "babbage";
export declare type Block = {
    byron?: BlockByron;
    shelley?: BlockShelley;
    allegra?: BlockAllegra;
    mary?: BlockMary;
    alonzo?: BlockAlonzo;
    babbage?: BlockBabbage;
};
export declare type RollCallbacks = {
    rollBackward: (point: Point, hasExited: boolean) => unknown;
    rollForward: (block: Block, hasExited: boolean) => unknown;
};
export declare type ClientConfig = {
    url: string;
    startPoint?: Point | "origin" | "tip";
};
export declare type Client = {
    start: () => void;
    close: () => void;
    /** Calling onExit allows to gracefully shutdown the client and to save all necessary state. */
    onExit: (cb: () => unknown) => void;
};
