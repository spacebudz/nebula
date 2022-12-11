import { serve } from "https://deno.land/std@0.167.0/http/server.ts";
import { serveFile } from "https://deno.land/std@0.167.0/http/file_server.ts";
import packageInfo from "../../package.json" assert { type: "json" };
import { parse } from "https://deno.land/std@0.119.0/flags/mod.ts";
import { DB } from "https://deno.land/x/sqlite@v3.7.0/mod.ts";
import { resolvePath } from "./utils.ts";

const queryFlags = parse(Deno.args, {
  string: ["database", "port"],
  boolean: ["version", "help"],
});

function usage(): string {
  return `Nebula Querier usage:
        ( --database )
        ( --port )
        [ --version ]
        [ --help ]

Available options: 
        --database          Path to database.
        --port              Port (Default: 3000).
        --version           Show the version.
        --help              Show this help text.`;
}

if (queryFlags.version) {
  console.log(`Nebula Querier version ${packageInfo.version}`);
  Deno.exit();
}

if (queryFlags.help) {
  console.log(usage());
  Deno.exit();
}

if (!queryFlags.database) {
  console.log(usage());
  throw "--database flag required.";
}

const dbRoute = new URLPattern({ pathname: "/db/marketplace.sqlite" });
const singleListingsRoute = new URLPattern({ pathname: "/listings/:policyId" });
const singleBidsRoute = new URLPattern({ pathname: "/bids/:policyId" });
const salesRoute = new URLPattern({ pathname: "/sales" });
const salesSummaryRoute = new URLPattern({ pathname: "/salesSummary" });
const activityRoute = new URLPattern({ pathname: "/activity" });

const db = new DB(resolvePath(queryFlags.database));

// For syntax highlighting in vscode: forbeslindesay.vscode-sql-template-literal
function sql(s: TemplateStringsArray): string {
  return s[0];
}

// This needs to be extended. Right now querying is very basic.

serve((req) => {
  if (dbRoute.test(req.url)) {
    return serveFile(
      req,
      resolvePath(queryFlags.database),
    );
  } else if (singleListingsRoute.test(req.url)) {
    const policyId: string = singleListingsRoute.exec(req.url)?.pathname.groups
      .policyId!;
    if (!policyId) {
      return new Response(JSON.stringify({ error: "Policy id not found." }), {
        status: 400,
      });
    }
    const listings = db.queryEntries(
      sql`SELECT * FROM listings WHERE listingType = 'ListingSingle' AND nfts LIKE :policyId AND spent = FALSE`,
      { policyId: policyId + "%" },
    );
    return new Response(JSON.stringify(listings), { status: 200 });
  } else if (singleBidsRoute.test(req.url)) {
    const policyId: string = singleBidsRoute.exec(req.url)?.pathname.groups
      .policyId!;
    if (!policyId) {
      return new Response(JSON.stringify({ error: "Policy id not found." }), {
        status: 400,
      });
    }
    const bids = db.queryEntries(
      sql`SELECT * FROM bids WHERE (bidType = 'BidSingle' AND nfts LIKE :policyIdStartsWith) OR (bidType = 'BidOpen' AND policyId = :policyId) AND spent = FALSE`,
      { policyId, policyIdStartsWith: policyId + "%" },
    );
    return new Response(JSON.stringify(bids), { status: 200 });
  } else if (salesRoute.test(req.url)) {
    const sales = db.queryEntries(sql`SELECT * FROM sales`);
    return new Response(
      JSON.stringify(sales),
      {
        status: 200,
      },
    );
  } else if (salesSummaryRoute.test(req.url)) {
    const [salesSummary] = db.query(
      sql`SELECT COUNT(*), SUM(lovelace) FROM sales`,
    );
    return new Response(
      JSON.stringify({
        totalSales: salesSummary[0],
        totalVolume: salesSummary[1],
      }),
      {
        status: 200,
      },
    );
  } else if (activityRoute.test(req.url)) {
    const activity = db.queryEntries(
      sql`SELECT * FROM activity`,
    );
    return new Response(JSON.stringify(activity), {
      status: 200,
    });
  }
  return new Response("404 Not Found", { status: 404 });
}, { port: queryFlags.port || 3000 });
