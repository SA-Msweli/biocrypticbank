// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBioCrypticBankCrossChainToken} from "./IBioCrypticBankCrossChainToken.sol";

/**
 * @title BioCrypticBankCrossChainToken (CCT)
 * @dev ERC20 token designed for cross-chain transfers within the BioCrypticBank MVP.
 * This contract implements custom minter and burner roles, managed by the contract owner,
 * to control the minting and burning of tokens, facilitating a burn-and-mint mechanism
 * across different blockchain networks via Chainlink CCIP.
 */
contract BioCrypticBankCrossChainToken is IBioCrypticBankCrossChainToken, ERC20, Ownable {
    mapping(address => bool) private _minters;
    mapping(address => bool) private _burners;

    /**
     * @dev Emitted when an account is granted the minter role.
     * @param account The address of the account that was granted the minter role.
     */
    event MinterRoleGranted(address indexed account);
    /**
     * @dev Emitted when an account's minter role is revoked.
     * @param account The address of the account whose minter role was revoked.
     */
    event MinterRoleRevoked(address indexed account);
    /**
     * @dev Emitted when an account is granted the burner role.
     * @param account The address of the account that was granted the burner role.
     */
    event BurnerRoleGranted(address indexed account);
    /**
     * @dev Emitted when an account's burner role is revoked.
     * @param account The address of the account whose burner role was revoked.
     */
    event BurnerRoleRevoked(address indexed account);
    /**
     * @dev Emitted when tokens are minted.
     * @param to The address to which tokens were minted.
     * @param amount The amount of tokens minted.
     */
    event Minted(address indexed to, uint256 amount);
    /**
     * @dev Emitted when tokens are burned.
     * @param from The address from which tokens were burned.
     * @param amount The amount of tokens burned.
     */
    event Burned(address indexed from, uint256 amount);

    /**
     * @dev Constructor to initialize the ERC-20 token.
     * @param name_ The name of the token (e.g., "BioCrypticBank Cross-Chain Token").
     * @param symbol_ The symbol of the token (e.g., "BCC").
     */
    constructor(address owner_, string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(owner_) {}

    // ===== Modifiers =====
    /**
     * @dev Throws if called by any account other than a minter.
     */
    modifier onlyMinter() {
        require(_minters[msg.sender], "CCT: caller is not a minter");
        _;
    }

    /**
     * @dev Throws if called by any account other than a burner.
     */
    modifier onlyBurner() {
        require(_burners[msg.sender], "CCT: caller is not a burner");
        _;
    }

    // ===== Role Management =====
    /**
     * @dev Grants the Minter role to a specified account.
     * Only the contract owner can call this function.
     * @param account The address to grant the minter role.
     */
    function grantMinterRole(address account) external onlyOwner {
        require(account != address(0), "CCT: zero address");
        require(!_minters[account], "CCT: already a minter");
        _minters[account] = true;
        emit MinterRoleGranted(account);
    }

    /**
     * @dev Revokes the Minter role from a specified account.
     * Only the contract owner can call this function.
     * @param account The address to revoke the minter role from.
     */
    function revokeMinterRole(address account) external onlyOwner {
        require(_minters[account], "CCT: not a minter");
        _minters[account] = false;
        emit MinterRoleRevoked(account);
    }

    /**
     * @dev Returns true if the specified account has the Minter role.
     * @param account The address to check.
     * @return A boolean indicating if the account is a minter.
     */
    function isMinter(address account) external view returns (bool) {
        return _minters[account];
    }

    /**
     * @dev Grants the Burner role to a specified account.
     * Only the contract owner can call this function.
     * @param account The address to grant the burner role.
     */
    function grantBurnerRole(address account) external onlyOwner {
        require(account != address(0), "CCT: zero address");
        require(!_burners[account], "CCT: already a burner");
        _burners[account] = true;
        emit BurnerRoleGranted(account);
    }

    /**
     * @dev Revokes the Burner role from a specified account.
     * Only the contract owner can call this function.
     * @param account The address to revoke the burner role from.
     */
    function revokeBurnerRole(address account) external onlyOwner {
        require(_burners[account], "CCT: not a burner");
        _burners[account] = false;
        emit BurnerRoleRevoked(account);
    }

    /**
     * @dev Returns true if the specified account has the Burner role.
     * @param account The address to check.
     * @return A boolean indicating if the account is a burner.
     */
    function isBurner(address account) external view returns (bool) {
        return _burners[account];
    }

    // ===== Mint/Burn Operations =====
    /**
     * @dev Mints `amount` tokens to the `to` address.
     * Only accounts with the Minter role can call this function.
     * @param to The address to which the tokens will be minted.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "CCT: mint to zero address");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @dev Burns `amount` tokens from the `from` address.
     * Only accounts with the Burner role can call this function.
     * @param from The address from which the tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) external onlyBurner {
        require(from != address(0), "CCT: burn from zero address");
        _burn(from, amount);
        emit Burned(from, amount);
    }
}
