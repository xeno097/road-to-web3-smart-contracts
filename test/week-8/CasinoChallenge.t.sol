// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-8/CasinoChallenge.sol";

contract CasinoChallengeTest is Test {
    uint256 revealDeadline = 12 hours;
    address constant playerA = 0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097;
    address constant playerB = 0x2546BcD3c84621e976D8185a91A922aE77ECEc30;
    uint256 constant valA = uint256(keccak256(hex"BAD060A7"));
    uint256 constant hashA = uint256(keccak256(abi.encode(valA)));
    uint256 constant valB = uint256(keccak256(hex"600D60A7"));
    uint256 constant hashB = uint256(keccak256(abi.encode(valB)));
    uint256 constant valBloses = uint256(keccak256(hex"BAD060A7"));
    uint256 constant hashBloses = uint256(keccak256(abi.encode(valBloses)));
    CasinoChallenge casinoContract;

    event BetProposed(uint256 indexed _commitment, uint256 value);

    event BetAccepted(uint256 indexed _commitment, address indexed _sideA);

    event NumberRevealed(uint256 indexed _commitment, address indexed player);

    event BetSettled(uint256 indexed _commitment, address winner, address loser, uint256 value);

    function setUp() public {
        casinoContract = new CasinoChallenge(revealDeadline);
    }

    function _skipTestIfAccountIsInvalid(address account) private view {
        // Exclude 0 address and precompiled contracts.
        vm.assume(uint160(account) > 10 && account != address(this));
        vm.assume(account.code.length == 0);
    }

    // proposeBet
    function testShouldAllowUserToProposeBet(address account, uint256 amount) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(amount != 0);

        hoax(account, amount);

        // Act
        casinoContract.proposeBet{value: amount}(hashA);

        // Assert
        (address sideA, uint256 value,, uint256 randomA,, bool revealed, bool accepted) =
            casinoContract.proposedBet(hashA);

        assertEq(sideA, account);
        assertEq(value, amount);
        assertEq(randomA, 0);
        assertFalse(revealed);
        assertFalse(accepted);
    }

    function testShouldEmitBetProposed(address account, uint256 amount) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(amount != 0);

        hoax(account, amount);

        // Assert
        vm.expectEmit(true, true, false, true);

        emit BetProposed(hashA, amount);

        // Act
        casinoContract.proposeBet{value: amount}(hashA);
    }

    function testCannotProposeAFreeBet(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);

        // Assert
        vm.expectRevert(bytes("you need to actually bet something"));

        // Act
        casinoContract.proposeBet{value: 0}(hashA);
    }

    function testCannotBetAlreadyExistingBet(address account, uint256 amount) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(account, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerA, amount);

        // Assert
        vm.expectRevert(bytes("there is already a bet on that commitment"));

        // Act
        casinoContract.proposeBet{value: amount}(hashA);
    }

    // acceptBet
    function testAcceptsBet(uint256 amount) public {
        // Arrange
        vm.assume(amount != 0);
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);

        // Act
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        // Assert
        (address sideB,, uint256 randomB) = casinoContract.acceptedBet(hashA);

        assertEq(sideB, playerB);
        assertEq(randomB, hashB);
    }

    function testEmitsBetAccepted(uint256 amount) public {
        // Arrange
        vm.assume(amount != 0);
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);

        // Assert
        vm.expectEmit(true, true, false, true);

        emit BetAccepted(hashA, playerA);

        // Act
        casinoContract.acceptBet{value: amount}(hashA, hashB);
    }

    function testCannotAccceptNonexistingBet(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerB, amount);

        // Assert
        vm.expectRevert(bytes("Nobody made that bet"));

        // Act
        casinoContract.acceptBet{value: amount}(hashA, hashB);
    }

    function testCannotAcceptOwnBet(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        startHoax(playerA, 2 * amount);
        casinoContract.proposeBet{value: amount}(hashA);

        // Assert
        vm.expectRevert(bytes("Can't accept your own bet"));

        // Act
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        // Clean up
        vm.stopPrank();
    }

    function testCannotAcceptAlreadyAcceptedBet(address account, uint256 amount) public {
        // Arrange
        vm.assume(amount != 0);
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        hoax(account, amount);

        // Assert
        vm.expectRevert(bytes("Bet has already been accepted"));

        // Act
        casinoContract.acceptBet{value: amount}(hashA, hashB);
    }

    function testCannotAcceptBetWithWrongAmount(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != playerA);
        vm.assume(1 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(account, amount);

        // Assert
        vm.expectRevert(bytes("Need to bet the same amount as sideA"));

        // Act
        casinoContract.acceptBet{value: amount - 1}(hashA, hashB);
    }

    // revealRandomA
    function testRevealRandomA(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);
        // Act
        casinoContract.revealRandomA(valA);

        // Assert
        (address sideA, uint256 value,, uint256 randomA,, bool revealed, bool accepted) =
            casinoContract.proposedBet(hashA);

        assertEq(sideA, playerA);
        assertEq(value, amount);
        assertEq(randomA, valA);
        assertTrue(revealed);
        assertTrue(accepted);
    }

    function testRevealRandomAemitsNumberRevealed(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);

        // Assert
        vm.expectEmit(true, true, false, true);

        emit NumberRevealed(hashA, playerA);

        // Act
        casinoContract.revealRandomA(valA);
    }

    function testCannotRevealRandomAWithWrongValue(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);

        // Assert
        vm.expectRevert(bytes("Not a bet you placed or wrong value"));

        // Act
        casinoContract.revealRandomA(0);
    }

    function testCannotRevealRandomAForNotAceptedBet(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        startHoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        // Assert
        vm.expectRevert(bytes("Bet has not been accepted yet"));

        // Act
        casinoContract.revealRandomA(valA);

        // Clean up
        vm.stopPrank();
    }

    // revealRandomB
    function testRevealRandomBBWins(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);
        casinoContract.revealRandomA(valA);

        vm.prank(playerB);

        // Assert
        vm.expectEmit(true, true, true, true);

        emit BetSettled(hashA, playerB, playerA, amount);

        // Act
        casinoContract.revealRandomB(hashA, valB);
    }

    function testRevealRandomBAWins(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashBloses);

        vm.prank(playerA);
        casinoContract.revealRandomA(valA);

        vm.prank(playerB);

        // Assert
        vm.expectEmit(true, true, true, true);

        emit BetSettled(hashA, playerA, playerB, amount);

        // Act
        casinoContract.revealRandomB(hashA, valBloses);
    }

    function testCannotRevealRandomBForABetThatBDidNotAccept(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != playerA);
        _skipTestIfAccountIsInvalid(account);
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(account, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);
        casinoContract.revealRandomA(valA);

        vm.prank(playerB);

        // Assert
        vm.expectRevert(bytes("Not a bet you accepted or wrong value"));

        // Act
        casinoContract.revealRandomB(hashA, valB);
    }

    function testCannotRevealRandomBWithInvalidValue(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);
        casinoContract.revealRandomA(valA);

        vm.prank(playerB);

        // Assert
        vm.expectRevert(bytes("Wrong number"));

        // Act
        casinoContract.revealRandomB(hashA, 0);
    }

    function testCannotRevealRandomBBeforeAReveal(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        startHoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        // Assert
        vm.expectRevert(bytes("Player A has not revealed its number yet"));

        // Act
        casinoContract.revealRandomB(hashA, valB);
    }

    // forfeit
    function testAForfeit(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.startPrank(playerA);
        casinoContract.revealRandomA(valA);

        skip(revealDeadline + 1);

        // Assert
        vm.expectEmit(true, true, true, true);

        emit BetSettled(hashA, playerA, playerB, amount);

        // Act
        casinoContract.forfeit(hashA);

        // Clean up
        vm.stopPrank();
    }

    function testBForfeit(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        startHoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        skip(revealDeadline + 1);

        // Assert
        vm.expectEmit(true, true, true, true);

        emit BetSettled(hashA, playerB, playerA, amount);

        // Act
        casinoContract.forfeit(hashA);

        // Clean up
        vm.stopPrank();
    }

    function testACannotForfeitNotAcceptedBet(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        startHoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        // Assert
        vm.expectRevert(bytes("Can't forfeit a bet that has not been accepted yet"));

        // Act
        casinoContract.forfeit(hashA);
    }

    function testACannotForfeitIfHasNotRevealedRandomA(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);

        // Assert
        vm.expectRevert(bytes("Can't forfeit a bet if you haven't revealed your number"));

        // Act
        casinoContract.forfeit(hashA);
    }

    function testACannotForfeitIfBRevealDeadlineHasNotPassedYet(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.startPrank(playerA);
        casinoContract.revealRandomA(valA);

        // Assert
        vm.expectRevert(bytes("Player B reveal deadline not reached yet"));

        // Act
        casinoContract.forfeit(hashA);

        // Clean up
        vm.stopPrank();
    }

    function testBCannotForfeitNotAcceptedBet(address account, uint256 amount) public {
        // Arrange
        vm.assume(account != playerA && account != playerB);
        _skipTestIfAccountIsInvalid(account);
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(account, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerB);

        // Assert
        vm.expectRevert(bytes("Not your bet"));

        // Act
        casinoContract.forfeit(hashA);
    }

    function testBCannotForfeitIfARevealedRandomA(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        hoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        vm.prank(playerA);
        casinoContract.revealRandomA(valA);

        vm.prank(playerB);

        // Assert
        vm.expectRevert(bytes("Can't forfeit bet if A revealed his number"));

        // Act
        casinoContract.forfeit(hashA);
    }

    function testBCannotForfeitIfARevealDeadlineHasNotExpired(uint256 amount) public {
        // Arrange
        vm.assume(0 < amount && amount <= 100 ether);

        hoax(playerA, amount);
        casinoContract.proposeBet{value: amount}(hashA);

        startHoax(playerB, amount);
        casinoContract.acceptBet{value: amount}(hashA, hashB);

        // Assert
        vm.expectRevert(bytes("Player A reveal deadline not reached yet"));

        // Act
        casinoContract.forfeit(hashA);
    }
}
