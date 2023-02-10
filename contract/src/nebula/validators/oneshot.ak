use aiken/list
use aiken/transaction.{OutputReference, ScriptContext}

fn mint(
  output_reference: OutputReference,
  _redeemer: Void,
  ctx: ScriptContext,
) -> Bool {
  let input =
    list.find(
      ctx.transaction.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  when input is {
    Some(_) -> True
    None -> False
  }
}
