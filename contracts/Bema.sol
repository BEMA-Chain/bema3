/*
 _______   ________  __       __   ______          ______   __    __   ______   ______  __    __ 
|       \ |        \|  \     /  \ /      \        /      \ |  \  |  \ /      \ |      \|  \  |  \
| $$$$$$$\| $$$$$$$$| $$\   /  $$|  $$$$$$\      |  $$$$$$\| $$  | $$|  $$$$$$\ \$$$$$$| $$\ | $$
| $$__/ $$| $$__    | $$$\ /  $$$| $$__| $$      | $$   \$$| $$__| $$| $$__| $$  | $$  | $$$\| $$
| $$    $$| $$  \   | $$$$\  $$$$| $$    $$      | $$      | $$    $$| $$    $$  | $$  | $$$$\ $$
| $$$$$$$\| $$$$$   | $$\$$ $$ $$| $$$$$$$$      | $$   __ | $$$$$$$$| $$$$$$$$  | $$  | $$\$$ $$
| $$__/ $$| $$_____ | $$ \$$$| $$| $$  | $$      | $$__/  \| $$  | $$| $$  | $$ _| $$_ | $$ \$$$$
| $$    $$| $$     \| $$  \$ | $$| $$  | $$       \$$    $$| $$  | $$| $$  | $$|   $$ \| $$  \$$$
 \$$$$$$$  \$$$$$$$$ \$$      \$$ \$$   \$$        \$$$$$$  \$$   \$$ \$$   \$$ \$$$$$$ \$$   \$$
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC1155Base.sol";

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Counters.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/ERC1155.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155Receiver.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

contract Bema is ReentrancyGuard {
    ERC1155 private _nftContract;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    
     address public owner;
     
     constructor(address nftContractAddress) {
         _nftContract = ERC1155(nftContractAddress);
         owner = msg.sender;
     }
     
     struct MarketItem {
         uint itemId;
         address nftContract;
         uint256 tokenId;
         address payable seller;
         address payable owner;
         uint256 price;
         bool sold;
     }
     
     mapping(uint256 => MarketItem) private idToMarketItem;
     
     event MarketItemCreated (
        uint indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
     );
     
     event MarketItemSold (
         uint indexed itemId,
         address owner
         );
     
    
    
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
        ) public payable nonReentrant {
            require(price > 0, "Price must be greater than 0");
            
            _itemIds.increment();
            uint256 itemId = _itemIds.current();
  
            idToMarketItem[itemId] =  MarketItem(
                itemId,
                nftContract,
                tokenId,
                payable(msg.sender),
                payable(address(0)),
                price,
                false
            );
            
            _nftContract.safeTransferFrom(msg.sender, address(this), tokenId, 1, "");
            emit MarketItemCreated(
                itemId,
                nftContract,
                tokenId,
                msg.sender,
                address(0),
                price,
                false
            );
        }
        
      function searchMarketItems(string memory keyword) public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
        if (idToMarketItem[i + 1].owner == address(0)) {
            uint currentId = i + 1;
            MarketItem storage currentItem = idToMarketItem[currentId];
            if (contains(currentItem.tokenId, keyword) || contains(addressToString(currentItem.seller), keyword)) {
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
    }
    return items;
}

function contains(string memory haystack, string memory needle) private pure returns (bool) {
    bytes memory h = bytes(haystack);
    bytes memory n = bytes(needle);
    if (h.length < n.length) return false;
    for (uint i = 0; i <= h.length - n.length; i++) {
        bool found = true;
        for (uint j = 0; j < n.length; j++) {
            if (h[i + j] != n[j]) {
                found = false;
                break;
            }
        }
        if (found) return true;
    }
    return false;
}

function addressToString(address x) private pure returns (string memory) {
    bytes memory b = new bytes(20);
    for (uint i = 0; i < 20; i++)
        b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
    return string(b);
}
    
    function createMarketSale(
        //address nftContract,
        uint256 itemId
        ) public payable nonReentrant {
            uint price = idToMarketItem[itemId].price;
            uint tokenId = idToMarketItem[itemId].tokenId;
            bool sold = idToMarketItem[itemId].sold;
            require(msg.value == price, "Please submit the asking price in order to complete the purchase");
            require(sold != true, "This Sale has alredy finnished");
            emit MarketItemSold(
                itemId,
                msg.sender
                );

            idToMarketItem[itemId].seller.transfer(msg.value);
            _nftContract.safeTransferFrom(address(this), msg.sender, tokenId, 1, "");
            idToMarketItem[itemId].owner = payable(msg.sender);
            _itemsSold.increment();
            idToMarketItem[itemId].sold = true;
        }
        
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _itemIds.current();
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
