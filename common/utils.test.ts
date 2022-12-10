import { assertEquals } from "https://deno.land/std@0.145.0/testing/asserts.ts";
import { Lucid } from "../deps.ts";
import {
  addressToData,
  assetsToData,
  dataToAddress,
  dataToAssets,
} from "./utils.ts";

const lucid = await Lucid.new(undefined, "Preview");

Deno.test("Address <> PlutusData", () => {
  const address =
    "addr_test1qq90qrxyw5qtkex0l7mc86xy9a6xkn5t3fcwm6wq33c38t8nhh356yzp7k3qwmhe4fk0g5u6kx5ka4rz5qcq4j7mvh2sts2cfa";
  const address2 =
    "addr_test1wqm0gyuht0ng20u3c7f6gcylt5dk0kvlhmcvgp87xx8wxmqy3h350";

  assertEquals(
    address,
    dataToAddress(addressToData(address), lucid),
  );
  assertEquals(
    address2,
    dataToAddress(addressToData(address2), lucid),
  );
});

Deno.test("Assets <> PlutusData", () => {
  const assets = { lovelace: 50000000n, ["31"]: 1n, ["313131"]: 10000n };

  assertEquals(
    assets,
    dataToAssets(assetsToData(assets)),
  );
});
