// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract MizzlTokenSale is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
   
    IERC20 public mizzlToken;  // Reference to the Mizzl token contract 
    IERC20 public usdt;  // Reference to the USDT token contract 
    address public collector; // Address that collects platform fees
    string public name; // Name of the contract
    string public symbol; // Symbol of the contract
   
    struct Slot {
        uint pricePerToken;  // Price per token in this slot (in wei)
        uint tokensAvailable; // Number of tokens available in this slot
        uint totalAmountGained; // Total amount of USDT gained in this slot
        address[] buyers; // List of buyers in this slot
        mapping(address => uint) buyerAmount; // Amount purchased by each buyer in this slot
    }

    Slot[] public slots; // Array to store all the slots
    uint public currentSlotIndex; // Index of the current active slot

    event SlotCreated(uint pricePerToken, uint tokensAvailable);
    event TokensPurchased(address indexed buyer, uint amount, uint totalCost);

    function initialize(address _owner, address USD, address mizzl) public initializer {
        __Ownable_init(_owner);  // Correctly initializing OwnableUpgradeable

        name = "MIZZL.io";
        symbol = "mizz";
        collector = payable(_owner);
        usdt = IERC20(USD);
        mizzlToken = IERC20(mizzl);
    }

    // Function to create a new slot by the owner
    function createSlot(uint pricePerToken, uint tokensAvailable) external onlyOwner {
       
        require(mizzlToken.balanceOf(address(this)) >= tokensAvailable, "Not enough tokens in the contract");

        slots.push();
        currentSlotIndex = slots.length - 1;
        Slot storage newSlot = slots[currentSlotIndex];
        newSlot.pricePerToken = pricePerToken;
        newSlot.tokensAvailable = tokensAvailable;

        emit SlotCreated(pricePerToken, tokensAvailable);
    }
    
    function calculatePrice(uint tokenAmount) public view returns (uint){
        Slot storage slot = slots[currentSlotIndex];
        uint totalprice = tokenAmount * slot.pricePerToken;

        return totalprice;  
    }
    // Function for users to purchase tokens from the current slot
    function purchaseTokens(uint tokenAmount) public{
        
        require(tokenAmount > 0, "Amount must be greater than 0");
        Slot storage slot = slots[currentSlotIndex];
        require(slot.tokensAvailable >= tokenAmount, "Not enough tokens available in this slot");
        
        uint totalCost = calculatePrice(tokenAmount);
        
        usdt.transferFrom(msg.sender, address(this), totalCost);

        slot.tokensAvailable -= tokenAmount;
        slot.totalAmountGained += totalCost;

        if (slot.buyerAmount[msg.sender] == 0) {
            slot.buyers.push(msg.sender);
        }
        slot.buyerAmount[msg.sender] += tokenAmount;

        mizzlToken.transfer(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, tokenAmount, totalCost);
    }
    
    // Function to check the USDT balance in the contract
     function getUSDTBalance() external view returns (uint256) {
         return usdt.balanceOf(address(this));
     }
     
     // Function to check the Mizzl token balance in the contract
     function getMizzlBalance() external view returns (uint256) {
         return mizzlToken.balanceOf(address(this));
     }
    // Function for the owner to withdraw USDT from the contract
    function withdrawUSD() external onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }

    // Get information about a specific slot
    function getSlotInfo(uint index) external view returns (uint pricePerToken, uint tokensAvailable, uint totalAmountGained) {
        Slot storage slot = slots[index];
        return (slot.pricePerToken, slot.tokensAvailable, slot.totalAmountGained);
    }

    // Get purchase information for a buyer in a specific slot
    function getBuyerInfo(uint index, address buyer) external view returns (uint amountPurchased) {
        Slot storage slot = slots[index];
        return slot.buyerAmount[buyer];
    }

    // Get the list of all buyers in a specific slot
    function getBuyersInSlot(uint index) external view returns (address[] memory) {
        return slots[index].buyers;
    }
}
