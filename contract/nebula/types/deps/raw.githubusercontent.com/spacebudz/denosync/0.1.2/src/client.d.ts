import { Block, BlockShelleyCompatible, Client, ClientConfig, Era, Point, ProtocolParametersAlonzo, ProtocolParametersBabbage, ProtocolParametersShelley, RollCallbacks, StandardBlock } from "./types.js";
export declare function getBlockEra(block: Block): Era;
export declare function toByronBlock(block: Block): StandardBlock | null;
export declare function toShelleyCompatibleBlock(block: Block): {
    blockShelley: BlockShelleyCompatible;
    era: Era;
} | null;
export declare const POINT_SHELLEY_START: Point;
export declare function createClient({ url, startPoint }: ClientConfig, callbacks: RollCallbacks): Promise<Client>;
export declare const isShelleyProtocolParameters: (params: ProtocolParametersShelley | ProtocolParametersAlonzo | ProtocolParametersBabbage) => params is ProtocolParametersShelley;
export declare const isAlonzoProtocolParameters: (params: ProtocolParametersShelley | ProtocolParametersAlonzo | ProtocolParametersBabbage) => params is ProtocolParametersAlonzo;
export declare const isBabbageProtocolParameters: (params: ProtocolParametersShelley | ProtocolParametersAlonzo | ProtocolParametersBabbage) => params is ProtocolParametersBabbage;
