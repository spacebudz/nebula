import { DB } from "https://deno.land/x/sqlite@v3.7.0/mod.ts";
import {
  checkpointToColor,
  fromMergedOutRef,
  fromMergedPoint,
  isEmptyString,
  parseJSONSafe,
  resolvePath,
  toMergedOutRef,
  toMergedPoint,
} from "./utils.ts";
import {
  BidDB,
  BidEventType,
  CancellationDB,
  CheckpointType,
  ListingDB,
  ListingEventType,
  MarketplaceEvent,
  MarketplaceEventType,
  SaleDB,
} from "./types.ts";
import { Json, OutRef, Point } from "../../deps.ts";
import { config, flags } from "./flags.ts";
// For syntax highlighting in vscode: forbeslindesay.vscode-sql-template-literal
function sql(s: TemplateStringsArray): string {
  return s[0];
}

const tableCreation = sql`
CREATE TABLE IF NOT EXISTS listings (
    outputReference TEXT PRIMARY KEY, -- tx hash + output index
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    spent BOOLEAN DEFAULT FALSE,
    listingType TEXT NOT NULL, -- SingleListing | BundleListing
    assets TEXT NOT NULl, -- { [policy id + asset name] : quantity } (nft or semi fungible)
    owner TEXT NOT NULL, -- payment credential bech32
    lovelace INTEGER NOT NULL,
    privateListing TEXT -- ? payment credential bech32
);

CREATE TABLE IF NOT EXISTS bids (
    outputReference TEXT PRIMARY KEY, -- tx hash + output index
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    spent BOOLEAN DEFAULT FALSE,
    bidType TEXT NOT NULL, -- BidSingle | BidBundle | BidOpen
    assets TEXT, -- ? { [policy id + asset name] : quantity } (nft or semi fungible)
    policyId TEXT, -- ? only policy id (open bid)
    constraints TEXT, -- ? constraints (open bid) e.g. {types: ["Lion"], traits: ["Axe", "Jo-Jo"]}
    owner TEXT NOT NULL, -- payment credential bech32
    lovelace INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sales (
    id INTEGER AUTOINCREMENT,
    txHash TEXT, -- tx hash
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    saleType TEXT NOT NULL, -- BuySingle | BuyBundle | SellSingle | SellBundle
    assets TEXT NOT NULL, -- { [policy id + asset name] : quantity } (nft or semi fungible)
    lovelace INTEGER NOT NULL,
    buyer TEXT, -- ? payment credential bech32
    seller TEXT, -- ? payment credential bech32
    PRIMARY KEY (id, txHash)
);

CREATE TABLE IF NOT EXISTS cancellations (
    id INTEGER AUTOINCREMENT,
    txHash TEXT, -- tx hash
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    cancelType TEXT NOT NULL, -- CancelBidSingle | CancelBidBundle | CancelBidOpen | CancelListingSingle | CancelListingBundle
    assets TEXT, -- ? { [policy id + asset name] : quantity } (nft or semi fungible)
    policyId TEXT, -- ? policy id (open bid)
    constraints TEXT, -- ? constraints (open bid) e.g. {types: ["Lion"], traits: ["Axe", "Jo-Jo"]}
    owner TEXT NOT NULL, -- payment credential bech32
    lovelace INTEGER NOT NULL,
    PRIMARY KEY (id, txHash)
);

CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slot INTEGER NOT NULL,
    headerHash TEXT NOT NULL,
    eventType TEXT NOT NULL,
    eventData TEXT NOT NULL
);

CREATE VIEW IF NOT EXISTS activity AS SELECT * FROM (
SELECT slot, SUBSTRING(outputReference, 0, 65) AS txHash, assets, listingType AS activityType, lovelace, NULL AS policyId FROM listings
UNION 
SELECT slot, SUBSTRING(outputReference, 0, 65) AS txHash, assets, bidType AS activityType, lovelace, policyId FROM bids
UNION
SELECT slot, txHash, assets, saleType AS activityType, lovelace, NULL AS policyId FROM sales
UNION
SELECT slot, txHash, assets, cancelType AS activityType, lovelace, policyId FROM cancellations
) ORDER BY slot DESC limit 100;

CREATE TABLE IF NOT EXISTS checkpoint (
    id INTEGER PRIMARY KEY,
    point TEXT NOT NULL,
    cleanupPoint TEXT NOT NULL
);
`;

class MarketplaceDB {
  db: DB;
  changes: number;

  constructor(db: DB, startPoint?: Point) {
    this.db = db;
    this.db.execute(tableCreation);
    this.changes = this.db.totalChanges;

    try {
      this.getCheckpoint();
    } catch (_e) {
      this.db.query(
        sql`INSERT INTO checkpoint (id, point, cleanupPoint) VALUES (:id, :point, :cleanupPoint)`,
        {
          id: 0,
          point: toMergedPoint(startPoint || { hash: "", slot: 0 }),
          cleanupPoint: toMergedPoint(startPoint || { hash: "", slot: 0 }),
        },
      );
    }
  }

