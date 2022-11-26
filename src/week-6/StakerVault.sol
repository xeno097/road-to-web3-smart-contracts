// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4; //Do not change the solidity version as it negativly impacts submission grading

contract StakerVaultContract {
    bool public completed;
    address owner;

    constructor() {
        owner = msg.sender;
    }

    // Allow only the staking contract to call functions on this contract
    modifier allowOnlyOnwer() {
        require(msg.sender == owner, "Only the owner can perform this operation");
        _;
    }

    function complete() public payable allowOnlyOnwer {
        completed = true;
    }

    function withdraw() external allowOnlyOnwer {
        (bool sent,) = owner.call{value: address(this).balance}("");
        completed = false;
        require(sent, "Failed to resend ether");
    }
}
