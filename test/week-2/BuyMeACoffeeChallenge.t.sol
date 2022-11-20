// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-2/BuyMeACoffeeChallenge.sol";

contract BuyMeACoffeeChallengeTest is Test {
    BuyMeACoffeeChallenge buyMeACoffeeContract;
    uint256 largeCoffeeTip = 0.003 ether;

    event NewMemo(address indexed from, uint256 timestamp, string name, string message);

    function setUp() public {
        buyMeACoffeeContract = new BuyMeACoffeeChallenge();
    }

    function testSuccessfullyCallsBuyARegularIcedCoffeeIfValueIsNot0(
        address account,
        string calldata input,
        uint256 tip
    ) public {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(tip != 0);
        vm.deal(account, tip);
        vm.prank(account);

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: tip}(input, input);
    }

    function testSuccessfullyCallsBuyALargeIcedCoffeIfValueIsNot3Eth(address account, string calldata input) public {
        // Arrange
        vm.assume(account != address(0));
        vm.deal(account, largeCoffeeTip);
        vm.prank(account);

        // Act
        buyMeACoffeeContract.buyALargeIcedCoffe{value: largeCoffeeTip}(input, input);
    }

    function testCreatesAMemoCallingBuyARegularIcedCoffee(address account, string calldata input, uint256 tip) public {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(tip != 0);
        vm.deal(account, tip);
        vm.prank(account);

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: tip}(input, input);

        BuyMeACoffeeChallenge.Memo[] memory memos = buyMeACoffeeContract.getMemos();

        // Assert
        assertEq(memos.length, 1);
        assertEq(memos[0].name, input);
        assertEq(memos[0].message, input);
    }

    function testCreatesAMemoCallingBuyALargeIcedCoffe(address account, string calldata input) public {
        // Arrange
        vm.assume(account != address(0));
        vm.deal(account, largeCoffeeTip);
        vm.prank(account);

        // Act
        buyMeACoffeeContract.buyALargeIcedCoffe{value: largeCoffeeTip}(input, input);

        BuyMeACoffeeChallenge.Memo[] memory memos = buyMeACoffeeContract.getMemos();

        // Assert
        assertEq(memos.length, 1);
        assertEq(memos[0].name, input);
        assertEq(memos[0].message, input);
    }

    function testEmitsNewMemoEventCallingBuyARegularIcedCoffee(address account, string calldata input, uint256 tip)
        public
    {
        // Arrange
        vm.assume(account != address(0));
        vm.assume(tip != 0);
        vm.deal(account, tip);
        vm.prank(account);

        // Assert
        vm.expectEmit(true, false, true, true);

        emit NewMemo({name: input, message: input, from: account, timestamp: block.timestamp});

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: tip}(input, input);
    }

    function testEmitsNewMemoEventCallingBuyALargeIcedCoffe(address account, string calldata input) public {
        // Arrange
        vm.assume(account != address(0));
        vm.deal(account, largeCoffeeTip);
        vm.prank(account);

        // Assert
        vm.expectEmit(true, false, true, true);

        emit NewMemo({name: input, message: input, from: account, timestamp: block.timestamp});

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: largeCoffeeTip}(input, input);
    }

    function testAllowsOwnerToWithdrawContractBalance(address account1, uint256 tip) public {
        // Arrange
        vm.assume(tip != 0);

        address account2 = 0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097;
        string memory input = "";

        vm.prank(account2);
        BuyMeACoffeeChallenge newOwnerBuyMeACoffeeContract = new BuyMeACoffeeChallenge();

        vm.deal(account1, tip);
        vm.prank(account1);

        newOwnerBuyMeACoffeeContract.buyARegularIcedCoffee{value: tip}(input, input);

        // Assert
        newOwnerBuyMeACoffeeContract.withdrawTips();

        // Act
        assertEq(account2.balance, tip);
    }

    function testAllowsOwnerToUpdateWithdrawalAddress(address account1) public {
        // Arrange
        vm.assume(account1 != address(this));
        BuyMeACoffeeChallenge newOwnerBuyMeACoffeeContract = new BuyMeACoffeeChallenge();

        // Assert
        newOwnerBuyMeACoffeeContract.updateContractOwner(account1);

        // Act
        vm.expectRevert(Unauthorized.selector);
        newOwnerBuyMeACoffeeContract.updateContractOwner(account1);
    }

    function testCannotBuyARegularIcedCoffeeIfValueIs0(address account) public {
        // Arrange
        vm.prank(account);
        string memory input = "";

        // Assert
        vm.expectRevert(FreeIcedCoffeeNotAllowed.selector);

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: 0}(input, input);
    }

    function testCannotBuyALargeIcedCoffeIfValueIsNotLargeCoffeeTip(address account, uint256 tip) public {
        // Arrange
        vm.assume(tip != largeCoffeeTip);

        vm.prank(account);
        vm.deal(account, tip);
        string memory input = "";

        // Assert
        vm.expectRevert(InvalidLargeIcedCoffeeTip.selector);

        // Act
        buyMeACoffeeContract.buyALargeIcedCoffe{value: tip}(input, input);
    }

    function testCannotUpdateWithdrawalAddressIfIsNotOwner(address account) public {
        // Arrange
        vm.assume(account != address(this));
        vm.prank(account);

        // Assert
        vm.expectRevert(Unauthorized.selector);

        // Act
        buyMeACoffeeContract.updateContractOwner(account);
    }
}