  getBid(outRef: OutRef): BidDB | null {
    try {
      const [q] = this.db.queryEntries<{
        outputReference: string;
        slot: number;
        headerHash: string;
        spent: boolean;
        bidType: string;
        assets?: string;
        policyId?: string;
        constraints?: string;
        owner: string;
        lovelace: number;
      }>(
        sql`SELECT * FROM bids WHERE outputReference = :outRef`,
        { outRef: toMergedOutRef(outRef) },
      );
      return {
        outRef: fromMergedOutRef(q.outputReference),
        point: { hash: q.headerHash, slot: q.slot },
        type: q.bidType as BidEventType,
        assets: parseJSONSafe(q.assets),
        policyId: q.policyId,
        constraints: parseJSONSafe(q.constraints),
        owner: q.owner,
        lovelace: q.lovelace,
      };
    } catch (_e) {
      return null;
    }
  }

  addBid(
    { outRef, point, type, assets, policyId, constraints, owner, lovelace }:
      BidDB,
  ) {
    this.db.query(
      sql`
      INSERT INTO bids (outputReference, slot, headerHash, bidType, assets, policyId, constraints, owner, lovelace) 
      VALUES (:outRef, :slot, :hash, :type, :assets, :policyId, :constraints, :owner, :lovelace)
    `,
      {
        outRef: toMergedOutRef(outRef),
        slot: point.slot,
        hash: point.hash,
        type,
        assets: assets ? JSON.stringify(assets) : null,
        policyId,
        constraints: constraints ? JSON.stringify(constraints) : null,
        owner,
        lovelace,
      },
    );
  }

  spendBid(outRef: OutRef) {
    this.db.query(
      sql`UPDATE bids SET spent = TRUE WHERE outputReference = :outRef`,
      {
        outRef: toMergedOutRef(outRef),
      },
    );
  }

  addListing(
    { outRef, point, type, assets, owner, lovelace, privateListing }: ListingDB,
  ) {
    this.db.query(
      sql`
      INSERT INTO listings (outputReference, slot, headerHash, listingType, assets, owner, lovelace, privateListing) 
      VALUES (:outRef, :slot, :hash, :type, :assets, :owner, :lovelace, :privateListing)
    `,
      {
        outRef: toMergedOutRef(outRef),
        slot: point.slot,
        hash: point.hash,
        type,
        assets: assets ? JSON.stringify(assets) : null,
        owner,
        lovelace,
        privateListing,
      },
    );
  }

  spendListing(outRef: OutRef) {
    this.db.query(
      sql`UPDATE listings SET spent = TRUE WHERE outputReference = :outRef`,
      {
        outRef: toMergedOutRef(outRef),
      },
    );
  }

  getListing(outRef: OutRef): ListingDB | null {
    try {
      const [q] = this.db.queryEntries<{
        outputReference: string;
        slot: number;
        headerHash: string;
        spent: boolean;
        listingType: string;
        assets: string;
        owner: string;
        lovelace: number;
        privateListing?: string;
      }>(
        sql`SELECT * FROM listings WHERE outputReference = :outRef`,
        { outRef: toMergedOutRef(outRef) },
      );
      return {
        outRef: fromMergedOutRef(q.outputReference),
        point: { hash: q.headerHash, slot: q.slot },
        type: q.listingType as ListingEventType,
        assets: parseJSONSafe(q.assets),
        owner: q.owner,
        lovelace: q.lovelace,
        privateListing: q.privateListing,
      };
    } catch (_e) {
      return null;
    }
  }

  addSale({ txHash, point, type, assets, lovelace, buyer, seller }: SaleDB) {
    this.db.query(
      sql`
      INSERT INTO sales (txHash, slot, headerHash, saleType, assets, lovelace, buyer, seller) 
      VALUES (:txHash, :slot, :hash, :type, :assets, :lovelace, :buyer, :seller)
    `,
      {
        txHash,
        slot: point.slot,
        hash: point.hash,
        type,
        assets: JSON.stringify(assets),
        lovelace,
        buyer,
        seller,
      },
    );
  }

  addCancellation(
    { txHash, point, type, assets, policyId, constraints, owner, lovelace }:
      CancellationDB,
  ) {
    this.db.query(
      sql`
    INSERT INTO cancellations (txHash, slot, headerHash, cancelType, assets, policyId, constraints, owner, lovelace) 
    VALUES (:txHash, :slot, :hash, :type, :assets, :policyId, :constraints, :owner, :lovelace)
  `,
      {
        txHash,
        slot: point.slot,
        hash: point.hash,
        type,
        assets: assets ? JSON.stringify(assets) : null,
        policyId,
        constraints: constraints ? JSON.stringify(constraints) : null,
        owner,
        lovelace,
      },
    );
  }

  updateCheckpoint(event: CheckpointType, point: Point) {
    this.db.query(
      sql`UPDATE checkpoint SET point = :point WHERE id = 0`,
      {
        point: toMergedPoint(point),
      },
    );
    console.log(
      `%c${event}`,
      `color:${checkpointToColor[event]}`,
      new Date(),
      point.hash,
      "at slot",
      point.slot,
    );
  }

