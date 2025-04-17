// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

library Counters {
    struct Counter {
        uint256 _value;
    }
    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}
interface IUserManager {
    function isregister(address user) external view returns (bool);
    function getPrice() external view returns (uint);
    function createReward( address buyer, uint marketItemId, uint totalPrice) external returns (uint);
    function addUserNFT(address user, uint tokenId) external;
}

contract MarketPlace is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, ERC1155Holder {
    using Counters for Counters.Counter;

    Counters.Counter private itemIds;
    Counters.Counter private tokenIds;
     function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC1155Upgradeable, ERC1155Holder) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
    IERC20 public usdt;
    IERC20 public ecotoken;
    address payable public collector;
    uint public platformFees;
    string public name;
    string public symbol;
    IUserManager public userManager;

    struct MarketItem {
        uint itemId;
        uint256 tokenId;
        uint units;
        uint units_left;
        address payable seller;
        uint256 totalPrice;
        uint PricePerUnit;
        uint currentItemPrice;
        uint time;
    }

    struct NFTDetail {
        uint tokenId;
        string uri;
        uint maxSupply;
        uint initialPrice;
        uint mintTime;
        uint currentSupply;
    }

    mapping(uint => string) public _tokenURI;
    mapping(uint => uint) public _currentSupply;
    mapping(uint => MarketItem) public idToMarketItem;
    mapping(uint => NFTDetail) public idToNftDetail;

    event MarketItemCreated(
        uint indexed itemId,
        uint256 tokenId,
        uint units,
        uint units_left,
        address seller,
        uint256 totalPrice,
        uint PricePerUnit,
        uint currentItemPrice,
        uint time
    );

    event TokenMinted(
        address indexed to,
        uint tokenId,
        uint amount,
        string uri,
        uint initialPrice
    );

    event TokenBurned(
        uint tokenId,
        uint amount,
        address from
    );

    function initialize(
        address _owner,
        uint _platformFees,
        address _usdt,
        address _ecotoken,
        address _userManager
    ) public initializer {
        __ERC1155_init("");
        __Ownable_init(_owner);
        __ReentrancyGuard_init();

        name = "EcoTraderMarket.io";
        symbol = "ECO";
        collector = payable(_owner);
        platformFees = _platformFees;
        usdt = IERC20(_usdt);
        ecotoken = IERC20(_ecotoken);
        userManager = IUserManager(_userManager);
        setApprovalForAll(address(this), true);
    }

    function updatePlatformFees(uint newPlatformFees) public onlyOwner {
        platformFees = newPlatformFees;
    }

    function getPlatformFees() public view returns (uint256) {
        return platformFees;
    }

    function updateCollector(address newCollector) public onlyOwner {
        collector = payable(newCollector);
    }

    function getCollector() public view returns (address) {
        return collector;
    }
    
    function updateUserManager(address _userManager) public onlyOwner {
        userManager = IUserManager(_userManager);
    }
    
    function mint(
        uint id,
        address to,
        uint amount,
        string memory tokenURI,
        uint initialPrice
    ) external onlyOwner {
        require(to != address(0), "Invalid address");
        require(!_isContract(msg.sender), "Not a wallet");

        tokenIds.increment();        
        _mint(to, id, amount, "");
        _setURI(id, tokenURI);
        _currentSupply[id] = amount;
        
        idToNftDetail[id] = NFTDetail(
            id,
            tokenURI,
            amount,
            initialPrice,
            block.timestamp,
            amount
        );

        emit TokenMinted(to, id, amount, tokenURI, initialPrice);
    }
    
