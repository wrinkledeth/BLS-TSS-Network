// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IController} from "../interfaces/IController.sol";

// we allow anyone to relay without given reward, the committer in a new group will have initiative as they can handle tasks on that chain then get rewarded
contract L1_ControllerRelayer is OwnableUpgradeable {
    // chainId => (groupIndex ⇒ groupEpoch)
    mapping(uint256 => mapping(uint256 => uint256)) _chainRelayRecord;
    mapping(uint256 => address) _chainMessengers;

    IController _controller;
    event GroupRelayed(uint256 epoch, uint256 groupIndex, uint256 groupEpoch, address committer);
    error GroupObsolete(uint256 groupIndex, uint256 relayedGroupEpoch, uint256 currentGroupEpoch);

    function relayGroup(uint256 chainId, uint256 groupIndex){
        require(_chainMessengers(chainId) != address(0));
        require(_controller.getCoordinator(groupIndex) == address(0)); // need the group is not in a DKG process so that group info on current epoch is finalized
        
        // call and assign groupToRelay = _controller.getGroup(groupIndex)
        if (_chainRelayRecord[chainId][groupIndex] >= groupToRelay.epoch){
            revert GroupObsolete
        }
        else {
            _chainRelayRecord[chainId][groupIndex] = groupToRelay.epoch
            // call our messenger of corresponding chain
            call _chainMessengers[chainId].relayMessage(msg.sender, groupToRelay)
            emit GroupRelayed
        }
    }

    function setChainMessenger(uint256 chainId, address chainMessenger) onlyOwner {
        _chainMessengers[chainId] = chainMessenger;
    }
}