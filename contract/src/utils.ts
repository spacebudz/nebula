import { Constr, Data, Redeemer } from "../../deps.ts";
import { TradeAction } from "../../common/types.ts";

export function toAction(action: TradeAction): Redeemer {
  return Data.to(new Constr(action, []));
}