function bridge_mint(
    uint id,
    address to,
    uint amount,
    string memory tokenURI,
    uint initialPrice
) external onlyOwner {
    require(to != address(0), "Invalid address");
    require(!_isContract(msg.sender), "Not a wallet");

    if (_currentSupply[id] > 0) {
        // Token ID already exists, update supply
        _currentSupply[id] += amount;
        idToNftDetail[id].currentSupply += amount;
        idToNftDetail[id].maxSupply += amount;
        idToNftDetail[id].uri = tokenURI;
        idToNftDetail[id].initialPrice = initialPrice;
        _mint(to, id, amount, "");
    } else {
        // New token ID, mint it
        tokenIds.increment();
        _mint(to, id, amount, "");
        _setURI(id, tokenURI);
        _currentSupply[id] = amount;

        idToNftDetail[id] = NFTDetail(
            id,
            tokenURI,
            amount,
            initialPrice,
            block.timestamp,
            amount
        );
    }

    emit TokenMinted(to, id, amount, tokenURI, initialPrice);
}
    function burn(
        uint tokenId,
        uint amount,
        address from
    ) public onlyOwner {
        require(balanceOf(from, tokenId) >= amount, "Insufficient balance");
        require(_currentSupply[tokenId] >= amount, "Insufficient supply");

        _burn(from, tokenId, amount);
        _currentSupply[tokenId] -= amount;
        idToNftDetail[tokenId].currentSupply -= amount;

        emit TokenBurned(tokenId, amount, from);
    }

    function onlyOwnerCreateItem(uint _tokenId, uint _PricePerUnit, uint numberOfUnits) public onlyOwner {
        require(balanceOf(msg.sender, _tokenId) >= numberOfUnits, "Insufficient balance");
        require(!_isContract(msg.sender), "Not a wallet");

        itemIds.increment();
        uint newItemId = itemIds.current();
        uint totalAmount = numberOfUnits * _PricePerUnit;
        
        idToMarketItem[newItemId] = MarketItem(
            newItemId,
            _tokenId,
            numberOfUnits,
            numberOfUnits,
            payable(msg.sender),
            totalAmount,
            _PricePerUnit,
            totalAmount,
            block.timestamp
        );

        _safeTransferFrom(msg.sender, address(this), _tokenId, numberOfUnits, "");
        
        emit MarketItemCreated(
            newItemId,
            _tokenId,
            numberOfUnits,
            numberOfUnits,
            msg.sender,
            totalAmount,
            _PricePerUnit,
            totalAmount,
            block.timestamp
        );
    }

    function resellCreateItem(uint _tokenId, uint _PricePerUnit, uint numberOfUnits) public nonReentrant{
        require(userManager.isregister(msg.sender), "User not registered");
        require(balanceOf(msg.sender, _tokenId) >= numberOfUnits, "Insufficient balance");

        itemIds.increment();
        uint newItemId = itemIds.current();
        uint totalAmount = numberOfUnits * _PricePerUnit;

        // Transfer resell fee
        usdt.transferFrom(msg.sender, collector, 2000000000000000000);
        
        idToMarketItem[newItemId] = MarketItem(
            newItemId,
            _tokenId,
            numberOfUnits,
            numberOfUnits,
            payable(msg.sender),
            totalAmount,
            _PricePerUnit,
            totalAmount,
            block.timestamp
        );

        _safeTransferFrom(msg.sender, address(this), _tokenId, numberOfUnits, "");
        
        emit MarketItemCreated(
            newItemId,
            _tokenId,
            numberOfUnits,
            numberOfUnits,
            msg.sender,
            totalAmount,
            _PricePerUnit,
            totalAmount,
            block.timestamp
        );
    }

    function updateItemPrice(uint _itemId, uint _newPricePerUnit) public {
        MarketItem storage item = idToMarketItem[_itemId];
        require(item.seller == msg.sender, "Only seller can update price");
        require(item.units_left > 0, "Item sold out");

        item.PricePerUnit = _newPricePerUnit;
        item.currentItemPrice = item.units_left * _newPricePerUnit;
    }

    function deleteMarketItem(uint _itemId) public {
        MarketItem storage item = idToMarketItem[_itemId];
        require(item.seller == msg.sender, "Only seller can delete item");
        require(item.units_left > 0, "Cannot delete sold out item");

        _safeTransferFrom(address(this), msg.sender, item.tokenId, item.units_left, "");
        delete idToMarketItem[_itemId];
    }

    function saleItem(uint newItemId, uint numberOfUnits) public nonReentrant {
        require(!_isContract(msg.sender), "Not a wallet");
        require(userManager.isregister(msg.sender), "User not registered");

        MarketItem storage item = idToMarketItem[newItemId];
        require(numberOfUnits <= item.units_left, "Insufficient units available");
        
        (uint totalCostUSDT, uint totalCostERC, uint feeUSDT, uint feeERC) = calculateSalePrice(newItemId, numberOfUnits);

        // Transfer payments
        usdt.transferFrom(msg.sender, item.seller, totalCostUSDT);
        usdt.transferFrom(msg.sender, collector, feeUSDT);
        ecotoken.transferFrom(msg.sender, item.seller, totalCostERC);
        ecotoken.transferFrom(msg.sender, collector, feeERC);

        // Update market item
        uint totalPrice = item.PricePerUnit * numberOfUnits;
        item.units_left -= numberOfUnits;
        item.currentItemPrice -= totalPrice;

        // Create reward and transfer NFT
        userManager.createReward(msg.sender, newItemId, totalPrice);
        userManager.addUserNFT(msg.sender, item.tokenId);
        _safeTransferFrom(address(this), msg.sender, item.tokenId, numberOfUnits, "");
    }

    function calculateSalePrice(uint newItemId, uint numberOfUnits) public view returns (
        uint totalCostUSDT, 
        uint totalCostERC, 
        uint feeUSDT, 
        uint feeERC
    ) {
        MarketItem memory item = idToMarketItem[newItemId];
        uint totalPrice = item.PricePerUnit * numberOfUnits;

        totalCostUSDT = (totalPrice * 75) / 100;
        totalCostERC = ((totalPrice * 25) / 100) * userManager.getPrice();

        uint fee = feeForSale(newItemId, numberOfUnits);
        feeUSDT = (fee * 75) / 100;
        feeERC = ((fee * 25) / 100) * userManager.getPrice();

        return (totalCostUSDT, totalCostERC, feeUSDT, feeERC);
    }

    function feeForSale(uint newItemId, uint numberOfUnits) public view returns (uint) {
        uint leftUnits = idToMarketItem[newItemId].units_left;
        require(numberOfUnits <= leftUnits, "Insufficient units available");
        uint priceOfSale = idToMarketItem[newItemId].PricePerUnit * numberOfUnits;
        
        return (priceOfSale * platformFees) / 10000;
    }
    
    function getAllMarketItems() public view returns (MarketItem[] memory) {
       uint count = itemIds.current();  
       MarketItem[] memory items = new MarketItem[](count); 
   
       for (uint i = 0; i < count; i++) {  
           items[i] = idToMarketItem[i + 1]; 
       }
   
       return items;
    }

    function isItemSoldOut(uint itemId) public view returns (bool) {
        return idToMarketItem[itemId].units_left == 0;
    }

    function _isContract(address addr) private view returns (bool) {
        return addr.code.length > 0;
    }

    function _setURI(uint tokenId, string memory urii) internal {
        _tokenURI[tokenId] = urii;
        emit URI(urii, tokenId);
    }

    function uri(uint tokenId) public view override returns (string memory) {
        return _tokenURI[tokenId];
    }
}