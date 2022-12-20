// deno-lint-ignore-file no-unused-vars

// Sample config (preprod network)

import {
  BidAndListingBundleEventData,
  BidAndListingSingleEventData,
  BidOpenEventData,
  Config,
  MarketplaceEvent,
  SaleBundleEventData,
  SaleSingleEventData,
} from "./src/types.ts";

export const config: Config = {
  scriptHash: "49f3072273af97cb3eedf70318479bd838bcb121d7d42d826799304a",
  bidPolicyId: "138434e35d556eaefecca3330025e3afccd8566c6af5303da8cca368",
  projects: ["8da99f2c04edd1c54993c74a36e8da8d9985334d9429d881e72e7e41"],
  startPoint: {
    hash: "0ac686ccb4900ae8bea9e75a7dbdf09bd306266570e8616d33e2ee5b7ef9b263",
    slot: 15865789,
  },
};

export function eventsHandler(events: MarketplaceEvent[]) {
  for (const event of events) {
    switch (event.type) {
      case "BidBundle": {
        const eventData: BidAndListingBundleEventData = event.data;
        // Your logic here
        break;
      }
      case "BidOpen": {
        const eventData: BidOpenEventData = event.data;
        // Your logic here
        break;
      }
      case "BidSingle": {
        const eventData: BidAndListingSingleEventData = event.data;
        // Your logic here
        break;
      }
      case "ListingBundle": {
        const eventData: BidAndListingBundleEventData = event.data;
        // Your logic here
        break;
      }
      case "ListingSingle": {
        const eventData: BidAndListingSingleEventData = event.data;
        // Your logic here
        break;
      }
      case "BuyBundle": {
        const eventData: SaleBundleEventData = event.data;
        // Your logic here
        break;
      }
      case "BuySingle": {
        const eventData: SaleSingleEventData = event.data;
        // Your logic here
        break;
      }
      case "SellBundle": {
        const eventData: SaleBundleEventData = event.data;
        // Your logic here
        break;
      }
      case "SellSingle": {
        const eventData: SaleSingleEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidBundle": {
        const eventData: BidAndListingBundleEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidOpen": {
        const eventData: BidOpenEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidSingle": {
        const eventData: BidAndListingSingleEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelListingBundle": {
        const eventData: BidAndListingBundleEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelListingSingle": {
        const eventData: BidAndListingSingleEventData = event.data;
        // Your logic here
        break;
      }
    }
  }
}
