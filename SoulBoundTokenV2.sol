// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts@4.7.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.0/token/ERC721/extensions/ERC721URIStorage.sol";

contract SoulBoundTokenV2 is ERC721, ERC721URIStorage, Ownable {
    uint256 private tokenID;
    uint256 public totalNftMinted;
    uint256 public constant totalNftSupply = 5;
    uint256 private constant nftToBeMintInLockingPeriod = 3;
    uint256 private constant nftLockingPeriod = 300 seconds;

    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);

    struct NftUser {
        uint256 tokenId;
        address nftUserAddress;
        uint256 boughtTime;
        uint256 lockingPeriod;
        bool isSold;
    }

    mapping(address => mapping (uint256 => NftUser)) public nftUser;

    constructor() ERC721("SoulBound", "SBT") {}

    function safeMint(address _to, string memory _uri) external onlyOwner {
        require(totalNftMinted < totalNftSupply, "NFT reached its limit");
        tokenID ++;
        nftUser[_to][tokenID].tokenId = tokenID;
        nftUser[_to][tokenID].nftUserAddress = _to;
        nftUser[_to][tokenID].boughtTime = block.timestamp;
        totalNftMinted++;
        nftUser[_to][tokenID].lockingPeriod = totalNftMinted <= nftToBeMintInLockingPeriod ? block.timestamp + nftLockingPeriod: 0;
        _safeMint(_to, tokenID);
        _setTokenURI(tokenID, _uri);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only owner of the token can burn it");
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) override internal {
        if (totalNftMinted <= nftToBeMintInLockingPeriod) {
            if (nftUser[from][tokenId].lockingPeriod >= block.timestamp || nftUser[to][tokenId].lockingPeriod >= block.timestamp) {
                require(from == address(0) || to == address(0), "Not allowed to transfer nft");
            }
            nftUser[from][tokenId].isSold = true;
        } 

        if (totalNftMinted > nftToBeMintInLockingPeriod && totalNftMinted <= totalNftSupply) {
            if (nftUser[from][tokenId].tokenId <= nftToBeMintInLockingPeriod) {
                require(nftUser[from][tokenId].lockingPeriod <= block.timestamp, "Not allowed to transfer nft");
            }
            nftUser[from][tokenId].isSold = true;
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 tokenId) override internal {
        if (from == address(0)) {
            emit Attest(to, tokenId);
        } else if (to == address(0)) {
            emit Revoke(to, tokenId);
        }
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
