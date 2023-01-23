// deno-lint-ignore-file no-unused-vars

// Sample config (preprod network)

import {
  BidAndListingEventData,
  BidOpenEventData,
  Config,
  MarketplaceEvent,
  SaleEventData,
} from "./src/types.ts";

export const config: Config = {
  scriptHash: "485bbed9c7134b0368bab01916e0ac597278707686f5fc5f709bd8f3",
  bidPolicyId: "93bada1436feec036338162558adf517b72603430b0e5c0a54d2c2a0",
  projects: ["8da99f2c04edd1c54993c74a36e8da8d9985334d9429d881e72e7e41"],
  startPoint: {
    hash: "92c398358efc8c3b55d230c9e2355a9421b11097da3e262373fba0c2765a92a2",
    slot: 17781828,
  },
};

export function eventsHandler(events: MarketplaceEvent[]) {
  for (const event of events) {
    switch (event.type) {
      case "BidBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "BidOpen": {
        const eventData: BidOpenEventData = event.data;
        // Your logic here
        break;
      }
      case "BidSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "ListingBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "ListingSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "BuyBundle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "BuySingle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "SellBundle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "SellSingle": {
        const eventData: SaleEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidOpen": {
        const eventData: BidOpenEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelBidSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelListingBundle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
      case "CancelListingSingle": {
        const eventData: BidAndListingEventData = event.data;
        // Your logic here
        break;
      }
    }
  }
}
