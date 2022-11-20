// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

error Unauthorized();
error FreeIcedCoffeeNotAllowed();
error InvalidLargeIcedCoffeeTip();

contract BuyMeAIcedCoffeeChallenge {
    struct Memo {
        address from;
        uint256 timestamp;
        string name;
        string message;
    }

    /// @dev Address allowed to withdraw this contract's balance.
    address payable owner;

    // List of all memos received from coffee purchases.
    Memo[] memos;

    event NewMemo(address indexed from, uint256 timestamp, string name, string message);

    constructor() {
        owner = payable(msg.sender);
    }

    /// @dev Allows only the contract's owner to invoke the decorated function.
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    /// @dev Returns the memos stored in this smart contract.
    function getMemos() public view returns (Memo[] memory) {
        return memos;
    }

    ///  @dev buy an iced coffee for owner (sends an ETH tip and leaves a memo)
    function buyARegularIcedCoffee(string memory _name, string memory _message) public payable {
        if (msg.value == 0) {
            revert FreeIcedCoffeeNotAllowed();
        }

        _addMemo(_name, _message);
    }

    /// @dev buy a large iced coffee for owner (sends an ETH tip and leaves a memo)
    function buyALargeIcedCoffe(string memory _name, string memory _message) public payable {
        if (msg.value != 0.003 ether) {
            revert InvalidLargeIcedCoffeeTip();
        }

        _addMemo(_name, _message);
    }

    /// @dev Stores a memo in this smart contract's storage.
    function _addMemo(string memory name, string memory message) private {
        memos.push(Memo({from: msg.sender, timestamp: block.timestamp, name: name, message: message}));

        emit NewMemo({from: msg.sender, timestamp: block.timestamp, name: name, message: message});
    }

    /// @dev Withdraws this smart contract's balance to the owner's address.
    function withdrawTips() public {
        require(owner.send(address(this).balance));
    }

    /// @dev updates the owner of the contract only if the account invoking the function is the actual owner of the contract.
    function updateContractOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0));

        owner = payable(newOwner);
    }
}
