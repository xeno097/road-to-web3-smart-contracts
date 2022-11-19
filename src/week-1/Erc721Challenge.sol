// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

error MintLimitPerUserReached(uint256);
error MaxSupplyReached(uint256);

contract Erc721Challenge is ERC721, ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256 immutable MAX_SUPPLY;
    uint256 immutable MINT_LIMIT_PER_USER;

    mapping(address => uint8) private mints;

    constructor(uint256 _maxSupply, uint256 _mintLimitPerUser) ERC721("Xeno097", "AXN97") {
        MAX_SUPPLY = _maxSupply;
        MINT_LIMIT_PER_USER = _mintLimitPerUser;
    }

    modifier limitMints() {
        if (mints[msg.sender] == MINT_LIMIT_PER_USER) {
            revert MintLimitPerUserReached(MINT_LIMIT_PER_USER);
        }
        _;
    }

    function totalMintCount() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function mintBalanceOf(address minter) public view returns (uint8) {
        return mints[minter];
    }

    function safeMint(address to, string memory uri) public limitMints {
        if (_tokenIdCounter.current() == MAX_SUPPLY) {
            revert MaxSupplyReached(MAX_SUPPLY);
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        mints[msg.sender] = mints[msg.sender] + 1;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // Overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256)
        internal
        override (ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, 1);
    }

    function _burn(uint256 tokenId) internal override (ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override (ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override (ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
