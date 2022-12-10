import {
  Block,
  createClient,
  Point,
  toShelleyCompatibleBlock,
} from "../../deps.ts";
import { db } from "./db.ts";
import { eventsHandler, flags } from "./flags.ts";
import { isEmptyString, pipe } from "./utils.ts";
import { watchBlock } from "./watcher.ts";

const CHECKPOINT_INTERVAL = flags.sync ? 10000 : 200;
const CONFIRMATIONS_NEEDED = 5;

function rollForward(block: Block, hasExited: boolean) {
  const { blockShelley } = toShelleyCompatibleBlock(block)!;
  const point: Point = {
    hash: blockShelley.headerHash,
    slot: blockShelley.header.slot,
  };

  watchBlock(blockShelley);

  if (!flags.sync) db.triggerEvents(point, eventsHandler, CONFIRMATIONS_NEEDED);

  if (
    !flags.sync && blockShelley.header.blockHeight % CHECKPOINT_INTERVAL === 0
  ) db.cleanupDatabase();

  if (
    blockShelley.header.blockHeight % CHECKPOINT_INTERVAL === 0 || hasExited
  ) db.updateCheckpoint("Sync", point);
}

function rollBackward(point: Point) {
  db.rollbackDatabase(point);
  db.updateCheckpoint("Rollback", point);
}

const client = await createClient({
  url: flags["ogmios-url"],
  startPoint: pipe(
    db.getCheckpoint(),
    (point: Point) => isEmptyString(point.hash) ? "tip" : point,
  ),
}, {
  rollBackward,
  rollForward,
});

client.start();
client.onExit(() => {
  console.log("Shutting down, waiting for next block..");
});
globalThis.addEventListener("unload", () => {
  db.close();
});
