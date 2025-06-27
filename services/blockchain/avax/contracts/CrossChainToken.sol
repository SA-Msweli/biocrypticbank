// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CrossChainToken (CCT)
 * @dev ERC20 with mint/burn capabilities controlled by external cross-chain agents (e.g. CCIP Sender/Receiver).
 */
contract CrossChainToken is ERC20, Ownable {
    mapping(address => bool) private _minters;
    mapping(address => bool) private _burners;

    event MinterRoleGranted(address indexed account);
    event MinterRoleRevoked(address indexed account);
    event BurnerRoleGranted(address indexed account);
    event BurnerRoleRevoked(address indexed account);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    // ===== Modifiers =====
    modifier onlyMinter() {
        require(_minters[msg.sender], "CCT: caller is not a minter");
        _;
    }

    modifier onlyBurner() {
        require(_burners[msg.sender], "CCT: caller is not a burner");
        _;
    }

    // ===== Role Management =====
    function grantMinterRole(address account) external onlyOwner {
        require(account != address(0), "CCT: zero address");
        require(!_minters[account], "CCT: already a minter");
        _minters[account] = true;
        emit MinterRoleGranted(account);
    }

    function revokeMinterRole(address account) external onlyOwner {
        require(_minters[account], "CCT: not a minter");
        _minters[account] = false;
        emit MinterRoleRevoked(account);
    }

    function isMinter(address account) external view returns (bool) {
        return _minters[account];
    }

    function grantBurnerRole(address account) external onlyOwner {
        require(account != address(0), "CCT: zero address");
        require(!_burners[account], "CCT: already a burner");
        _burners[account] = true;
        emit BurnerRoleGranted(account);
    }

    function revokeBurnerRole(address account) external onlyOwner {
        require(_burners[account], "CCT: not a burner");
        _burners[account] = false;
        emit BurnerRoleRevoked(account);
    }

    function isBurner(address account) external view returns (bool) {
        return _burners[account];
    }

    // ===== Mint/Burn Operations =====
    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "CCT: mint to zero address");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(address from, uint256 amount) external onlyBurner {
        require(from != address(0), "CCT: burn from zero address");
        _burn(from, amount);
        emit Burned(from, amount);
    }
}
