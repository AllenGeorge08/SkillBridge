// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SkillCredential is ERC721, ERC721URIStorage, Ownable {
    uint256 public nextTokenId;

    // Mapping from tokenId to skill metadata (could be expanded or use tokenURI)
    struct Skill {
        address issuedTo;
        string skillName;
        string level;
        string issuer;
        uint256 issuedAt;
    }

    mapping(uint256 => Skill) public skills;

    event CredentialMinted(address indexed to, uint256 indexed tokenId, string skillName, string level, string issuer);

    constructor() ERC721("SkillBridgeCredential", "SKILL") Ownable(msg.sender) {}

    function mintCredential(
        address to,
        string memory skillName,
        string memory level,
        string memory issuer,
        string memory tokenURI
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        skills[tokenId] = Skill(to, skillName, level, issuer, block.timestamp);
        emit CredentialMinted(to, tokenId, skillName, level, issuer);
        return tokenId;
    }

    function burnCredential(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }

    function getSkill(uint256 tokenId) external view returns (Skill memory) {
        require(_ownerOf(tokenId) != address(0), "Credential does not exist");
        return skills[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // The following functions are overrides required by Solidity for multiple inheritance
    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
