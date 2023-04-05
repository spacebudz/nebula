// deno-lint-ignore-file no-unused-vars

import {
  BidAndListingEventData,
  BidOpenEventData,
  BidSwapEventData,
  Config,
  MarketplaceEvent,
  SaleEventData,
} from "./src/types.ts";

export const config: Config = {
  scriptHash: "6b5d9fa53ca28b537b7f61ef8321f6a2ba620df844ce769d2aafe59d",
  bidPolicyId: "9785fa0349c462aa109f68110fc350cbc9fcbe5c6f6e27ac4aa3d351",
  projects: ["4523c5e21d409b81c95b45b0aea275b8ea1406e6cafea5583b9f8a5f"],
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
