// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./StakerVault.sol";

contract StakerChallenge {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    uint256 public constant rewardRatePerBlock = 0.002 ether;
    uint256 public depositPeriod;
    uint256 public withdrawalPeriod;
    uint256 public depositDeadline;
    uint256 public withdrawDeadline;
    uint256 public stakingSession = 0;

    StakerVault public stakerVaultContract;

    event Stake(address indexed sender, uint256 amount);
    event Received(address, uint256);
    event Execute(address indexed sender, uint256 amount);

    constructor(uint256 _depositPeriod, uint256 _withdrawalPeriod) {
        stakerVaultContract = new StakerVault();
        stakingSession = 1;
        depositPeriod = _depositPeriod;
        withdrawalPeriod = _withdrawalPeriod;
        _setTimers();
    }

    modifier depositDeadlineReached(bool requireReached) {
        uint256 timeRemaining = depositTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Deposit deadline not reached!");
        } else {
            require(timeRemaining > 0, "Deposit deadline reached!");
        }
        _;
    }

    modifier withdrawDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Withdraw deadline not reached!");
        } else {
            require(timeRemaining > 0, "Withdraw deadline reached!");
        }
        _;
    }

    modifier notCompleted() {
        require(!stakerVaultContract.completed(), "Staking session completed!");
        _;
    }

    modifier onlyCompleted() {
        require(stakerVaultContract.completed(), "Staking session not completed!");
        _;
    }

    /// @dev Set deadlines for the current staking session.
    function _setTimers() internal {
        depositDeadline = block.timestamp + depositPeriod;
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

    /// @dev Returns the time left to withdrwaw locked ETH in the contract before the staking session completes.
    function withdrawTimeLeft() public view returns (uint256) {
        if (block.timestamp >= withdrawDeadline) {
            return (0);
        } else {
            uint256 lowerBound = block.timestamp >= depositDeadline ? block.timestamp : depositDeadline;
            return (withdrawDeadline - lowerBound);
        }
    }

    /// @dev Locks ETH to be staked in the contract.
    function stake() public payable depositDeadlineReached(false) withdrawDeadlineReached(false) {
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
    function withdraw() public depositDeadlineReached(true) withdrawDeadlineReached(false) notCompleted {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];
        uint256 depositPeriods = stakingSession + 1 - depositTimestamps[msg.sender];
        uint256 balanceRewards = (individualBalance + rewardRatePerBlock) * (depositPeriods) ** 2;
        balances[msg.sender] = 0;
        depositTimestamps[msg.sender] = 0;

        require(address(this).balance > balanceRewards, "Insufficient funds to process the transaction");

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (bool sent,) = msg.sender.call{value: balanceRewards}("");
        require(sent, "Withdrawal failed");
    }

    /// @dev Sends remaining funds into the vault contract after a completed staking session.
    function execute() public withdrawDeadlineReached(true) notCompleted {
        uint256 amount = address(this).balance;

        stakerVaultContract.complete{value: amount}();

        emit Execute(msg.sender, amount);
    }

    /// @dev Returns the total value locked into the external vault.
    function lockedBalance() public view returns (uint256) {
        return address(stakerVaultContract).balance;
    }

    //// @dev Allows a user to start a new staking session by withdrawing ETH from the StakerVault.
    function restartStakingSession() external onlyCompleted {
        stakerVaultContract.withdraw();
        _setTimers();
        stakingSession++;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
