import { Config, MarketplaceEvent } from "./types.ts";
import { parse } from "https://deno.land/std@0.119.0/flags/mod.ts";
import packageInfo from "../../package.json" assert { type: "json" };
import { resolvePath } from "./utils.ts";

export const flags = parse(Deno.args, {
  string: ["ogmios-url", "database", "config"],
  boolean: ["sync", "version", "help"],
});

function usage(): string {
  return `Nebula Watcher usage:
        ( --ogmios-url )
        ( --database )
        [ --config ]
        [ --sync ]
        [ --version ]
        [ --help ]

Available options: 
        --ogmios-url        URL to Ogmios instance. e.g. ws://localhost:1337
        --database          Path to database.
        --config            Path to the config file. Required flag, but if left out the default SpaceBudz config is loaded.
        --sync              Writes to the database in less intervals to speed up sync time. Also doesn't trigger events.
        --version           Show the version.
        --help              Show this help text.`;
}

if (flags.version) {
  console.log(`Nebula Watcher version ${packageInfo.version}`);
  Deno.exit();
}

if (flags.help) {
  console.log(usage());
  Deno.exit();
}

if (!flags["ogmios-url"]) {
  console.log(usage());
  throw "--ogmios-url flag required.";
}

if (!flags.database) {
  console.log(usage());
  throw "--database flag required.";
}

export const { config, eventsHandler }: {
  config: Config;
  eventsHandler: (events: MarketplaceEvent[]) => unknown;
} = await import(
  resolvePath(flags.config || new URL("../config.ts", import.meta.url)).href
);
