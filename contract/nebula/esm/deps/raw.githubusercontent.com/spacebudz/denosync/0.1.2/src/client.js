export function getBlockEra(block) {
    return Object.keys(block)[0];
}
export function toByronBlock(block) {
    return block.byron || null;
}
// deno-lint-ignore no-explicit-any
function toShelleyCompactHeader(header) {
    return {
        blockHash: header.blockHash,
        blockHeight: header.blockHeight,
        blockSize: header.blockSize,
        prevHash: header.prevHash,
        slot: header.slot,
    };
}
export function toShelleyCompatibleBlock(block) {
    const era = getBlockEra(block);
    if (era === "byron")
        return null;
    const blockEra = block[era];
    if (!blockEra)
        return null;
    const header = toShelleyCompactHeader(blockEra.header);
    const headerHash = blockEra.headerHash;
    // deno-lint-ignore no-explicit-any
    const body = blockEra.body.map((tx) => {
        if (era === "shelley") {
            return {
                ...tx,
                body: {
                    ...tx.body,
                    validityInterval: {
                        invalidBefore: null,
                        invalidHereafter: tx.body.timeToLive || null,
                    },
                },
            };
        }
        else {
            return tx;
        }
    });
    return { blockShelley: { header, headerHash, body }, era };
}
export const POINT_SHELLEY_START = {
    slot: 4492799,
    hash: "f8084c61b6a238acec985b59310b6ecec49c0ab8352249afd7268da5cff2a457",
};
export async function createClient({ url, startPoint }, callbacks) {
    const client = new WebSocket(url);
    function wsp(methodname, args, mirror) {
        client.send(JSON.stringify({
            type: "jsonwsp/request",
            version: "1.0",
            servicename: "ogmios",
            methodname,
            args,
            mirror,
        }));
    }
    let hasExited = false;
    Deno.addSignalListener("SIGINT", () => {
        hasExited = true;
    });
    client.addEventListener("message", async (msg) => {
        const response = JSON.parse(msg.data);
        switch (response.methodname) {
            case "FindIntersect":
                if (!response.result.IntersectionFound) {
                    throw "Intersection not found.";
                }
                break;
            case "RequestNext":
                if (response.result.RollForward) {
                    await callbacks.rollForward(response.result.RollForward.block, hasExited);
                }
                else if (response.result.RollBackward) {
                    await callbacks.rollBackward(response.result.RollBackward.point, hasExited);
                }
                else {
                    throw "RequestNext could not move forward or backward.";
                }
                if (hasExited) {
                    client.close();
                    return;
                }
                wsp("RequestNext", {});
                break;
        }
    });
    await new Promise((res) => {
        client.addEventListener("open", async () => {
            if (startPoint) {
                if (startPoint === "tip") {
                    client.send(JSON.stringify({
                        type: "jsonwsp/request",
                        version: "1.0",
                        servicename: "ogmios",
                        methodname: "Query",
                        args: { query: "chainTip" },
                    }));
                    const tip = await new Promise((res, rej) => {
                        client.addEventListener("message", (msg) => {
                            try {
                                const { result } = JSON.parse(msg.data);
                                res({
                                    hash: result.hash,
                                    slot: result.slot,
                                });
                            }
                            catch (e) {
                                rej(e);
                            }
                        }, { once: true });
                    });
                    wsp("FindIntersect", { points: [tip] });
                }
                else {
                    wsp("FindIntersect", { points: [startPoint] });
                }
            }
            return res(1);
        }, { once: true });
    });
    return {
        start: () => {
            for (let i = 0; i < 100; i += 1) {
                wsp("RequestNext", {});
            }
        },
        close: () => client.close(),
        onExit: (cb) => {
            Deno.addSignalListener("SIGINT", () => {
                setTimeout(() => {
                    cb();
                }, 1000);
            });
        },
    };
}
export const isShelleyProtocolParameters = (params) => params.minUtxoValue !== undefined;
export const isAlonzoProtocolParameters = (params) => params.coinsPerUtxoWord !== undefined;
export const isBabbageProtocolParameters = (params) => params.coinsPerUtxoByte !== undefined;
