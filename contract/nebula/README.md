# Nebula Contract

⚠️ The contract hasn't been thoroughly tested yet. Use the contract at your own
risk.

## Needs fix

- [ ] Lucid needs to be updated in order to support payment credentials properly
      with the Blockfrost provider. UTxOs returned by Blockfrost from specific
      queries do not contain addresses and so the address right now needs to be
      more or less guessed, which could lead to wrong script context creations.

## Todo

- [ ] Move away from PlutusTx -> Aiken
- [ ] Find a way to discover script buyer/seller properly.
- [ ] NFT <-> NFT trades (the problem here is they require a different fee
      structure, since there aren't any ADA involved necessarily).
