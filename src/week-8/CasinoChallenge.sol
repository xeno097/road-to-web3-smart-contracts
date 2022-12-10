//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract CasinoChallenge {
    struct ProposedBet {
        address sideA;
        uint256 value;
        uint256 placedAt;
        uint256 randomA;
        uint256 revealedAt;
        bool revealed;
        bool accepted;
    }

    struct AcceptedBet {
        address sideB;
        uint256 acceptedAt;
        uint256 randomB;
    }

    uint256 public revealDeadline;
    address owner;

    // Proposed bets, keyed by the commitment value
    mapping(uint256 => ProposedBet) public proposedBet;

    // Accepted bets, also keyed by commitment value
    mapping(uint256 => AcceptedBet) public acceptedBet;

    event BetProposed(uint256 indexed _commitment, uint256 value);

    event BetAccepted(uint256 indexed _commitment, address indexed _sideA);

    event NumberRevealed(uint256 indexed _commitment, address indexed player);

    event BetSettled(uint256 indexed _commitment, address winner, address loser, uint256 value);

    constructor(uint256 _revealDeadline) {
        owner = msg.sender;
        revealDeadline = _revealDeadline;
    }

    modifier onlyOwnBet(uint256 _commitment) {
        require(
            proposedBet[_commitment].sideA == msg.sender || acceptedBet[_commitment].sideB == msg.sender, "Not your bet"
        );
        _;
    }

    function setRevealDeadline(uint256 _revealDeadline) public {
        require(owner == msg.sender, "Not the owner");
        revealDeadline = _revealDeadline;
    }

    // Called by sideA to start the process
    function proposeBet(uint256 _commitment) external payable {
        require(proposedBet[_commitment].value == 0, "there is already a bet on that commitment");
        require(msg.value > 0, "you need to actually bet something");

        proposedBet[_commitment].sideA = msg.sender;
        proposedBet[_commitment].value = msg.value;
        proposedBet[_commitment].placedAt = block.timestamp;

        emit BetProposed(_commitment, msg.value);
    }

    // Called by sideB to continue
    function acceptBet(uint256 _commitment, uint256 _random) external payable {
        require(!proposedBet[_commitment].accepted, "Bet has already been accepted");
        require(proposedBet[_commitment].sideA != address(0), "Nobody made that bet");
        require(proposedBet[_commitment].sideA != msg.sender, "Can't accept your own bet");
        require(msg.value == proposedBet[_commitment].value, "Need to bet the same amount as sideA");

        acceptedBet[_commitment].sideB = msg.sender;
        acceptedBet[_commitment].acceptedAt = block.timestamp;
        acceptedBet[_commitment].randomB = _random;
        proposedBet[_commitment].accepted = true;

        emit BetAccepted(_commitment, proposedBet[_commitment].sideA);
    }

    // Called by sideA to reveal their random value
    function revealRandomA(uint256 _random) external {
        uint256 _commitment = uint256(keccak256(abi.encodePacked(_random)));

        require(proposedBet[_commitment].sideA == msg.sender, "Not a bet you placed or wrong value");
        require(proposedBet[_commitment].accepted, "Bet has not been accepted yet");

        proposedBet[_commitment].randomA = _random;
        proposedBet[_commitment].revealed = true;
        proposedBet[_commitment].revealedAt = block.timestamp;

        emit NumberRevealed(_commitment, msg.sender);
    }

    // Called by sideB to reveal their random value
    function revealRandomB(uint256 _commitment, uint256 _random) external {
        require(acceptedBet[_commitment].sideB == msg.sender, "Not a bet you accepted or wrong value");
        require(proposedBet[_commitment].revealed, "Player A has not revealed its number yet");

        uint256 _randomB = uint256(keccak256(abi.encodePacked(_random)));

        require(_randomB == acceptedBet[_commitment].randomB, "Wrong number");

        _completeBet(_commitment, _random);
    }

    function _completeBet(uint256 _commitment, uint256 revealedRandomB) private {
        address _sideA = proposedBet[_commitment].sideA;
        address _sideB = acceptedBet[_commitment].sideB;
        uint256 _agreedRandom = proposedBet[_commitment].randomA ^ revealedRandomB;

        address winner = _agreedRandom % 2 == 0 ? _sideA : _sideB;
        address loser = winner == _sideA ? _sideB : _sideA;

        _settleBet(_commitment, winner, loser);
    }

    function forfeit(uint256 _commitment) public onlyOwnBet(_commitment) {
        if (msg.sender == proposedBet[_commitment].sideA) {
            _forfeitA(_commitment);
            return;
        }

        _forfeitB(_commitment);
    }

    // Called by A to forfeit if B has not revealed his number yet
    function _forfeitA(uint256 _commitment) private {
        require(proposedBet[_commitment].accepted, "Can't forfeit a bet that has not been accepted yet");
        require(proposedBet[_commitment].revealed, "You can't forfeit a bet if you haven't reveald your number");
        require(
            proposedBet[_commitment].revealedAt + revealDeadline < block.timestamp,
            "Player B reveal deadline not reached yet"
        );

        address loser = acceptedBet[_commitment].sideB;

        _settleBet(_commitment, msg.sender, loser);
    }

    // Called by B to forfeit if A has not revealed his number yet
    function _forfeitB(uint256 _commitment) private {
        require(!proposedBet[_commitment].revealed, "You can't forfeit a bet if player A has reveald his number");
        require(
            block.timestamp > acceptedBet[_commitment].acceptedAt + revealDeadline,
            "Player A reveal deadline not reached yet"
        );

        address loser = proposedBet[_commitment].sideA;

        _settleBet(_commitment, msg.sender, loser);
    }

    function _settleBet(uint256 _commitment, address winner, address loser) private {
        uint256 _value = proposedBet[_commitment].value;

        payable(winner).transfer(2 * _value);
        emit BetSettled(_commitment, winner, loser, _value);

        // Cleanup
        delete proposedBet[_commitment];
        delete acceptedBet[_commitment];
    }
}
