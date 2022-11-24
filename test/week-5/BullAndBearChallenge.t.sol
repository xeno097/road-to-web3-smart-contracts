// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-5/BullAndBearChallenge.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract BullAndBearChallengeTest is Test {
    uint64 fakeSubscriptionId = 1;
    address fakeVrfCoordinator = address(101);
    address fakePriceFeed = address(102);
    address constant testAccount = 0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097;
    BullAndBearChallenge bullAndBearContract;

    event TokenUrisUpdated(BullAndBearChallenge.MarketTrend indexed trend, uint256 indexed timestamp, uint256 uriIdx);

    function _setUpPriceFeedMockedCall(int256 price) private {
        vm.mockCall(
            fakePriceFeed,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(uint80(1), price, block.timestamp, block.timestamp, uint80(1))
        );
    }

    function _setUpVrfCoordinatorMockedCall(uint80 requestId) private {
        vm.mockCall(
            fakeVrfCoordinator,
            abi.encodeWithSelector(VRFCoordinatorV2Interface.requestRandomWords.selector),
            abi.encode(requestId)
        );
    }

    function setUp() public {
        _setUpPriceFeedMockedCall(1);

        bullAndBearContract = new BullAndBearChallenge(fakeSubscriptionId,fakeVrfCoordinator,fakePriceFeed);

        vm.clearMockedCalls();
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
        bullAndBearContract.safeMint(account);

        // Assert
        assertEq(bullAndBearContract.balanceOf(account), 1);
        assertEq(bullAndBearContract.ownerOf(0), account);
        assertEq(
            bullAndBearContract.tokenURI(0),
            "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json"
        );
    }

    // getLatestPrice
    function testGetLatestPrice() public {
        // Arrange
        int256 expectedPrice = 10;

        _setUpPriceFeedMockedCall(expectedPrice);

        // Act
        int256 price = bullAndBearContract.getLatestPrice();

        // Assert
        assertEq(price, expectedPrice);

        // CleanUp
        vm.clearMockedCalls();
    }

    // checkUpkeep
    function testCheckUpkeepReturnsFalseIfADayHasNotPassedYet() public {
        // Act
        (bool res,) = bullAndBearContract.checkUpkeep(abi.encode());

        // Assert
        assertEq(res, false);
    }

    function testCheckUpkeepReturnsTrueIfADayHasPassed() public {
        // Arrange
        skip(1 days);

        // Act
        (bool res,) = bullAndBearContract.checkUpkeep(abi.encode());

        // Assert
        assertEq(res, true);
    }

    // performUpkeep
    function testPerformUpkeepMakesNoChangesIfIntervalHasNotPassed() public {
        // Act
        bullAndBearContract.performUpkeep(abi.encode());

        // Assert
        assertEq(bullAndBearContract.currentPrice(), 1);
    }

    function testPerformUpkeepUpdateCurrentMarketTrendToBearishIfNewPriceIsLessThanCurrentPrice() public {
        // Arrange
        skip(1 days);

        int256 expectedPrice = -10;

        _setUpPriceFeedMockedCall(expectedPrice);

        _setUpVrfCoordinatorMockedCall(1);

        // Act
        bullAndBearContract.performUpkeep(abi.encode());

        // Assert
        assertEq(bullAndBearContract.currentPrice(), expectedPrice);
        assertEq(uint256(bullAndBearContract.currentMarketTrend()), uint256(BullAndBearChallenge.MarketTrend.Bearish));
    }

    // rawFulfillRandomWords (fulfillRandomWords)
    function testFulFillRandomWordsUpdatesTokenUriWithBullishTrend() public {
        // Arrange
        bullAndBearContract.safeMint(testAccount);

        vm.prank(fakeVrfCoordinator);

        uint256[] memory fakeResponse = new uint256[](1);
        fakeResponse[0] = 5;

        // Act
        bullAndBearContract.rawFulfillRandomWords(1, fakeResponse);

        // Assert
        assertEq(
            bullAndBearContract.tokenURI(0),
            "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
        );
    }

    function testFulFillRandomWordsUpdatesTokenUriWithBearishTrend() public {
        // Arrange
        bullAndBearContract.safeMint(testAccount);

        int256 expectedPrice = -10;

        _setUpPriceFeedMockedCall(expectedPrice);

        _setUpVrfCoordinatorMockedCall(1);

        bullAndBearContract.forcePerformUpkeep();

        vm.prank(fakeVrfCoordinator);

        uint256[] memory fakeResponse = new uint256[](1);
        fakeResponse[0] = 5;

        // Act
        bullAndBearContract.rawFulfillRandomWords(1, fakeResponse);

        // Assert
        assertEq(
            bullAndBearContract.tokenURI(0),
            "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
        );
    }

    function testFulFillRandomWordsEmitsTokensUpdated() public {
        // Arrange
        vm.prank(fakeVrfCoordinator);

        uint256[] memory fakeResponse = new uint256[](1);
        fakeResponse[0] = 5;

        // Assert
        vm.expectEmit(true, false, true, true);

        emit TokenUrisUpdated(BullAndBearChallenge.MarketTrend.Bullish, block.timestamp, 2);

        // Act
        bullAndBearContract.rawFulfillRandomWords(1, fakeResponse);
    }
}
