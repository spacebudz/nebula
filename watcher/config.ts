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
  scriptHash: "0cee3f2b5ee5913be062a0cd940fb6fd2754aca88c231710b3f272ad",
  bidPolicyId: "188ea8a2dce433e15daab5f18dd46be25ad2ae73d3d071bb744e9d30",
  projects: ["8da99f2c04edd1c54993c74a36e8da8d9985334d9429d881e72e7e41"],
  startPoint: {
    hash: "6bdfd391f9095544f8b04d998e789df7a2237e3523e797aef714f323cf2e2021",
    slot: 15067500,
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
