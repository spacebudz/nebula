import {
  Address,
  C,
  Constr,
  getAddressDetails,
  Json,
  Lucid,
  OutRef,
  PlutusData,
  Point,
} from "../../deps.ts";
import { dataToAddress } from "../../common/utils.ts";
import { CheckpointType } from "./types.ts";
import { isAbsolute, join } from "https://deno.land/std@0.167.0/path/mod.ts";

const lucid = await Lucid.new();

/** Return the payment credential from an address (in PlutusData) as Bech32.  */
export function toOwner(
  { address, data }: { address?: Address; data?: Constr<PlutusData> },
): string {
  const { paymentCredential } = getAddressDetails(
    address || dataToAddress(
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

export function toMergedOutRef(
  { txHash, outputIndex }: OutRef,
): string {
  return txHash + outputIndex;
}

export function fromMergedOutRef(
  mergedOutRef: string,
): OutRef {
  return {
    txHash: mergedOutRef.slice(0, 64),
    outputIndex: parseInt(mergedOutRef.slice(64)),
  };
}

export function toMergedPoint(
  { hash, slot }: Point,
): string {
  return hash + slot;
}

export function fromMergedPoint(
  mergedPoint: string,
): Point {
  return {
    hash: mergedPoint.slice(0, 64),
    slot: parseInt(mergedPoint.slice(64)),
  };
}

export function isEmptyString(str: string | null | undefined): boolean {
  return str == "0" || !str;
}

// deno-lint-ignore no-explicit-any
export const pipe = (...args: any[]) => args.reduce((acc, el) => el(acc));

export function parseJSONSafe(text?: string | null): Json {
  try {
    return JSON.parse(text!);
  } catch (_e) {
    return text;
  }
}

export const checkpointToColor: Record<CheckpointType, string> = {
  Bid: "orange",
  Listing: "blue",
  Cleanup: "yellow",
  Rollback: "red",
  Sale: "green",
  Sync: "lavender",
  Cancel: "orangered",
};

export function resolvePath(path: string | URL): string {
  console.log(path);
  console.log(Deno.cwd());
  if (path instanceof URL) return path.pathname;
  else if (/^(?:[a-z]+:)?\/\//i.test(path)) return path;
  else if (isAbsolute(path)) return path;
  return join(Deno.cwd(), path);
}
