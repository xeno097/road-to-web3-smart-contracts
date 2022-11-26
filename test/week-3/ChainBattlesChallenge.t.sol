// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-3/ChainBattlesChallenge.sol";

contract ChainBattlesChallengeTest is Test {
    ChainBattlesChallenge chainBattlesContract;

    function setUp() public {
        chainBattlesContract = new ChainBattlesChallenge();
    }

    function _skipTestIfAccountIsInvalid(address account) private view {
        // Sending an NFT to the 0 address is equivalent to burning it and Open Zeppelin contracts have checks to avoid it.
        vm.assume(account != address(0));
        vm.assume(account.code.length == 0);
    }

    // mint
    function testMintNewNft(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.prank(account);

        // Act
        chainBattlesContract.mint();

        // Assert
        assertEq(chainBattlesContract.balanceOf(account), 1);
        assertEq(chainBattlesContract.ownerOf(0), account);

        ChainBattlesChallenge.CharStats memory char = chainBattlesContract.getCharStats(0);

        assertEq(char.level, 0);
        assertEq(char.speed, 1);
        assertEq(char.strength, 1);
        assertEq(char.life, 5);
        assertTrue(
            char.class == ChainBattlesChallenge.CharClass.Scout || char.class == ChainBattlesChallenge.CharClass.Warrior
        );
    }

    // train
    function testTrain(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.startPrank(account);

        chainBattlesContract.mint();

        // Act
        chainBattlesContract.train(0);

        // Assert
        ChainBattlesChallenge.CharStats memory char = chainBattlesContract.getCharStats(0);

        assertEq(char.level, 1);

        // Clean up
        vm.stopPrank();
    }

    function testCannotTrainNonExistentCharacter(address account) public {
        // Arrange
        vm.prank(account);

        // Assert
        vm.expectRevert(NonExistentCharacter.selector);

        // Act
        chainBattlesContract.train(0);
    }

    function testCannotTrainOtherUserCharacter(address account1, address account2) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);
        vm.prank(account1);

        chainBattlesContract.mint();

        vm.prank(account2);

        // Assert
        vm.expectRevert(Unauthorized.selector);

        // Act
        chainBattlesContract.train(0);
    }

    function testCannotTrainCharacterOverLevel100(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.startPrank(account);

        chainBattlesContract.mint();

        for (uint256 i; i < 100; i++) {
            chainBattlesContract.train(0);
        }

        // Assert
        vm.expectRevert(MaxedOutCharacter.selector);

        // Act
        chainBattlesContract.train(0);

        // Clean up
        vm.stopPrank();
    }

    // getCharStats
    function testGetCharacterStats(address account, uint256 idx) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.startPrank(account);

        for (uint256 i = 0; i < 10; i++) {
            chainBattlesContract.mint();
        }

        uint256 tokenId = idx % 10;

        // Act
        ChainBattlesChallenge.CharStats memory char = chainBattlesContract.getCharStats(tokenId);

        // Assert
        assertEq(char.level, 0);
        assertEq(char.speed, 1);
        assertEq(char.strength, 1);
        assertEq(char.life, 5);
        assertTrue(
            char.class == ChainBattlesChallenge.CharClass.Scout || char.class == ChainBattlesChallenge.CharClass.Warrior
        );

        // Clean up
        vm.stopPrank();
    }

    function testCannotGetNonExistentCharacterStats() public {
        // Assert
        vm.expectRevert(NonExistentCharacter.selector);

        // Act
        chainBattlesContract.getCharStats(0);
    }
}
