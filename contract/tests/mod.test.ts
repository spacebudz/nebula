import {
  Assets,
  Constr,
  Data,
  Emulator,
  fromText,
  generateSeedPhrase,
  Lucid,
  SpendingValidator,
  toUnit,
} from "../../deps.ts";
import { Contract } from "../mod.ts";
import { assert } from "https://deno.land/std@0.145.0/testing/asserts.ts";
import { idToBud } from "../../common/utils.ts";

async function generateAccount(assets: Assets) {
  const seedPhrase = generateSeedPhrase();
  return {
    seedPhrase,
    address: await (await Lucid.new(undefined, "Custom"))
      .selectWalletFromSeed(seedPhrase).wallet.address(),
    assets,
  };
}

const ACCOUNT_0 = await generateAccount({ lovelace: 30000000000n });
const ACCOUNT_1 = await generateAccount({ lovelace: 75000000000n });

const emulator = new Emulator([ACCOUNT_0, ACCOUNT_1]);

const lucid = await Lucid.new(emulator);

lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase);

// ---- SETUP

async function createNFTs() {
  const { paymentCredential } = lucid.utils.getAddressDetails(
    await lucid.wallet.address(),
  );
  const script = lucid.utils.nativeScriptFromJson({
    type: "all",
    scripts: [
      { type: "after", slot: 10 },
      { type: "sig", keyHash: paymentCredential?.hash! },
    ],
  });

  emulator.awaitBlock(10);

  const policyId = lucid.utils.mintingPolicyToId(script);

  const unspendableScript: SpendingValidator = {
    type: "PlutusV2",
    script: "54530100003222233335734600893124c4c9312501",
  };
  const unspendableAddress = lucid.utils.validatorToAddress(unspendableScript);

  const tx = await lucid.newTx().mintAssets({
    [toUnit(policyId, fromText("Bud0"), 100)]: 1n,
    [toUnit(policyId, fromText("Bud0"), 222)]: 1n,
    [toUnit(policyId, fromText("Bud25"), 100)]: 1n,
    [toUnit(policyId, fromText("Bud25"), 222)]: 1n,
    [toUnit(policyId, fromText("Bud32"), 100)]: 1n,
    [toUnit(policyId, fromText("Bud32"), 222)]: 1n,
    [toUnit(policyId, fromText("Bud1111"), 100)]: 1n,
    [toUnit(policyId, fromText("Bud1111"), 222)]: 1n,
  })
    .payToContract(
      unspendableAddress,
      Data.to(
        new Constr(0, [
          Data.fromJson({
            name: "SpaceBud #0",
            image: "ipfs://QmSNJ78jdqwbd6yRtHzLrXNnaY8vnuuGN4AbJbMVd2XRuC",
            traits: ["Special Background", "Axe", "Belt"],
            type: "Cat",
            imageHash: "sha256",
          }),
          1n,
          new Constr(0, []),
        ]),
      ),
      {
        [toUnit(policyId, fromText("Bud0"), 100)]: 1n,
      },
    )
    .payToContract(
      unspendableAddress,
      Data.to(
        new Constr(0, [
          Data.fromJson({
            name: "SpaceBud #25",
            image: "ipfs://QmSNJ78jdqwbd6yRtHzLrXNnaY8vnuuGN4AbJbMVd2XRuC",
            traits: ["Belt", "Axe"],
            type: "Dino",
            imageHash: "sha256",
          }),
          1n,
          new Constr(0, []),
        ]),
      ),
      {
        [toUnit(policyId, fromText("Bud25"), 100)]: 1n,
      },
    )
    .payToContract(
      unspendableAddress,
      Data.to(
        new Constr(0, [
          Data.fromJson({
            name: "SpaceBud #32",
            image: "ipfs://QmSNJ78jdqwbd6yRtHzLrXNnaY8vnuuGN4AbJbMVd2XRuC",
            traits: ["Jo-Jo", "Covered Helmet"],
            type: "Dog",
            imageHash: "sha256",
          }),
          1n,
          new Constr(0, []),
        ]),
      ),
      {
        [toUnit(policyId, fromText("Bud32"), 100)]: 1n,
      },
    )
    .payToContract(
      unspendableAddress,
      Data.to(
        new Constr(0, [
          Data.fromJson({
            name: "SpaceBud #1111",
            image: "ipfs://QmSNJ78jdqwbd6yRtHzLrXNnaY8vnuuGN4AbJbMVd2XRuC",
            traits: [],
            type: "Bull",
            imageHash: "sha256",
          }),
          1n,
          new Constr(0, []),
        ]),
      ),
      {
        [toUnit(policyId, fromText("Bud1111"), 100)]: 1n,
      },
    )
    .validFrom(emulator.now())
    .attachMintingPolicy(script).complete();

  const signedTx = await tx.sign().complete();
  return { txHash: await signedTx.submit(), policyId };
}

const { txHash: createNFTsTxHash, policyId } = await createNFTs();
await lucid.awaitTx(createNFTsTxHash);

emulator.awaitBlock(50);

