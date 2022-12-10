# Requirements

- ghc >= 8.10.7
- cabal >= 3.0
- Install
  [custom libsodium](https://developers.cardano.org/docs/get-started/installing-cardano-node/#downloading--compiling)

# Getting started

### Build

```
cabal build contract
```

### Run

```
cabal run contract
```

This will generate a `scripts.json` file at the `ghc` folder containing the
serialized scripts/validators.
