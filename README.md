# No Grind Token

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

[Documentation link](https://book.getfoundry.sh/)

## Usage

### Build

```shell
forge build --via-ir
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

### Anvil

```shell
anvil --port 8555 --balance 1000000 --fork-url http://localhost:8545 --chain-id 369
```

### Deploy

```shell
# forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
forge script script/NoGrindToken.s.sol:DeployNoGrindToken --rpc-url $RPC_URL --broadcast
```

```shell
# forge script script/FlashSwapArb.s.sol:DeployFlashSwapArb --broadcast --verify --rpc-url <your_rpc_url>
forge script script/FlashSwapArb.s.sol:DeployFlashSwapArb --broadcast --rpc-url http://localhost:8555 --via-ir
```

### Cast

```shell
cast <subcommand>
```

```shell
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url http://localhost:8555
```

### Help

```shell
forge --help
anvil --help
cast --help
```
