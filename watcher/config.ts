// deno-lint-ignore-file no-unused-vars

// Sample config (preprod network)

import {
  BidAndListingEventData,
  BidOpenEventData,
  BidSwapEventData,
  Config,
  MarketplaceEvent,
  SaleEventData,
} from "./src/types.ts";

export const config: Config = {
  scriptHash: "6b119d59fb18d5a67d6713f61c5f34b3ffe35776d9aa372cad7f761e",
  bidPolicyId: "f2064327c97a911c04139cc4b40a8d4836752c27fc4b0e97de77e1b3",
  projects: ["8da99f2c04edd1c54993c74a36e8da8d9985334d9429d881e72e7e41"],
  startPoint: {
    hash: "7328ac27f51c83d7e565d84272fdcb76cedb3c6ac878b8a02bc129c6d79bf3c7",
    slot: 18892999,
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
      case "SellSwap": {
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
      case "CancelBidSwap": {
        const eventData: BidSwapEventData = event.data;
        // Your logic here
        break;
      }
    }
  }
}

export function onChange() {
  // optionally handle db changes
}
