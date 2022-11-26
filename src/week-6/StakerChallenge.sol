// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./StakerVault.sol";

contract StakerChallenge {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    uint256 public constant rewardRatePerBlock = 0.002 ether;
    uint256 public stakingPeriod;
    uint256 public withdrawalPeriod;
    uint256 public depositDeadline;
    uint256 public withdrawDeadline;
    uint256 public currentBlock = 0;
    uint256 public stakingSession = 0;

    StakerVaultContract public stakerVaultContract;

    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint256);
    event Execute(address indexed sender, uint256 amount);

    constructor(uint256 _stakingPeriod, uint256 _withdrawalPeriod) {
        stakerVaultContract = new StakerVaultContract();
        stakingSession = 1;
        stakingPeriod = _stakingPeriod;
        withdrawalPeriod = _withdrawalPeriod;
        _setTimers();
    }

    modifier depositDeadlineReached(bool requireReached) {
        uint256 timeRemaining = depositTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Deposit deadline has not been reached yet");
        } else {
            require(timeRemaining > 0, "Deposit deadline has been reached");
        }
        _;
    }

    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    modifier notCompleted() {
        require(!stakerVaultContract.completed(), "Stake already completed!");
        _;
    }

    modifier onlyCompleted() {
        require(stakerVaultContract.completed(), "Staking period must be over to perform this operation");
        _;
    }

    function _setTimers() internal {
        depositDeadline = block.timestamp + stakingPeriod;
        withdrawDeadline = depositDeadline + withdrawalPeriod;
    }

    /// @dev Returns the time left to deposit ETH in the contract.
    function depositTimeLeft() public view returns (uint256) {
        if (block.timestamp >= depositDeadline) {
            return (0);
        } else {
            return (depositDeadline - block.timestamp);
        }
    }

    /// @dev Returns the time left to claim locked ETH in the contract before the staking period completes.
    function withdrawTimeLeft() public view returns (uint256) {
        if (block.timestamp >= withdrawDeadline) {
            return (0);
        } else {
            uint256 lowerBound = block.timestamp >= depositDeadline ? block.timestamp : depositDeadline;
            return (withdrawDeadline - lowerBound);
        }
    }

    /// @dev Locks ETH to be staked in the contract.
    function stake() public payable depositDeadlineReached(false) claimDeadlineReached(false) {
        require(msg.value > 0, "Quantity to stake must be greater than 0");

        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] =
            depositTimestamps[msg.sender] != 0 ? depositTimestamps[msg.sender] : stakingSession;

        emit Stake(msg.sender, msg.value);
    }

    /// @dev Determines if a staking period is closed.
    function completed() public view returns (bool) {
        return stakerVaultContract.completed();
    }

    /// @dev Withdraws the balance and accrued rewards of the sender to its address.
    function withdraw() public depositDeadlineReached(true) claimDeadlineReached(false) notCompleted {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 stakingPeriods = stakingSession + 1 - depositTimestamps[msg.sender];
        uint256 balanceRewards = (individualBalance + rewardRatePerBlock) * (stakingPeriods) ** 2;
        balances[msg.sender] = 0;
        depositTimestamps[msg.sender] = 0;

        require(address(this).balance > balanceRewards, "Insufficient funds to process the transaction");

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent,) = msg.sender.call{value: balanceRewards}("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    /// @dev Sends remaining funds into the vault contract after a completed staking session.
    function execute() public claimDeadlineReached(true) notCompleted {
        stakerVaultContract.complete{value: address(this).balance}();
    }

    /// @dev Returns the total value locked into the external vault.
    function lockedBalance() public view returns (uint256) {
        return address(stakerVaultContract).balance;
    }

    //// @dev Allows a user to start a new staking session by withdrawing ETH from the stakerVaultContract.
    function restartStakingPeriod() external onlyCompleted {
        stakerVaultContract.withdraw();
        _setTimers();
        stakingSession++;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
