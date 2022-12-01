// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-7/NFTMarketplaceChallenge.sol";

contract NFTMarketplaceChallengeTest is Test {
    uint256 marketplaceListFee = 0.01 ether;
    string tokenURI = "Some random tokenURI";
    NFTMarketplaceChallenge nftMarketplaceContract;

    event TokenListedSuccess(uint256 indexed tokenId, address creator, address owner, uint256 price);

    function setUp() public {
        nftMarketplaceContract = new NFTMarketplaceChallenge();
    }

    function _skipTestIfAccountIsInvalid(address account) private view {
        vm.assume(account != address(0) && account != 0x0000000000000000000000000000000000000009);
        vm.assume(account.code.length == 0);
    }

    // createToken
    function testMintsANewTokenAndSendItToTheMarketPlaceAddress(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        vm.deal(account, marketplaceListFee);
        vm.prank(account);

        // Act
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, price);

        // Assert
        assertEq(nftMarketplaceContract.balanceOf(address(nftMarketplaceContract)), 1);
        assertEq(nftMarketplaceContract.ownerOf(0), address(nftMarketplaceContract));
        assertEq(nftMarketplaceContract.tokenURI(0), tokenURI);
    }

    function testMintsANewTokenAndSetTheMarketplaceData(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        vm.deal(account, marketplaceListFee);
        vm.prank(account);

        // Act
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, price);

        // Assert
        NFTMarketplaceChallenge.ListedToken memory data = nftMarketplaceContract.getListedTokenById(0);

        assertEq(data.tokenId, 0);
        assertEq(data.owner, payable(account));
        assertEq(data.creator, payable(account));
        assertEq(data.price, price);
        assertEq(data.currentlyListed, true);
    }

    function testMintsANewTokenAndEmitTokenListedSuccess(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        vm.deal(account, marketplaceListFee);
        vm.prank(account);

        // Assert
        vm.expectEmit(true, true, true, true);

        emit TokenListedSuccess(0, account, account, price);

        // Act
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, price);
    }

    function testCannotCreateANewTokenWithPrice0(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.deal(account, marketplaceListFee);
        vm.prank(account);

        // Assert
        vm.expectRevert(bytes("Marketplace: Invalid price"));

        // Act
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, 0);
    }

    function testCannotCreateANewTokenWithoutPayingListFee(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        vm.deal(account, marketplaceListFee);
        vm.prank(account);

        // Assert
        vm.expectRevert(bytes("Markeplace: Invalid listing fee"));

        // Act
        nftMarketplaceContract.createToken{value: 0}(tokenURI, price);
    }

    // getAllNFTs
    function testGetAllNFTsReturnsEmtpyArrayIfNoTokensHaveBeenCreated() public {
        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getAllNFTs();

        // Assert
        assertEq(nfts.length, 0);
    }

    function testGetAllNFTsReturnsAllTheNfts(address account, uint256 numberOfNfts) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(0 < numberOfNfts && numberOfNfts < 1000);
        vm.deal(account, numberOfNfts * marketplaceListFee);
        vm.startPrank(account);

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, 10 ether);
        }

        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getAllNFTs();

        // Assert
        assertEq(nfts.length, numberOfNfts);

        // Clean up
        vm.stopPrank();
    }

    // getPublishedNFTS
    function testGetPublishedNFTsReturnsAnEmptyArrayIfNoTokensHaveBeenCreated() public {
        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getPublishedNFTs();

        // Assert
        assertEq(nfts.length, 0);
    }

    function testGetPublishedNFTsReturnsAnEmptyArrayIfThereAreNoPublishedNFTs(address account, uint256 numberOfNfts)
        public
    {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(0 < numberOfNfts && numberOfNfts < 50);
        vm.deal(account, numberOfNfts * marketplaceListFee);
        vm.startPrank(account);

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, 10 ether);
        }

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.hideNFT(i);
        }

        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getPublishedNFTs();

        // Assert
        assertEq(nfts.length, 0);

        // Clean up
        vm.stopPrank();
    }
}
