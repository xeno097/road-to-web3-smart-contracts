// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-1/Erc721Challenge.sol";

contract Erc721ChallengeTest is Test {
    Erc721Challenge nftContract;
    uint256 MAX_SUPPLY;
    uint256 MINT_LIMIT_PER_USER;

    function setUp() public {
        MAX_SUPPLY = 7;
        MINT_LIMIT_PER_USER = 5;
        nftContract = new Erc721Challenge(MAX_SUPPLY,MINT_LIMIT_PER_USER);
    }

    function testMint(address _account, string calldata _uri) public {
        // Arrange
        vm.assume(_account != address(0));
        vm.assume(_account.code.length == 0);
        vm.prank(_account);

        // Act
        nftContract.safeMint(_account, _uri);

        // Assert
        assertEq(nftContract.balanceOf(_account), 1);
    }

    function testAllowsToMintMultipleTimesBelowTheLimit(address _account, uint256 mints, string calldata _uri) public {
        // Arrange
        vm.assume(_account != address(0));
        vm.assume(_account.code.length == 0);
        vm.assume(0 < mints && mints <= 5);

        vm.startPrank(_account);

        // Act
        for (uint256 i = 0; i < mints; i++) {
            nftContract.safeMint(_account, _uri);
        }

        // Assert
        assertEq(nftContract.balanceOf(_account), mints);

        // Clean up
        vm.stopPrank();
    }

    function testCannotMintMoreThan5NftsPerAccount(address _account, string calldata _uri) public {
        // Arrange
        vm.assume(_account != address(0));
        vm.assume(_account.code.length == 0);
        vm.startPrank(_account);

        // Act
        for (uint256 i = 0; i <= MINT_LIMIT_PER_USER; i++) {
            if (i == MINT_LIMIT_PER_USER) {
                // Assert
                assertEq(nftContract.mintBalanceOf(_account), MINT_LIMIT_PER_USER);
                vm.expectRevert(abi.encodeWithSelector(MintLimitPerUserReached.selector, MINT_LIMIT_PER_USER));
            }

            nftContract.safeMint(_account, _uri);
        }

        // Clean up
        vm.stopPrank();
    }

    function testCannotMintMoreThanMaxSupply(address _account1, address _account2, string calldata _uri) public {
        // Arrange
        vm.assume(_account1 != address(0) && _account2 != address(0));
        vm.assume(_account1 != _account2);
        vm.assume(_account1.code.length == 0 && _account2.code.length == 0);

        address account = _account1;

        // Act
        for (uint256 i = 0; i <= MAX_SUPPLY; i++) {
            if (i == MINT_LIMIT_PER_USER) {
                account = _account2;
            }

            if (i == MAX_SUPPLY) {
                // Assert
                assertEq(nftContract.totalMintCount(), MAX_SUPPLY);
                vm.expectRevert(abi.encodeWithSelector(MaxSupplyReached.selector, MAX_SUPPLY));
            }

            vm.prank(account);
            nftContract.safeMint(account, _uri);
        }
    }
}
