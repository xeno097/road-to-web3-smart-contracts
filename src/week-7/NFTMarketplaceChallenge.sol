//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplaceChallenge is ERC721URIStorage {
    using Counters for Counters.Counter;

    // Tracks the number of minted tokens.
    Counters.Counter private _tokenIds;

    // Keeps track of the number of items sold on the marketplace.
    Counters.Counter private _itemsSold;

    // Keeps track of the number of items published for sale on the marketplace.
    Counters.Counter private _publishedItems;

    // Address that created this smart contract.
    address payable owner;

    // Fee charged by the marketplace to to list an NFT.
    uint256 listFee = 0.01 ether;

    // Marketplace data for an NFT.
    struct ListedToken {
        uint256 tokenId;
        address payable creator;
        address payable owner;
        uint256 price;
        bool currentlyListed;
    }

    // Event emitted when a token is successfully listed.
    event TokenListedSuccess(uint256 indexed tokenId, address creator, address owner, uint256 price);

    // Maps a tokenId to the NFT's marketplace data.
    mapping(uint256 => ListedToken) private idToListedToken;

    constructor() ERC721("XN097NFTMarketplace", "XNFTM") {
        owner = payable(msg.sender);
    }

    modifier onlyNFTOwner(uint256 tokenId) {
        require(
            idToListedToken[tokenId].owner == msg.sender, "Marketplace: only the NFT owner can perform this operation"
        );
        _;
    }

    /// @dev Mints a token and lists it for sale.
    function createToken(string memory tokenURI, uint256 price) public payable returns (uint256) {
        uint256 newTokenId = _tokenIds.current();

        // Increment the tokenId counter, which is keeping track of the number of minted NFTs
        _tokenIds.increment();

        // Mint the NFT with newTokenId to the address who called createToken
        _safeMint(msg.sender, newTokenId);

        // Map the tokenId to the tokenURI
        _setTokenURI(newTokenId, tokenURI);

        // Helper function to update Global variables and emit an event
        _createListedToken(newTokenId, price);

        _listNFTForSale(newTokenId);

        return newTokenId;
    }

    /// @dev Creates the NFT's marketplace data.
    function _createListedToken(uint256 tokenId, uint256 price) private {
        // Just sanity check
        require(price > 0, "Marketplace: Invalid price");

        // Update the mapping of tokenId's to Token details, useful for retrieval functions
        idToListedToken[tokenId] = ListedToken({
            tokenId: tokenId,
            owner: payable(msg.sender),
            creator: payable(msg.sender),
            price: price,
            currentlyListed: true
        });
    }

    /// @dev Lists an existing NFT for sale on the marketplace.
    function _listNFTForSale(uint256 tokenId) private {
        require(msg.value == listFee, "Markeplace: Invalid listing fee");

        ListedToken storage item = idToListedToken[tokenId];

        // Transfer the NFT to the marketplace
        _transfer(msg.sender, address(this), tokenId);

        item.currentlyListed = true;
        _publishedItems.increment();

        emit TokenListedSuccess(tokenId, item.creator, item.owner, item.price);
    }

    /// @dev Returns all the NFTs.
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint256 nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);

        for (uint256 i = 0; i < nftCount; i++) {
            ListedToken storage currentItem = idToListedToken[i];
            tokens[i] = currentItem;
        }

        return tokens;
    }

    /// @dev Returns all the NFTs that are listed on the marketplace to be sold.
    function getPublishedNFTs() public view returns (ListedToken[] memory) {
        uint256 totalNftCount = _tokenIds.current();
        uint256 totalPublishedNftCount = _publishedItems.current();
        ListedToken[] memory tokens = new ListedToken[](totalPublishedNftCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalNftCount; i++) {
            ListedToken storage currentItem = idToListedToken[i];
            if (currentItem.currentlyListed) {
                tokens[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return tokens;
    }

    /// @dev Returns all the NFTs owned or created by a user.
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        // Get the count of NFTs owned or created by the user.
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToListedToken[i].owner == msg.sender || idToListedToken[i].creator == msg.sender) {
                itemCount += 1;
            }
        }

        // Get the NFTs owned or created by the user.
        ListedToken[] memory items = new ListedToken[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToListedToken[i].owner == msg.sender || idToListedToken[i].creator == msg.sender) {
                ListedToken storage currentItem = idToListedToken[i];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }

        return items;
    }

    /// @dev Allows a user to buy an NFT.
    function executeSale(uint256 tokenId) public payable {
        ListedToken storage currentItem = idToListedToken[tokenId];

        address currentSeller = currentItem.owner;

        require(
            msg.value == currentItem.price,
            "Marketplace: Please submit the asking price in order to complete the purchase"
        );

        require(currentItem.currentlyListed, "Marketplace: You can't buy an item that is not listed for sale");

        require(msg.sender != currentItem.owner, "Marketplace: You can't buy an item that you already own");

        // Update the details of the token
        currentItem.currentlyListed = false;
        currentItem.owner = payable(msg.sender);
        _itemsSold.increment();
        _publishedItems.decrement();

        // Actually transfer the token to the new owner
        _transfer(address(this), msg.sender, tokenId);

        // Transfer the listing fee to the marketplace creator
        payable(owner).transfer(listFee);

        // Transfer the proceeds from the sale to the seller of the NFT
        payable(currentSeller).transfer((msg.value * 90) / 100);

        // Transfer 10% of the selling price to the NFT creator
        payable(currentItem.creator).transfer(msg.value / 10);
    }

    /// @dev Allows the NFT's owner to publish it on the markeplace.
    function listNFTForSale(uint256 tokenId) public payable onlyNFTOwner(tokenId) {
        require(!idToListedToken[tokenId].currentlyListed, "Marketplace: Item already listed for sale");

        _listNFTForSale(tokenId);
    }

    /// @dev Allows the NFT's owner to unpublish it from the marketplace.
    function hideNFT(uint256 tokenId) public onlyNFTOwner(tokenId) {
        ListedToken storage item = idToListedToken[tokenId];
        require(item.currentlyListed, "Marketplace: Item already hidden from marketplace");

        // Send the NFT back to its owner and reset approvals
        _transfer(address(this), msg.sender, tokenId);

        item.currentlyListed = false;
        _publishedItems.decrement();
    }

    /// @dev Allows an NFT's owner to update its price before listing it on the marketplace.
    function updateNFTPrice(uint256 tokenId, uint256 _price) public onlyNFTOwner(tokenId) {
        ListedToken storage item = idToListedToken[tokenId];

        require(!item.currentlyListed, "Marketplace: Can't change price of a listed item");

        item.price = _price;
    }

    /// @dev Allows the marketplace owner to update the listing fee.
    function updateListFee(uint256 _listFee) public payable {
        require(owner == msg.sender, "Only owner can update listing price");
        listFee = _listFee;
    }

    /// @dev Returns the current fee needed to list an existing NFT on the marketplace.
    function getListFee() public view returns (uint256) {
        return listFee;
    }

    /// @dev Returns the marketplace data for an existing NFT.
    function getListedTokenById(uint256 tokenId) public view returns (ListedToken memory) {
        _exists(tokenId);

        return idToListedToken[tokenId];
    }
}
