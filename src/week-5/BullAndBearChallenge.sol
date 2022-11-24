// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

contract BullAndBearChallenge is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    VRFConsumerBaseV2,
    KeeperCompatibleInterface
{
    // NFT contract variables
    address owner;

    using Counters for Counters.Counter;

    Counters.Counter private _tokenId;

    // Chainlink randomness coordinator
    VRFCoordinatorV2Interface COORDINATOR;

    // Chainlink price feed
    AggregatorV3Interface pricefeed;
    int256 public currentPrice;
    uint256 constant interval = 1 days;
    uint256 public lastTimeStamp;

    // Chainlink VRF options
    uint64 VRFSubscriptionId;
    bytes32 gasLaneKeyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
    uint32 callbackGasLimit = 60000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    // Chainlink request control
    uint256 private pendingVrfRequestId;

    enum MarketTrend {
        Bullish,
        Bearish
    }

    MarketTrend public currentMarketTrend = MarketTrend.Bullish;

    // Events
    event TokenUrisUpdated(MarketTrend indexed trend, uint256 indexed timestamp, uint256 uriIdx);

    // NFT metadata uris
    string[] bullUrisIpfs = [
        "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json",
        "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
        "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];

    string[] bearUrisIpfs = [
        "https://ipfs.io/ipfs/Qmdx9Hx7FCDZGExyjLR6vYcnutUR8KhBZBnZfAPHiUommN?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    constructor(uint64 subscriptionId, address _vrfCoordinator, address _pricefeed)
        ERC721("Xeno097Bull&Bear", "XN97B&B")
        VRFConsumerBaseV2(_vrfCoordinator)
    {
        owner = msg.sender;
        lastTimeStamp = block.timestamp;

        // Chainlink config
        VRFSubscriptionId = subscriptionId;

        // Set the coordinator to the Rinkeby coordinator.
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);

        pricefeed = AggregatorV3Interface(_pricefeed);

        // set the price for the chosen currency pair.
        currentPrice = getLatestPrice();
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /// @dev Mints a new NFT with bull metadata.
    function safeMint(address to) public {
        uint256 tokenId = _tokenId.current();
        _tokenId.increment();

        _safeMint(to, tokenId);

        // Default to a bull NFT
        string memory defaultUri = bullUrisIpfs[0];
        _setTokenURI(tokenId, defaultUri);
    }

    // VRF overrides
    /// @dev Function used by the VRFCoordinator to fullfill the randomness request. Must not override!!!
    /// https://docs.chain.link/vrf/v2/security/
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        pendingVrfRequestId = 0;

        uint256 metadataIdx = (randomWords[0] % 3);
        _updateAllTokenUris(metadataIdx);
    }

    // Keeper compatible overrides for Chainlink automation https://docs.chain.link/chainlink-automation/compatible-contracts
    /// @dev Instructs chainlink automation if the action to automate can be called or not.
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) >= interval;

        return (upkeepNeeded, performData);
    }

    /// @dev Function called by chainlink automation if checkUpkeep returns true.
    function performUpkeep(bytes calldata /* performData */ ) external override {
        if ((block.timestamp - lastTimeStamp) >= interval) {
            _performUpKeep();
        } else {
            return;
        }
    }

    /// @dev Allows owner to manually force the price feed update.
    function forcePerformUpkeep() public onlyOwner {
        _performUpKeep();
    }

    /// @dev Updates the price, the market trend and performs a request for random numbers.
    function _performUpKeep() internal {
        lastTimeStamp = block.timestamp;
        int256 latestPrice = getLatestPrice();

        if (latestPrice == currentPrice) {
            return;
        }

        if (latestPrice < currentPrice) {
            currentMarketTrend = MarketTrend.Bearish;
        } else {
            currentMarketTrend = MarketTrend.Bullish;
        }

        // Perform the randomness request only if there isn't another pending request.
        if (pendingVrfRequestId != 0) {
            pendingVrfRequestId = COORDINATOR.requestRandomWords(
                gasLaneKeyHash, VRFSubscriptionId, requestConfirmations, callbackGasLimit, numWords
            );
        }

        currentPrice = latestPrice;
    }

    // Helpers
    /// @dev Gets the latest price from the selected AggregatorV3Interface price feed.
    /// https://docs.chain.link/data-feeds/price-feeds
    function getLatestPrice() public view returns (int256) {
        (, int256 price,,,) = pricefeed.latestRoundData();

        return price;
    }

    /// @dev Updates all the currently minted NFT's metadata based on the current market trend.
    /// https://docs.chain.link/data-feeds/price-feeds
    function _updateAllTokenUris(uint256 idx) internal {
        string[] storage uris = currentMarketTrend == MarketTrend.Bullish ? bullUrisIpfs : bearUrisIpfs;

        string memory uri = uris[idx];

        for (uint256 i = 0; i < _tokenId.current(); i++) {
            _setTokenURI(i, uri);
        }

        emit TokenUrisUpdated(currentMarketTrend, block.timestamp, idx);
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batch)
        internal
        override (ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batch);
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
