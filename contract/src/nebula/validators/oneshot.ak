use aiken/list
use aiken/transaction.{OutputReference, ScriptContext}

validator mint(output_reference: OutputReference) {
  fn(_redeemer: Void, ctx: ScriptContext) -> Bool {
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
}
