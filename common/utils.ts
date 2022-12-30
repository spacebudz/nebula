import {
  Address,
  Assets,
  C,
  fromText,
  getAddressDetails,
  Lucid,
  toLabel,
  UTxO,
} from "../deps.ts";
import * as D from "./contract.types.ts";

const lucid = await Lucid.new();

export function idToBud(id: number): string {
  return toLabel(222) + fromText(`Bud${id}`);
}

export function colorToBerry(color: string): string {
  return fromText(`Berry${color}`);
}

export function idToMatrix(id: number): string {
  return fromText(`Matrix${id}`);
}

export function sortDesc(a: UTxO, b: UTxO): number {
  if (a.assets.lovelace > b.assets.lovelace) {
    return -1;
  } else if (a.assets.lovelace < b.assets.lovelace) {
    return 1;
  } else {
    return 0;
  }
}

export function toOwner(
  { address, data }: { address?: Address; data?: D.Address },
): string {
  const { paymentCredential } = getAddressDetails(
    address || toAddress(
      data!,
      lucid,
    ),
  );
  if (paymentCredential?.type === "Key") {
    return C.Ed25519KeyHash.from_hex(paymentCredential.hash).to_bech32(
      "addr_vkh",
    );
  } else if (paymentCredential?.type === "Script") {
    return C.ScriptHash.from_hex(paymentCredential.hash).to_bech32("script");
  }
  return "";
}

export function fromAddress(address: Address): D.Address {
  // We do not support pointer addresses!

  const { paymentCredential, stakeCredential } = getAddressDetails(
    address,
  );

  if (!paymentCredential) throw new Error("Not a valid payment address.");

  return {
    paymentCredential: paymentCredential?.type === "Key"
      ? {
        PublicKeyCredential: [paymentCredential.hash],
      }
      : { ScriptCredential: [paymentCredential.hash] },
    stakeCredential: stakeCredential
      ? {
        Inline: [
          stakeCredential.type === "Key"
            ? {
              PublicKeyCredential: [stakeCredential.hash],
            }
            : { ScriptCredential: [stakeCredential.hash] },
        ],
      }
      : null,
  };
}

export function toAddress(address: D.Address, lucid: Lucid): Address {
  const paymentCredential = (() => {
    if ("PublicKeyCredential" in address.paymentCredential) {
      return lucid.utils.keyHashToCredential(
        address.paymentCredential.PublicKeyCredential[0],
      );
    } else {
      return lucid.utils.scriptHashToCredential(
        address.paymentCredential.ScriptCredential[0],
      );
    }
  })();
  const stakeCredential = (() => {
    if (!address.stakeCredential) return undefined;
    if ("Inline" in address.stakeCredential) {
      if ("PublicKeyCredential" in address.stakeCredential.Inline[0]) {
        return lucid.utils.keyHashToCredential(
          address.stakeCredential.Inline[0].PublicKeyCredential[0],
        );
      } else {
        return lucid.utils.scriptHashToCredential(
          address.stakeCredential.Inline[0].ScriptCredential[0],
        );
      }
    } else {
      return undefined;
    }
  })();
  return lucid.utils.credentialToAddress(paymentCredential, stakeCredential);
}

export function fromAssets(assets: Assets): D.Value {
  const value = new Map<string, Map<string, bigint>>();
  if (assets.lovelace) value.set("", new Map([["", assets.lovelace]]));

  const units = Object.keys(assets);
  const policies = Array.from(
    new Set(
      units
        .filter((unit) => unit !== "lovelace")
        .map((unit) => unit.slice(0, 56)),
    ),
  );
  policies.sort().forEach((policyId) => {
    const policyUnits = units.filter((unit) => unit.slice(0, 56) === policyId);
    const assetsMap = new Map<string, bigint>();
    policyUnits.sort().forEach((unit) => {
      assetsMap.set(
        unit.slice(56),
        assets[unit],
      );
    });
    value.set(policyId, assetsMap);
  });
  return value;
}

export function toAssets(value: D.Value): Assets {
  const result: Assets = { lovelace: value.get("")?.get("") || 0n };

  for (const [policyId, assets] of value) {
    if (policyId === "") continue;
    for (const [assetName, amount] of assets) {
      result[policyId + assetName] = amount;
    }
  }
  return result;
}
