// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts@4.7.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.0/utils/Counters.sol";
import "@openzeppelin/contracts@4.7.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.7.0/token/ERC721/extensions/ERC721URIStorage.sol";

contract SoulBoundTokenV3 is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint256 public totalNftMinted;
    uint256 public constant totalNftSupply = 5;
    uint256 private constant nftToBeMintInLockingPeriod = 3;
    uint256 private constant nftLockingPeriod = 1 minutes;

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
        
        uint256 tokenId = _tokenIdCounter.current();
        nftUser[_to][tokenId].tokenId = tokenId;
        nftUser[_to][tokenId].nftUserAddress = _to;
        nftUser[_to][tokenId].boughtTime = block.timestamp;
        totalNftMinted++;
        nftUser[_to][tokenId].lockingPeriod = totalNftMinted <= nftToBeMintInLockingPeriod ? block.timestamp + nftLockingPeriod: 0;

        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _uri);
        _tokenIdCounter.increment();
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only owner of the token can burn it");
        _burn(tokenId);
    }

    // Restrictions on transfer tokens to destination address
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) override internal {
        if (totalNftMinted <= nftToBeMintInLockingPeriod) {
            if (nftUser[from][tokenId].lockingPeriod >= block.timestamp || nftUser[to][tokenId].lockingPeriod >= block.timestamp) {
                require(from == address(0) || to == address(0), "Not allowed to transfer nft");
            }
        } 

        if (totalNftMinted > nftToBeMintInLockingPeriod && totalNftMinted <= totalNftSupply) {
            if (nftUser[from][tokenId].tokenId < nftToBeMintInLockingPeriod) {
                require(nftUser[from][tokenId].lockingPeriod <= block.timestamp, "Not allowed to transfer nft");
            }
        }
        
        nftUser[from][tokenId].isSold = true;
    }

    // Restrictions on approve tokens to destination address
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);

        require(to != owner, "ERC721: approval to current owner");
        require(
        _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);

        if (totalNftMinted <= nftToBeMintInLockingPeriod) {
            if (nftUser[owner][tokenId].lockingPeriod >= block.timestamp || nftUser[to][tokenId].lockingPeriod >= block.timestamp) {
                require(owner == address(0) || to == address(0), "Not allowed to approve nft");
            }
        } 

        if (totalNftMinted > nftToBeMintInLockingPeriod && totalNftMinted <= totalNftSupply) {
            if (nftUser[owner][tokenId].tokenId < nftToBeMintInLockingPeriod) {
                require(nftUser[owner][tokenId].lockingPeriod <= block.timestamp, "Not allowed to approve nft");
            }
        }
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() == address(0) || operator == address(0), "Not allowed to approve nfts");
        _setApprovalForAll(_msgSender(), operator, approved);
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
