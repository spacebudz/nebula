import { Assets, Json, OutRef, Point, Unit } from "../../deps.ts";
import { CheckpointType } from "./types.ts";
import {
  isAbsolute,
  toFileUrl,
} from "https://deno.land/std@0.167.0/path/mod.ts";

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

export function parseJSONSafe(text?: string | null): Json | null {
  try {
    return JSON.parse(text!);
  } catch (_e) {
    return text ? text : null;
  }
}

export function assetsToAsssetsWithNumber(
  assets: Assets,
): Record<Unit, number> {
  return Object.fromEntries(
    Object.entries(assets).map(([unit, quantity]) => (
      [unit, Number(quantity)]
    )),
  );
}

export function transformArrayToString(
  arr: string[],
): string | string[] | null | undefined {
  return arr.length > 1 ? arr : arr[0];
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

export function resolvePath(path: string | URL): URL {
  if (path instanceof URL) return path;
  else if (/^(?:[a-z]+:)?\/\//i.test(path)) return new URL(path);
  else if (isAbsolute(path)) return toFileUrl(path);
  return toFileUrl(Deno.cwd() + new URL(`file:///${path}`).pathname);
}
