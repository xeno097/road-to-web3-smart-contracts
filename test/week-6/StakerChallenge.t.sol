// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-6/StakerChallenge.sol";

contract StakerChallengeTest is Test {
    StakerChallenge stakerContract;
    uint256 stakingPeriod = 3 minutes;
    uint256 withdrawalPeriod = 2 minutes;

    event Stake(address indexed sender, uint256 amount);

    function setUp() public {
        stakerContract = new StakerChallenge(stakingPeriod, withdrawalPeriod);
    }

    // depositTimeLeft
    function testCorrectValueIfDeadlineHasNotPassed(uint256 elapsedTime) public {
        // Arrange
        vm.assume(0 < elapsedTime && elapsedTime < stakingPeriod);
        uint256 expectedResult = stakingPeriod - elapsedTime;
        skip(elapsedTime);

        // Act
        uint256 time = stakerContract.depositTimeLeft();

        // Assert
        assertEq(time, expectedResult);
    }

    function testReturns0IfDeadlineHasPassed(uint256 elapsedTime) public {
        // Arrange
        vm.assume(stakingPeriod <= elapsedTime && elapsedTime < 1000);
        skip(elapsedTime);

        // Act
        uint256 time = stakerContract.depositTimeLeft();

        // Assert
        assertEq(time, 0);
    }

    // withdrawTimeLeft
    function testReturnsTheFullClaimPeriodIfDepositDeadlineHasNotPassedYet(uint256 elapsedTime) public {
        // Arrange
        vm.assume(0 <= elapsedTime && elapsedTime < stakingPeriod);

        // Act
        uint256 time = stakerContract.withdrawTimeLeft();

        // Arrange
        assertEq(time, withdrawalPeriod);
    }

    function testReturnsCorrectValueIfWithdrawDeadlineHasNotPassedYet(uint256 elapsedTime) public {
        // Arrange
        vm.assume(0 < elapsedTime && elapsedTime < withdrawalPeriod);
        uint256 expectedResult = withdrawalPeriod - elapsedTime;
        skip(stakingPeriod + elapsedTime);

        // Act
        uint256 time = stakerContract.withdrawTimeLeft();

        // Assert
        assertEq(time, expectedResult);
    }

    function testReturns0IfWithdrawDeadlineHasPassed(uint256 elapsedTime) public {
        // Arrange
        uint256 fullStakingSessionTime = stakingPeriod + withdrawalPeriod;
        vm.assume(fullStakingSessionTime <= elapsedTime && elapsedTime < 1000);
        skip(elapsedTime);

        // Act
        uint256 time = stakerContract.withdrawTimeLeft();

        // Assert
        assertEq(time, 0);
    }

    // stake
    function testAllowsToStakeEth(address account, uint256 amount) public {
        // Arrange
        vm.assume(amount != 0);
        vm.deal(account, amount);
        vm.prank(account);

        // Act
        stakerContract.stake{value: amount}();

        // Assert
        assertEq(address(stakerContract).balance, amount);
        assertEq(stakerContract.balances(account), amount);
    }

    function testEmitsStakeEvent(address account, uint256 amount) public {
        // Arrange
        vm.assume(amount != 0);
        vm.deal(account, amount);
        vm.prank(account);

        // Assert
        vm.expectEmit(true, true, false, true);

        emit Stake(account, amount);

        // Act
        stakerContract.stake{value: amount}();
    }

    function testCannotStake0Eth(address account) public {
        // Arrange
        vm.prank(account);

        // Assert
        vm.expectRevert(bytes("Quantity to stake must be greater than 0"));

        // Act
        stakerContract.stake{value: 0}();
    }

    function testCannotStakeAfterDepositDeadline(address account, uint256 amount) public {
        // Arrange
        vm.assume(amount != 0);
        vm.deal(account, amount);
        vm.prank(account);

        skip(stakingPeriod);

        // Assert
        vm.expectRevert(bytes("Deposit deadline has been reached"));

        // Act
        stakerContract.stake{value: amount}();
    }

    // completed
    function testCompletedReturnsFalseIfStakinPeriodHasNotEnded() public {
        // Act
        bool res = stakerContract.completed();

        // Assert
        assertEq(res, false);
    }

    function testCompletedReturnsTrueIfStakinPeriodHasEnded() public {
        // Arrange
        skip(5 minutes);

        stakerContract.execute();

        // Act
        bool res = stakerContract.completed();

        // Assert
        assertEq(res, true);
    }

    // withdraw
    function testWithdrawEth(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != address(0) && account != 0x0000000000000000000000000000000000000009);
        vm.assume(account.code.length == 0);
        vm.assume(0 < amount && amount <= 1000 ether);
        vm.deal(account, amount);
        vm.deal(address(stakerContract), type(uint256).max - amount);
        vm.startPrank(account);
        stakerContract.stake{value: amount}();
        skip(stakingPeriod);

        // Act
        stakerContract.withdraw();

        // Assert
        assertGe(account.balance, amount);

        // Clean up
        vm.stopPrank();
    }

    function testCannotWithdrawOEth(address account) public {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(account.code.length == 0);
        vm.prank(account);
        skip(stakingPeriod);

        // Assert
        vm.expectRevert(bytes("You have no balance to withdraw!"));

        // Act
        stakerContract.withdraw();
    }

    function testCannotWithdrawIfContractBalanceIsInsufficient(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(account.code.length == 0);
        vm.assume(0 < amount && amount <= 1000 ether);
        vm.deal(account, amount);
        vm.startPrank(account);
        stakerContract.stake{value: amount}();
        skip(stakingPeriod);

        // Assert
        vm.expectRevert(bytes("Insufficient funds to process the transaction"));

        // Act
        stakerContract.withdraw();

        // Cleanup
        vm.stopPrank();
    }

    // execute
    function testExecuteIfStakingSessionHasPassed(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(account.code.length == 0);
        vm.assume(0 < amount && amount <= 1000 ether);
        vm.deal(account, amount);
        vm.prank(account);
        stakerContract.stake{value: amount}();
        skip(stakingPeriod + withdrawalPeriod);

        // Act
        stakerContract.execute();

        // Assert
        assertEq(address(stakerContract).balance, 0);
        assertEq(stakerContract.lockedBalance(), amount);
    }

    function testCannotExecuteIfStakingSessionHasNotPassedYet(uint256 elapsedTime) public {
        // Arrange
        vm.assume(0 < elapsedTime && elapsedTime < stakingPeriod + withdrawalPeriod);
        skip(elapsedTime);

        // Assert
        vm.expectRevert(bytes("Claim deadline is not reached yet"));

        // Act
        stakerContract.execute();
    }

    function testCannotExecuteIfAlreadyCompleted(uint256 elapsedTime) public {
        // Arrange
        vm.assume(0 <= elapsedTime && elapsedTime < 1000);
        skip(stakingPeriod + withdrawalPeriod + elapsedTime);

        stakerContract.execute();

        // Assert
        vm.expectRevert(bytes("Stake already completed!"));

        // Act
        stakerContract.execute();
    }

    // lockedBalance
    function testReturnsTheBalanceOfTheVaultContract(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(account.code.length == 0);
        vm.assume(0 < amount && amount <= 1000 ether);
        vm.deal(account, amount);
        vm.prank(account);
        stakerContract.stake{value: amount}();
        skip(stakingPeriod + withdrawalPeriod);

        // Act
        stakerContract.execute();

        // Assert
        assertEq(stakerContract.lockedBalance(), amount);
    }

    // restartStakingPeriod
    function testRestartsTheStakingPeriod(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(account.code.length == 0);
        vm.assume(0 < amount && amount <= 1000 ether);
        vm.deal(account, amount);
        vm.prank(account);
        stakerContract.stake{value: amount}();
        skip(stakingPeriod + withdrawalPeriod);

        stakerContract.execute();

        // Act
        stakerContract.restartStakingPeriod();

        // Assert
        assertEq(stakerContract.stakingSession(), 2);
    }

    function testCannotRestartTheStakingPeriodIfStakingSessionHasNotBeenCompleted(uint256 elapsedTime) public {
        // Arrange
        vm.assume(0 <= elapsedTime && elapsedTime < 1000);
        skip(stakingPeriod);

        // Assert
        vm.expectRevert(bytes("Staking period must be over to perform this operation"));

        // Act
        stakerContract.restartStakingPeriod();
    }
}
