#!/bin/bash
/root/.foundry/bin/forge script script/ControllerLocalTest.s.sol:ControllerLocalTestScript --fork-url http://0.0.0.0:8545 --broadcast
/root/.foundry/bin/forge script script/StakeNodeLocalTest.s.sol:StakeNodeLocalTestScript --fork-url http://0.0.0.0:8545 --broadcast -g 150
tail -f /dev/null