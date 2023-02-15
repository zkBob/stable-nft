// SPDX-License-Identifier: BSL-1.1
pragma solidity 0.8.15;

import "@zkbob/proxy/EIP1967Admin.sol";
import "./token/ERC721/ERC721Enumerable.sol";
import "./interfaces/IVaultRegistry.sol";

contract VaultRegistry is IVaultRegistry, EIP1967Admin, ERC721Enumerable {
    /// @notice Thrown when not minter trying to mint
    error Forbidden();

    /// @notice CDP Vault contracts allowed to mint
    mapping(address => bool) public isMinter;

    /// @notice Vault NFT minter
    mapping(uint256 => address) public minterOf;

    /// @notice Current free tokenId of NFT
    uint256 public idCounter;

    /// @notice Creates a new contract
    /// @param name_ Token name
    /// @param symbol_ Token's symbol name
    /// @param baseURI_ Token's baseURI
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_, baseURI_) {}

    /// @notice Enables/disables new Vault Registry NFT minter
    /// @param minter address of the modified minter
    /// @param approved true, to enable minter, false otherwise
    function setMinter(address minter, bool approved) external onlyAdmin {
        isMinter[minter] = approved;
    }

    /// @inheritdoc IVaultRegistry
    function isAuthorized(uint256 tokenId, address user) external view returns (bool) {
        return _isApprovedOrOwner(user, tokenId);
    }

    /// @inheritdoc IVaultRegistry
    function mint(address to) external returns (uint256 tokenId) {
        if (!isMinter[msg.sender]) {
            revert Forbidden();
        }

        tokenId = idCounter + 1;
        minterOf[tokenId] = msg.sender;

        idCounter = tokenId;
        _mint(to, tokenId);
    }

    /// @inheritdoc IVaultRegistry
    function burn(uint256 tokenId) external {
        if (msg.sender != minterOf[tokenId]) {
            revert Forbidden();
        }

        delete minterOf[tokenId];

        _burn(tokenId);
    }
}
