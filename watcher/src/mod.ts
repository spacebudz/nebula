import {
  Block,
  createChainSynchronizationClient,
  createInteractionContext,
  Origin,
  Point,
  Tip,
} from "../../deps.ts";
import { db } from "./db.ts";
import { eventsHandler, flags, onChange } from "./flags.ts";
import { isEmptyString, pipe, pointToPointDB } from "./utils.ts";
import { watchBlock } from "./watcher.ts";
import { PointDB } from "./types.ts";

const CHECKPOINT_INTERVAL = flags.sync ? 10000 : 200;
const CONFIRMATIONS_NEEDED = 5;

let hasExited = false;
Deno.addSignalListener("SIGINT", () => {
  hasExited = true;
});

function rollForward({ block }: {
  block: Block;
  tip: Tip | Origin;
}, nextBlock: () => void): Promise<void> {
  if (block.type !== "praos") return new Promise((res) => res());
  const point: PointDB = {
    hash: block.id,
    slot: block.slot,
  };

  watchBlock(block);

  if (!flags.sync) db.triggerEvents(point, eventsHandler, CONFIRMATIONS_NEEDED);

  if (
    !flags.sync && block.height % CHECKPOINT_INTERVAL === 0
  ) db.cleanupDatabase();

  if (
    block.height % CHECKPOINT_INTERVAL === 0 || hasExited
  ) db.updateCheckpoint("Sync", point);
  if (db.hasChange()) onChange();

  if (hasExited) {
    if (client.context.socket.readyState === client.context.socket.OPEN) {
      return client.shutdown();
    } else {
      return new Promise((res) => res());
    }
  }

  return new Promise((res) => res(nextBlock()));
}

function rollBackward({ point }: {
  point: Point | Origin;
  tip: Tip | Origin;
}, nextBlock: () => void): Promise<void> {
  db.rollbackDatabase(pointToPointDB(point));
  db.updateCheckpoint("Rollback", pointToPointDB(point));
  if (db.hasChange()) onChange();
  return new Promise((res) => res(nextBlock()));
}

const startPoint: [Point] | undefined = pipe(
  db.getCheckpoint(),
  (point: PointDB) =>
    isEmptyString(point.hash)
      ? undefined
      : [{ id: point.hash, slot: point.slot }],
);

const connection = pipe(
  flags["ogmios-url"].split(":"),
  (url: string) => ({
    host: url[1].slice(2),
    port: parseInt(url[2]),
    tls: url[0] === "wss",
  }),
);

const context = await createInteractionContext(
  (err) => console.error(err),
  () => console.log("Shutting down, waiting for next block.."),
  {
    connection,
  },
);

const client = await createChainSynchronizationClient(context, {
  rollForward,
  rollBackward,
});
client.resume(startPoint);

globalThis.addEventListener("unload", () => {
  db.close();
});
