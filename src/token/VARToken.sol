// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title VARToken
 * @notice Variational protocol governance and utility token.
 *         - Fixed max supply
 *         - Mintable by authorized minters (airdrop distributor, treasury)
 *         - Burnable via buy-and-burn mechanism (≥30% of protocol revenue)
 *         - Governance via Snapshot off-chain + on-chain execution
 */
contract VARToken is ERC20, ERC20Burnable, Ownable, Pausable {

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18; // 1B VAR

    mapping(address => bool) public minters;

    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event BuyAndBurn(uint256 usdcSpent, uint256 varBurned);

    modifier onlyMinter() {
        require(minters[msg.sender], "VAR: not minter");
        _;
    }

    constructor(address _owner) ERC20("Variational", "VAR") Ownable(_owner) {}

    function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
        require(totalSupply() + amount <= MAX_SUPPLY, "VAR: max supply exceeded");
        _mint(to, amount);
    }

    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }
}
