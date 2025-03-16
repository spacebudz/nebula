import {
  Addresses,
  Assets,
  fromText,
  Lucid,
  toLabel,
  Utils,
  Utxo,
} from "lucid";
import * as D from "./contract.types.ts";

const lucid = new Lucid();

export function idToBud(id: number): string {
  return toLabel(222) + fromText(`Bud${id}`);
}

export function colorToBerry(color: string): string {
  return fromText(`Berry${color}`);
}

export function idToMatrix(id: number): string {
  return toLabel(222) + fromText(`Matrix${id}`);
}

export function sortDesc(a: Utxo, b: Utxo): number {
  if (a.assets.lovelace > b.assets.lovelace) {
    return -1;
  } else if (a.assets.lovelace < b.assets.lovelace) {
    return 1;
  } else {
    return 0;
  }
}

export function sortAsc(a: Utxo, b: Utxo): number {
  if (a.assets.lovelace > b.assets.lovelace) {
    return 1;
  } else if (a.assets.lovelace < b.assets.lovelace) {
    return -1;
  } else {
    return 0;
  }
}

export function toOwner(
  { address, data }: { address?: string; data?: D.Address },
): string {
  const { payment } = Addresses.inspect(
    address || toAddress(
      data!,
      lucid,
    ),
  );
  if (payment?.type === "Key") {
    return Utils.encodeBech32("addr_vkh", payment.hash);
  } else if (payment?.type === "Script") {
    return Utils.encodeBech32("script", payment.hash);
  }
  return "";
}

export function fromAddress(address: string): D.Address {
  // We do not support pointer addresses!

  const { payment, delegation } = Addresses.inspect(
    address,
  );

  if (!payment) throw new Error("Not a valid payment address.");

  return {
    paymentCredential: payment?.type === "Key"
      ? {
        VerificationKeyCredential: [payment.hash],
      }
      : { ScriptCredential: [payment.hash] },
    stakeCredential: delegation
      ? {
        Inline: [
          delegation.type === "Key"
            ? {
              VerificationKeyCredential: [delegation.hash],
            }
            : { ScriptCredential: [delegation.hash] },
        ],
      }
      : null,
  };
}

export function toAddress(address: D.Address, lucid: Lucid): string {
  const paymentCredential = (() => {
    if ("VerificationKeyCredential" in address.paymentCredential) {
      return Addresses.keyHashToCredential(
        address.paymentCredential.VerificationKeyCredential[0],
      );
    } else {
      return Addresses.scriptHashToCredential(
        address.paymentCredential.ScriptCredential[0],
      );
    }
  })();
  const stakeCredential = (() => {
    if (!address.stakeCredential) return undefined;
    if ("Inline" in address.stakeCredential) {
      if ("VerificationKeyCredential" in address.stakeCredential.Inline[0]) {
        return Addresses.keyHashToCredential(
          address.stakeCredential.Inline[0].VerificationKeyCredential[0],
        );
      } else {
        return Addresses.scriptHashToCredential(
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
  const value = new Map() as D.Value;
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

export function checkVariableFee(fee: number): bigint {
  if (fee <= 0) throw new Error("Variable fee needs to be greater than 0.");
  return BigInt(Math.floor(1 / (fee / 10)));
}
