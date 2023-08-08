// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IScorer.sol";

contract Solaxy is ERC20 {
    uint80 public constant MAX_SUPPLY = 100_000 * 10 ** 18;
    uint72 public constant ALLOWANCE = 50 * 10 ** 18;
    uint16 public constant PASSING_SCORE = 21_00;
    uint32 public immutable GENESIS_BLOCK;
    uint16 public blockInterval = 0;
    // all above var packed into 1 storage slot;

    uint256 public lastBlock;
    GitcoinScorer public constant SCORER = GitcoinScorer(address(0));
    mapping(address => bool) Minted;

    error SupplyMaxedOut();
    error AllowanceClaimed();
    error InCooldown();
    error LowPassportScore();
    error Unqualified();

    constructor() ERC20("Solaxy", "SLX") {
        GENESIS_BLOCK = uint32(block.number);
        lastBlock = block.number;
    }

    function canMint(address account) public view returns (bool) {
        if (totalSupply() >= MAX_SUPPLY) revert SupplyMaxedOut();
        if (Minted[account]) revert AllowanceClaimed();
        if (block.number < lastBlock + blockInterval) revert InCooldown();
        uint256 cutoff = PASSING_SCORE;
        cutoff = totalSupply() >= MAX_SUPPLY / 2 ? cutoff + 2_00 : cutoff;
        cutoff = block.number >= GENESIS_BLOCK + 6_307_200
            ? cutoff + 2_00
            : cutoff;

        if (SCORER.scorePassport(account) < cutoff) revert LowPassportScore();
        return true;
    }

    function updateStates() internal {
        blockInterval += 7;
        Minted[msg.sender] = true;
        lastBlock = block.number;
    }

    function mint() public {
        if (!canMint(msg.sender)) revert Unqualified();
        _mint(msg.sender, ALLOWANCE);
        updateStates();
    }
}