const { txHash, royaltyToken } = await Contract.createRoyalty(
  lucid,
  [{
    address: "addr_test1vqdr6txha8u2q4c5h2xy5rvk7lslvr252k2khln5mea32lcf82jnm",
    minFee: 400000n,
    fee: 0.016,
    // maxFee: 1500000n,
  }, {
    address: "addr_test1vz54zm2fmqxzm6m6jq577ssu4z67tw0qk2xm6m7zceexlfc7qyr5h",
    fee: 0.004,
  }, {
    address: "addr_test1vr0yva2r7l8wjyfcpptewfu6gk88gqsvxzlqkvjuatdpr5st9chpv",
    fee: 0.004,
    maxFee: 1500000n,
  }, {
    address: (await generateAccount({ lovelace: 0n })).address,
    fee: 0.004,
    maxFee: 1400000n,
  }, {
    address: (await generateAccount({ lovelace: 0n })).address,
    fee: 0.004,
  }],
  ACCOUNT_0.address,
);

await lucid.awaitTx(txHash);

const deployHash = await new Contract(lucid, {
  royaltyToken,
  owner: ACCOUNT_0.address,
  policyId,
}).deployScripts();

await lucid.awaitTx(deployHash);

const contract = new Contract(lucid, {
  royaltyToken,
  owner: ACCOUNT_0.address,
  policyId,
  deployHash,
  aggregatorFee: [{
    address: (await generateAccount({ lovelace: 0n })).address,
    minFee: 400000n,
    fee: 0.016,
  }],
});

// ---- SETUP

Deno.test("List and buy", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.list([idToBud(0)], 800000000n),
  );
  const [listing] = await contract.getListings(idToBud(0));
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.buy([listing]),
  );
});

Deno.test("Bid and sell", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.bid({ [idToBud(0)]: 1n }, 800000000n),
  );
  const [bid] = await contract.getBids({ assetName: idToBud(0) });
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.sell([{ bidUtxo: bid }]),
  );
});

Deno.test("List and cancel", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.list({ [idToBud(0)]: 1n }, 800000000n),
  );
  const [listing] = await contract.getListings(idToBud(0));
  try {
    await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
      await contract.cancelListing(listing),
    );
    assert(false);
  } catch (_e) {
    assert(true);
  }
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.cancelListing(listing),
  );
});

Deno.test("Bid and cancel", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.bid([idToBud(0)], 800000000n),
  );
  const [bid] = await contract.getBids({ assetName: idToBud(0) });
  try {
    await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
      await contract.cancelBid(bid),
    );
    assert(false);
  } catch (_e) {
    assert(true);
  }
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.cancelBid(bid),
  );
});

Deno.test("Collection offer and sell", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.bidOpen(11100000n, {
      types: ["Cat"],
      traits: [{ trait: "Axe" }],
    }),
  );
  const [bid] = await contract.getBids("Open");
  try {
    await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
      await contract.sell([{ bidUtxo: bid, assetName: idToBud(25) }]),
    );
    assert(false);
  } catch (_e) {
    assert(true);
  }
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.sell([{ bidUtxo: bid, assetName: idToBud(0) }]),
  );
});

Deno.test("Swap", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.bidSwap({ assetNames: [idToBud(32), idToBud(1111)] }, {
      specific: [idToBud(0)],
    }),
  );
  const [bid] = await contract.getBids("Swap");
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.sell([{ bidUtxo: bid }]),
  );
});

Deno.test("Swap with constraints", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.bidSwap({ assetNames: [idToBud(1111)] }, {
      constraints: { types: ["Dino"] },
    }),
  );
  const [bid] = await contract.getBids("Swap");
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.sell([{ bidUtxo: bid, assetName: idToBud(25) }]),
  );
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await lucid.newTx().payToAddress(ACCOUNT_1.address, {
      [contract.config.policyId + idToBud(1111)]: 1n,
    }).complete().then((tx) => tx.sign().complete()).then((tx) => tx.submit()),
  );
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await lucid.newTx().payToAddress(ACCOUNT_0.address, {
      [contract.config.policyId + idToBud(25)]: 1n,
    }).complete().then((tx) => tx.sign().complete()).then((tx) => tx.submit()),
  );
});

Deno.test("Combine endpoints", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.list([idToBud(25)], 800000000n),
  );
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.bid([idToBud(25)], 500000000n),
  );
  const [bid] = await contract.getBids({ assetName: idToBud(25) });
  const [listing] = await contract.getListings(idToBud(25));
  const doMultiple = await lucid
    .selectWalletFromSeed(ACCOUNT_1.seedPhrase)
    .newTx()
    .compose(await contract._list([idToBud(32)], 10000000000n))
    .compose(await contract._bid([idToBud(22)], 30000000n))
    .compose(await contract._bid([idToBud(237)], 20000000n))
    .compose(await contract._cancelBid(bid))
    .compose(await contract._buy(listing))
    .compose(await contract._bidOpen(200000000n, { types: ["Ape"] }))
    .complete();
  const signedTx = await doMultiple.sign().complete();
  await lucid.awaitTx(await signedTx.submit());
});

Deno.test("Bundle bid", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.bid([idToBud(25), idToBud(1111)], 1000000000n),
  );
  const [bid] = await contract.getBids("Bundle");
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.sell([{ bidUtxo: bid }]),
  );
});

Deno.test("Bundle listing", async () => {
  await lucid.selectWalletFromSeed(ACCOUNT_0.seedPhrase).awaitTx(
    await contract.list([idToBud(25), idToBud(1111)], 1000000000n),
  );
  const [listing] = await contract.getListings(idToBud(25));
  await lucid.selectWalletFromSeed(ACCOUNT_1.seedPhrase).awaitTx(
    await contract.buy([listing]),
  );
});
