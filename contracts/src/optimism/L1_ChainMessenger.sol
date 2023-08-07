// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { ICrossDomainMessenger } from 
    "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

contract L1_ChainMessenger {
    address _controllerRelayer; // set after deploying controller contract

    address crossDomainMessengerAddr = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;

    // function relayMessage(address committer, Group group) external {
    function relayMessage(address committer, uint256 group) external {
        require(msg.sender == _controllerRelayer);
        //call portal of that chain on L1 to trigger message relay, e.g. for OP this is to call L1CrossDomainMessenger.sendMessage
        bytes memory message;
        message = abi.encodeWithSignature("relayGroup(address,uint256)", 
            committer, group);

        ICrossDomainMessenger(crossDomainMessengerAddr).sendMessage(
            _controllerRelayer,
            message,
            1000000   // within the free gas limit amount
        );
    }
}