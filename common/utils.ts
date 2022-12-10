import {
  Address,
  Assets,
  Constr,
  getAddressDetails,
  Lucid,
  PlutusData,
  toLabel,
  utf8ToHex,
  UTxO,
} from "../deps.ts";

export function idToBud(id: number): string {
  return toLabel(222) + utf8ToHex(`Bud${id}`);
}

export function colorToBerry(color: string): string {
  return utf8ToHex(`Berry${color}`);
}

export function idToMatrix(id: number): string {
  return utf8ToHex(`Matrix${id}`);
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

export function dataToAddress(
  plutusData: Constr<PlutusData>,
  lucid: Lucid,
): Address {
  const paymentPart = plutusData.fields[0] as Constr<PlutusData>;
  const paymentCredential = paymentPart.index === 0
    ? lucid.utils.keyHashToCredential(paymentPart.fields[0] as string)
    : lucid.utils.scriptHashToCredential(paymentPart.fields[0] as string);

  const stakePart = unwrapMaybe(
    plutusData.fields[1] as Constr<PlutusData>,
  ) as
    | Constr<PlutusData>
    | null;
  const stakeCredential = stakePart
    ? (stakePart.fields[0] as Constr<PlutusData>).index === 0
      ? lucid.utils.keyHashToCredential(
        (stakePart.fields[0] as Constr<PlutusData>).fields[0] as string,
      )
      : lucid.utils.scriptHashToCredential(
        (stakePart.fields[0] as Constr<PlutusData>).fields[0] as string,
      )
    : undefined;

  return lucid.utils.credentialToAddress(paymentCredential, stakeCredential);
}

export function addressToData(address: Address): Constr<PlutusData> {
  const { paymentCredential, stakeCredential } = getAddressDetails(address);
  const paymentPart = paymentCredential?.type === "Key"
    ? new Constr(0, [paymentCredential!.hash])
    : new Constr(1, [paymentCredential!.hash]);

  const stakePart = stakeCredential
    ? stakeCredential.type === "Key"
      ? new Constr(0, [new Constr(0, [stakeCredential!.hash])])
      : new Constr(0, [new Constr(1, [stakeCredential!.hash])])
    : null;

  return new Constr(0, [paymentPart, wrapMaybe(stakePart)]);
}

export function dataToAssets(
  plutusData: Map<string, Map<string, bigint>>,
): Assets {
  const result: Assets = { lovelace: plutusData.get("")?.get("") || 0n };

  for (const [policyId, assets] of plutusData) {
    if (policyId === "") continue;
    for (const [assetName, amount] of assets) {
      result[policyId + assetName] = amount;
    }
  }
  return result;
}

export function assetsToData(assets: Assets): Map<string, Map<string, bigint>> {
  const valueMap = new Map<string, Map<string, bigint>>();
  if (assets.lovelace) valueMap.set("", new Map([["", assets.lovelace]]));

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
    valueMap.set(policyId, assetsMap);
  });
  return valueMap;
}

export function wrapMaybe(data?: PlutusData | null): PlutusData {
  if (data) return new Constr(0, [data!]);
  return new Constr(1, []);
}

export function unwrapMaybe(data: Constr<PlutusData>): PlutusData | null {
  if (data.index === 0) return data.fields[0];
  return null;
}
