use aiken/list
use aiken/transaction.{OutputReference, ScriptContext}

fn mint(output_reference: OutputReference, _, ctx: ScriptContext) -> Bool {
  when
    list.find(
      ctx.transaction.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  is {
    Some(_) -> True
    None -> False
  }
}
