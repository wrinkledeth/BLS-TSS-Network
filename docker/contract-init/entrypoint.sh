#!/bin/bash
git clone https://github.com/ARPA-Network/BLS-TSS-Network.git
cp /usr/src/app/external/.env /usr/src/app/BLS-TSS-Network/contracts/.env
cd /usr/src/app/BLS-TSS-Network/contracts
/root/.foundry/bin/forge test
/root/.foundry/bin/forge script script/ControllerLocalTest.s.sol:ControllerLocalTestScript --fork-url http://anvil-chain:8545 --broadcast
/root/.foundry/bin/forge script script/StakeNodeLocalTest.s.sol:StakeNodeLocalTestScript --fork-url http://anvil-chain:8545 --broadcast -g 150
tail -f /dev/null