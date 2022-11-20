// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-2/BuyMeAIcedCoffeeChallenge.sol";

contract BuyMeAIcedCoffeeChallengeTest is Test {
    BuyMeAIcedCoffeeChallenge buyMeACoffeeContract;
    uint256 largeCoffeeTip = 0.003 ether;

    event NewMemo(address indexed from, uint256 timestamp, string name, string message);

    function setUp() public {
        buyMeACoffeeContract = new BuyMeAIcedCoffeeChallenge();
    }

    // buyARegularIcedCoffee
    function _arrangeBuyARegularIcedCoffeeTests(address account, uint256 tip) private {
        vm.assume(tip != 0);
        vm.deal(account, tip);
        vm.prank(account);
    }

    function testSuccessfullyCallsBuyARegularIcedCoffeeIfValueIsNot0(
        address account,
        string calldata input,
        uint256 tip
    ) public {
        // Arrange
        _arrangeBuyARegularIcedCoffeeTests(account, tip);

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: tip}(input, input);
    }

    function testCreatesAMemoCallingBuyARegularIcedCoffee(address account, string calldata input, uint256 tip) public {
        // Arrange
        _arrangeBuyARegularIcedCoffeeTests(account, tip);

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: tip}(input, input);

        BuyMeAIcedCoffeeChallenge.Memo[] memory memos = buyMeACoffeeContract.getMemos();

        // Assert
        assertEq(memos.length, 1);
        assertEq(memos[0].from, account);
        assertEq(memos[0].name, input);
        assertEq(memos[0].message, input);
    }

    function testEmitsNewMemoEventCallingBuyARegularIcedCoffee(address account, string calldata input, uint256 tip)
        public
    {
        // Arrange
        _arrangeBuyARegularIcedCoffeeTests(account, tip);

        // Assert
        vm.expectEmit(true, false, true, true);

        emit NewMemo({name: input, message: input, from: account, timestamp: block.timestamp});

        // Act
        buyMeACoffeeContract.buyARegularIcedCoffee{value: tip}(input, input);
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

    // buyALargeIcedCoffe
    function _arrangeBuyALargeIcedCoffeTests(address account) private {
        vm.deal(account, largeCoffeeTip);
        vm.prank(account);
    }

    function testSuccessfullyCallsBuyALargeIcedCoffeIfValueIsNot3Eth(address account, string calldata input) public {
        // Arrange
        _arrangeBuyALargeIcedCoffeTests(account);

        // Act
        buyMeACoffeeContract.buyALargeIcedCoffe{value: largeCoffeeTip}(input, input);
    }

    function testCreatesAMemoCallingBuyALargeIcedCoffe(address account, string calldata input) public {
        // Arrange
        _arrangeBuyALargeIcedCoffeTests(account);

        // Act
        buyMeACoffeeContract.buyALargeIcedCoffe{value: largeCoffeeTip}(input, input);

        BuyMeAIcedCoffeeChallenge.Memo[] memory memos = buyMeACoffeeContract.getMemos();

        // Assert
        assertEq(memos.length, 1);
        assertEq(memos[0].from, account);
        assertEq(memos[0].name, input);
        assertEq(memos[0].message, input);
    }

    function testEmitsNewMemoEventCallingBuyALargeIcedCoffe(address account, string calldata input) public {
        // Arrange
        _arrangeBuyALargeIcedCoffeTests(account);

        // Assert
        vm.expectEmit(true, false, true, true);

        emit NewMemo({name: input, message: input, from: account, timestamp: block.timestamp});

        // Act
        buyMeACoffeeContract.buyALargeIcedCoffe{value: largeCoffeeTip}(input, input);
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

    // withdrawTips
    function testAllowOwnerToWithdrawContractBalance(address account1, uint256 tip) public {
        // Arrange
        vm.assume(tip != 0);

        address account2 = 0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097;
        string memory input = "";

        vm.prank(account2);
        BuyMeAIcedCoffeeChallenge withdrawContractInstance = new BuyMeAIcedCoffeeChallenge();

        vm.deal(account1, tip);
        vm.prank(account1);

        withdrawContractInstance.buyARegularIcedCoffee{value: tip}(input, input);

        // Assert
        withdrawContractInstance.withdrawTips();

        // Act
        assertEq(account2.balance, tip);
    }

    // updateContractOwner
    function _arrangeUpdateContractOwnerTest(address account) private view {
        vm.assume(account != address(0));
        vm.assume(account != address(this));
    }

    function testAllowOwnerToUpdateWithdrawalAddress(address account) public {
        // Arrange
        _arrangeUpdateContractOwnerTest(account);
        BuyMeAIcedCoffeeChallenge changeOwnerContractInstance = new BuyMeAIcedCoffeeChallenge();

        // Assert
        changeOwnerContractInstance.updateContractOwner(account);

        // Act
        vm.expectRevert(Unauthorized.selector);
        changeOwnerContractInstance.updateContractOwner(account);
    }

    function testCannotUpdateWithdrawalAddressIfIsNotOwner(address account) public {
        // Arrange
        _arrangeUpdateContractOwnerTest(account);
        vm.prank(account);

        // Assert
        vm.expectRevert(Unauthorized.selector);

        // Act
        buyMeACoffeeContract.updateContractOwner(account);
    }

    function testCannotUpdateWithdrawalAddressTo0Address() public {
        // Assert
        vm.expectRevert(InvalidWithdrawAddress.selector);

        // Act
        buyMeACoffeeContract.updateContractOwner(address(0));
    }
}
