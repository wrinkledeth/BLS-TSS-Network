// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

// the oracle can be sync'd with L1 Controller but with smaller global epoch
contract L2_ControllerOracle {
    mapping(address => uint256) _withdrawableEths;
    mapping(address => uint256) _arpaRewards;
    address chainMessenger;
    IERC20 private _arpa;
    uint256 _lastOutput;
    GroupData _groupData;

    event GroupUpdated(uint256 epoch, uint256 groupIndex, uint256 groupEpoch, address committer);
    error GroupObsolete(uint256 groupIndex, uint256 relayedGroupEpoch, uint256 currentGroupEpoch);
    
    function updateGroup(address committer, Group group) external {
        require(msg.sender == alias(ChainMessenger address on L1);
        if (input groupEpoch is less than or equal to current groupEpoch) {
            revert GroupObsolete(this should be accepted by deposit transaction flow and can’t be replayed)
        }
        else { // input groupEpoch is bigger than current epoch
            groupData.epoch++;
            if (the group does not exist) {
                groupData.groupCount++;
                update the _groupData
                emit GroupUpdated
            }
        }
    }

    function setChainMessenger(address chainMessenger) external onlyOwner {}
    function addReward(address[] memory nodes, uint256 ethAmount, uint256 arpaAmount) external {}
    function nodeWithdraw(address recipient) external {}
    function setLastOutput(uint256 lastOutput) external {}
    function getValidGroupIndices() external view returns (uint256[] memory) {}
    function getGroupEpoch() external view returns (uint256) {}
    function getGroupCount() external view returns (uint256){}
    function getGroup(uint256 index) external view returns (Group memory){}
    function getGroupThreshold(uint256 groupIndex) external view returns (uint256, uint256){}
    function getMember(uint256 groupIndex, uint256 memberIndex) external view returns (Member memory){}
    function getBelongingGroup(address nodeAddress) external view returns (int256, int256){}
    function getNodeWithdrawableTokens(address nodeAddress) external view returns (uint256, uint256){}
    function getLastOutput() external view returns (uint256){}
}