  updateCleanupCheckpoint(point: Point) {
    this.db.query(
      sql`UPDATE checkpoint SET cleanupPoint = :cleanupPoint WHERE id = 0`,
      {
        cleanupPoint: toMergedPoint(point),
      },
    );
    console.log(
      `%c${"Cleanup" as CheckpointType}`,
      `color:${checkpointToColor["Cleanup"]}`,
      new Date(),
      point.hash,
      "at slot",
      point.slot,
    );
  }

  getCheckpoint(): Point {
    const q = this.db.queryEntries<{ point: string }>(
      sql`SELECT point from checkpoint`,
    )[0]
      ?.point;
    if (q) return fromMergedPoint(q);
    throw new Error("No checkpoint found. Maybe DB not initialized yet.");
  }

  getCleanupCheckpoint(): Point {
    const q = this.db.queryEntries<{ cleanupPoint: string }>(
      sql`SELECT cleanupPoint from checkpoint`,
    )[0]
      ?.cleanupPoint;
    if (q) return fromMergedPoint(q);
    throw new Error("No checkpoint found. Maybe DB not initialized yet.");
  }

  cleanupDatabase() {
    const checkpoint = this.getCheckpoint();
    const cleanupPoint = this.getCleanupCheckpoint();

    /**
     * This only happens if there was no start point set and we start tracking from the tip.
     * We do not really cleanup the database here. We do only update the checkpoint.
     */
    if (isEmptyString(cleanupPoint.hash)) {
      this.updateCleanupCheckpoint(checkpoint);
      return;
    }

    /** Roughly 100 block (~30 min) confirmations needed until a cleanup happens. */
    if (checkpoint.slot - cleanupPoint.slot < 1800) return;

    this.db.query(sql`BEGIN`);

    this.db.query(
      sql`DELETE FROM listings WHERE slot < :slot AND spent = TRUE`,
      { slot: cleanupPoint.slot },
    );
    this.db.query(
      sql`DELETE FROM bids WHERE slot <= :slot AND spent = TRUE;`,
      { slot: cleanupPoint.slot },
    );

    this.updateCleanupCheckpoint(checkpoint);

    this.db.query(sql`COMMIT`);
  }

  rollbackDatabase(point: Point) {
    this.db.query(sql`BEGIN`);

    this.db.query(
      sql`DELETE FROM listings WHERE slot >= :slot AND headerHash != :hash; AND spent = FALSE`,
      { ...point },
    );
    this.db.query(
      sql`UPDATE listings SET spent = FALSE WHERE slot >= :slot AND headerHash != :hash AND spent = TRUE;`,
      { ...point },
    );

    this.db.query(
      sql`DELETE FROM bids WHERE slot >= :slot AND headerHash != :hash AND spent = FALSE;`,
      { ...point },
    );
    this.db.query(
      sql`UPDATE bids SET spent = FALSE WHERE slot >= :slot AND headerHash != :hash AND spent = TRUE;`,
      { ...point },
    );

    this.db.query(
      sql`DELETE FROM sales WHERE slot >= :slot AND headerHash != :hash;`,
      { ...point },
    );

    this.db.query(
      sql`DELETE FROM cancellations WHERE slot >= :slot AND headerHash != :hash;`,
      { ...point },
    );

    this.db.query(
      sql`DELETE FROM events WHERE slot >= :slot AND headerHash != :hash;`,
      { ...point },
    );

    this.db.query(sql`COMMIT`);
  }

  registerEvent(event: MarketplaceEvent, point: Point) {
    this.db.query(
      sql`INSERT INTO events (slot, headerHash, eventType, eventData) VALUES (:slot, :hash, :eventType, :eventData)`,
      {
        slot: point.slot,
        hash: point.hash,
        eventType: event.type,
        eventData: JSON.stringify(event.data),
      },
    );
  }

  /** Events will be stored in a buffer and only be triggered after x block confirmations. They will be deleted in case of rollbacks. */
  triggerEvents(
    point: Point,
    cb: (events: MarketplaceEvent[]) => unknown,
    confirmations = 5,
  ) {
    const events = this.db.queryEntries<
      { id: number; eventType: MarketplaceEventType; eventData: Json }
    >(
      sql`SELECT id, eventType, eventData FROM events WHERE slot <= :safeSlot`,
      { safeSlot: point.slot - confirmations * 20 }, // currently every 20 slots one new block
    );
    const parsedEvents: MarketplaceEvent[] = events.map((
      { eventType, eventData },
    ) => ({ type: eventType, data: parseJSONSafe(eventData) }));
    if (parsedEvents.length > 0) {
      cb(parsedEvents);
      this.db.query(sql`BEGIN`);
      events.forEach(({ id }) =>
        this.db.query(sql`DELETE FROM events WHERE id = :id`, { id })
      );
      this.db.query(sql`COMMIT`);
    }
  }
  close() {
    this.db.close();
  }

  hasChange(): boolean {
    if (this.changes !== this.db.totalChanges) {
      this.changes = this.db.totalChanges;
      return true;
    }
    return false;
  }
}

export const db = new MarketplaceDB(
  new DB(resolvePath(flags.database).pathname),
  config.startPoint,
);
