// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "@contracts/week-7/NFTMarketplaceChallenge.sol";

contract NFTMarketplaceChallengeTest is Test {
    uint256 marketplaceListFee = 0.01 ether;
    uint256 itemPrice = 0.5 ether;
    string tokenURI = "Some random tokenURI";
    address constant testAccount = 0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097;
    NFTMarketplaceChallenge nftMarketplaceContract;

    event TokenListedSuccess(uint256 indexed tokenId, address creator, address owner, uint256 price);

    function setUp() public {
        nftMarketplaceContract = new NFTMarketplaceChallenge(marketplaceListFee);
    }

    function _skipTestIfAccountIsInvalid(address account) private view {
        // Exclude 0 address and precompiled contracts.
        vm.assume(uint160(account) > 10 && account != address(this));
        vm.assume(account.code.length == 0);
    }

    // createToken
    function testCreateTokenSendNewNFTToMarketplaceAddress(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        hoax(account, marketplaceListFee);

        // Act
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, price);

        // Assert
        assertEq(nftMarketplaceContract.balanceOf(address(nftMarketplaceContract)), 1);
        assertEq(nftMarketplaceContract.ownerOf(0), address(nftMarketplaceContract));
        assertEq(nftMarketplaceContract.tokenURI(0), tokenURI);
    }

    function testCreateTokenSetsNFTMarketplaceData(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        hoax(account, marketplaceListFee);

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

    function testCreateTokenEmitsTokenListedSuccess(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        hoax(account, marketplaceListFee);

        // Assert
        vm.expectEmit(true, true, true, true);

        emit TokenListedSuccess(0, account, account, price);

        // Act
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, price);
    }

    function testCannotCreateNewTokenWithPrice0(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        hoax(account, marketplaceListFee);

        // Assert
        vm.expectRevert(bytes("Marketplace: Invalid price"));

        // Act
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, 0);
    }

    function testCannotCreateNewTokenForFree(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        hoax(account, marketplaceListFee);

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
        startHoax(account, numberOfNfts * marketplaceListFee);

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
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
        startHoax(account, numberOfNfts * marketplaceListFee);

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
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

    function testGetPublishedNFTsReturnsPublishedNFTs(address account, uint256 numberOfNfts) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(0 < numberOfNfts && numberOfNfts < 50);
        startHoax(account, numberOfNfts * marketplaceListFee);

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        }

        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getPublishedNFTs();

        // Assert
        assertEq(nfts.length, numberOfNfts);

        // Clean up
        vm.stopPrank();
    }

    // getMyNFTs
    function testGetMyNFTsReturnsEmptyArrayIfNoTokensHaveBeenCreated() public {
        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getMyNFTs();

        // Assert
        assertEq(nfts.length, 0);
    }

    function testGetMyNFTsReturnsEmtpyArrayIfUserDoesNotOwnAnyNFTs(
        address account1,
        address account2,
        uint256 numberOfNfts
    ) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);
        vm.assume(0 < numberOfNfts && numberOfNfts < 50);
        startHoax(account1, numberOfNfts * marketplaceListFee);

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        }

        vm.stopPrank();
        vm.prank(account2);

        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getMyNFTs();

        // Assert
        assertEq(nfts.length, 0);
    }

    function testGetMyNFTsReturnsAllTheNFTsOwnedByUser(address account, uint256 numberOfNfts) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(0 < numberOfNfts && numberOfNfts < 50);
        startHoax(account, numberOfNfts * marketplaceListFee);

        for (uint256 i = 0; i < numberOfNfts; i++) {
            nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        }

        // Act
        NFTMarketplaceChallenge.ListedToken[] memory nfts = nftMarketplaceContract.getMyNFTs();

        // Assert
        assertEq(nfts.length, numberOfNfts);

        // Clean up
        vm.stopPrank();
    }

    // executeSale
    function testExecuteSale(address account1, address account2) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);

        vm.prank(testAccount);
        NFTMarketplaceChallenge marketplaceContract = new NFTMarketplaceChallenge(marketplaceListFee);

        hoax(account1, marketplaceListFee);
        marketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        hoax(account2,itemPrice);

        // Act
        marketplaceContract.executeSale{value: itemPrice}(0);

        // Assert
        NFTMarketplaceChallenge.ListedToken memory data = marketplaceContract.getListedTokenById(0);

        assertEq(data.tokenId, 0);
        assertEq(data.owner, payable(account2));
        assertEq(data.creator, payable(account1));
        assertEq(data.price, itemPrice);
        assertEq(data.currentlyListed, false);
    }

    function testCannotExecuteSaleForFree(address account1, address account2) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);

        hoax(account1, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        hoax(account2,itemPrice);

        // Assert
        vm.expectRevert(bytes("Marketplace: Invalid NFT price"));

        // Act
        nftMarketplaceContract.executeSale{value: 0}(0);
    }

    function testCannotExecuteSaleForHiddenItem(address account1, address account2) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);
        
        startHoax(account1, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        nftMarketplaceContract.hideNFT(0);
        vm.stopPrank();

        hoax(account2,itemPrice);

        // Assert
        vm.expectRevert(bytes("Marketplace: NFT not for sale"));

        // Act
        nftMarketplaceContract.executeSale{value: itemPrice}(0);
    }

    function testCannotExecuteSaleForOwnItem(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);

        startHoax(account, marketplaceListFee + itemPrice);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        // Assert
        vm.expectRevert(bytes("Marketplace: You already own this NFT"));

        // Act
        nftMarketplaceContract.executeSale{value: itemPrice}(0);

        // Clean up
        vm.stopPrank();
    }

    // listNFTForSale
    function testListForSale(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);

        startHoax(account, 2 * marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        nftMarketplaceContract.hideNFT(0);

        // Act
        nftMarketplaceContract.listNFTForSale{value: marketplaceListFee}(0);

        // Assert
        NFTMarketplaceChallenge.ListedToken memory nft = nftMarketplaceContract.getListedTokenById(0);

        assertTrue(nft.currentlyListed);

        // Clean up
        vm.stopPrank();
    }

    function testCannotListForSaleIfIsNotTheOwner(address account1, address account2) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);

        hoax(account1, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        hoax(account2, marketplaceListFee);

        // Assert
        vm.expectRevert(bytes("Marketplace: Not the NFT Owner"));

        // Act
        nftMarketplaceContract.listNFTForSale{value: marketplaceListFee}(0);
    }

    function testCannotListForSaleAlreadyListedNFT(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);

        startHoax(account, 2 * marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        // Assert
        vm.expectRevert(bytes("Marketplace: Already listed for sale"));

        // Act
        nftMarketplaceContract.listNFTForSale{value: marketplaceListFee}(0);

        // Clean up
        vm.stopPrank();
    }

    function testCannotListForSaleForFree(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        
        startHoax(account, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        nftMarketplaceContract.hideNFT(0);

        // Assert
        vm.expectRevert(bytes("Markeplace: Invalid listing fee"));

        // Act
        nftMarketplaceContract.listNFTForSale{value: 0}(0);

        // Clean up
        vm.stopPrank();
    }

    // hideNFT
    function testHideNFT(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        
        startHoax(account, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        // Act
        nftMarketplaceContract.hideNFT(0);

        // Assert
        NFTMarketplaceChallenge.ListedToken memory nft = nftMarketplaceContract.getListedTokenById(0);

        assertFalse(nft.currentlyListed);

        // Clean up
        vm.stopPrank();
    }

    function testCannotHideNFTIfIsNotTheOwner(address account1, address account2) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);

        hoax(account1, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        vm.prank(account2);

        // Assert
        vm.expectRevert(bytes("Marketplace: Not the NFT Owner"));

        // Act
        nftMarketplaceContract.hideNFT(0);
    }

    function testCannotHideAlreadyHiddenNFT(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);

        startHoax(account, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        nftMarketplaceContract.hideNFT(0);

        // Assert
        vm.expectRevert(bytes("Marketplace: NFT already hidden"));

        // Act
        nftMarketplaceContract.hideNFT(0);

        // Clean up
        vm.stopPrank();
    }

    // updateNFTPrice
    function testUpdateNFTPrice(address account, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(price != 0);
        
        startHoax(account, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        nftMarketplaceContract.hideNFT(0);

        // Act
        nftMarketplaceContract.updateNFTPrice(0, price);

        // Assert
        NFTMarketplaceChallenge.ListedToken memory nft = nftMarketplaceContract.getListedTokenById(0);

        assertEq(nft.price, price);

        // Clean up
        vm.stopPrank();
    }

    function testCannotUpdateNFTPriceTo0(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        
        startHoax(account, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);
        nftMarketplaceContract.hideNFT(0);

        // Assert
        vm.expectRevert(bytes("Marketplace: Invalid price"));

        // Act
        nftMarketplaceContract.updateNFTPrice(0, 0);

        // Clean up
        vm.stopPrank();
    }

    function testCannotUpdateNFTPriceForListedItem(address account1, uint256 price) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        vm.assume(price != 0);

        startHoax(account1, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        // Assert
        vm.expectRevert(bytes("Marketplace: Can't change price of a listed item"));

        // Act
        nftMarketplaceContract.updateNFTPrice(0, price);

        // Clean up
        vm.stopPrank();
    }

    function testCannotUpdateNFTPriceIfNotTheOwner(address account1, address account2) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account1);
        _skipTestIfAccountIsInvalid(account2);
        vm.assume(account1 != account2);

        hoax(account1, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        vm.prank(account2);

        // Assert
        vm.expectRevert(bytes("Marketplace: Not the NFT Owner"));

        // Act
        nftMarketplaceContract.updateNFTPrice(0, 10 ether);
    }

    // updateListFee
    function testUpdateListFee(uint256 newFee) public {
        // Arrange
        vm.assume(newFee != 0);

        // Act
        nftMarketplaceContract.updateListFee(newFee);

        // Assert
        assertEq(nftMarketplaceContract.getListFee(), newFee);
    }

    function testCannotUpdateListFeeTo0() public {
        // Assert
        vm.expectRevert(bytes("Marketplace: Invalid list fee update"));

        // Act
        nftMarketplaceContract.updateListFee(0);
    }

    function testCannotUpdateListFeeIfNotMarketplaceOwner(address account, uint256 newFee) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);
        vm.assume(newFee != 0);
        vm.prank(account);

        // Assert
        vm.expectRevert(bytes("Marketplace: Not marketplace owner"));

        // Act
        nftMarketplaceContract.updateListFee(newFee);
    }

    // getListFee
    function testGetListFee(address account) public {
        // Arrange
        vm.prank(account);

        // Act
        uint256 fee = nftMarketplaceContract.getListFee();

        // Assert
        assertEq(fee, marketplaceListFee);
    }

    // getListedTokenById
    function testGetListedTokenById(address account) public {
        // Arrange
        _skipTestIfAccountIsInvalid(account);

        hoax(account, marketplaceListFee);
        nftMarketplaceContract.createToken{value: marketplaceListFee}(tokenURI, itemPrice);

        // Act
        NFTMarketplaceChallenge.ListedToken memory data = nftMarketplaceContract.getListedTokenById(0);

        // Assert
        assertEq(data.tokenId, 0);
        assertEq(data.owner, payable(account));
        assertEq(data.creator, payable(account));
        assertEq(data.price, itemPrice);
        assertEq(data.currentlyListed, true);
    }

    function testCannotGetListedTokenByIdIfNotExist(address account) public {
        // Arrange
        vm.prank(account);

        // Assert
        vm.expectRevert(bytes("Marketplace: Non existent NFT"));

        // Act
        nftMarketplaceContract.getListedTokenById(0);
    }
}
