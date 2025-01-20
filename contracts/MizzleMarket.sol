// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract MizzleMarket is Initializable, OwnableUpgradeable, ERC1155Upgradeable, ReentrancyGuardUpgradeable {
    
    IERC20 public mizzleToken;
    IERC20 public usdt;
    uint public mizzlePrice;
    address public collector;
    address private keeper;
    address contractowner;
    struct User {
        uint id;
        uint mizzleStaked;
        address[] userAddresses;
        PurchasedNft[] nftOwned;
    }
    struct PurchasedNft{
        uint nftId;
        uint fractionId;
        uint price;
    }
    struct Nft {
        uint id;
        string nftName;
        uint price;
        uint TotalNftFractions;
        uint NftFractionsSold;
        string uri;
        Slot[3] slots;
    }

    struct MarketItem {
        uint nftId;
        string nftName;
        uint slotIndex;
        uint price;
        uint amount;
    }
    
    struct OrderDetail{
        uint nftId;
        uint price;
        uint amount;
        uint buyerId;
        uint mizzleStaked;
        uint stakeStartTime;
        uint stakeEndTime;
    }
    
   struct Slot {
        uint number;
        uint price;
        uint amountLeft;
        uint totalEarning;
        bool isSold;
    }
   
    uint public NftIds;
    uint public OrderId;
    uint public MarketItemIds;
    uint public feeToAddAddress;
    uint public slot1price;
    uint public slot2price;
    uint public slot3price;

    mapping(uint => Nft) public NftDetails;
    mapping(uint => User) private UserDetail;
    mapping(uint=> uint) public AlottedSponser;
    mapping(uint => MarketItem) public MarketItemDetails;
    mapping(uint => bool) public isSoldout;
    mapping(uint => bool) public isRegistered;
    mapping(uint => OrderDetail) public GetOrderDetail;
    mapping(uint => bytes32) private pass;

    event NftPurchased(uint nftId, uint fractionId, uint userId, uint OrderId);

    function initialize(address owner, address collect, IERC20 _usdt, IERC20 mizzle,address Keeper, uint _mizzlePrice) initializer public {
        __Ownable_init(owner);
        __ERC1155_init("");
        __ReentrancyGuard_init();
        contractowner = owner;
        collector = collect;
        mizzleToken = IERC20(mizzle);
        usdt = IERC20(_usdt);
        keeper = Keeper;
        mizzlePrice = _mizzlePrice;
    }
    
    function changeCollector(address col) external onlyOwner{
         collector = col;
    } 
    function changeKeeper(address keep) external onlyOwner{
         keeper = keep;
    } 
    function changeContractOwner(address own) external onlyOwner{
         contractowner = own;
    } 
    function change_MizzleToken(address token) external onlyOwner{
         mizzleToken = IERC20(token);
    }
    function change_UsdtToken(address token) external onlyOwner{
         usdt = IERC20(token);
    }
    function change_FeeToAddAddress(uint fee) external onlyOwner{
         feeToAddAddress = fee;
    }
    function change_MizzlePrice(uint price) external onlyOwner{
         mizzlePrice = price;
    }
    function change_SlotPrices(uint price1,uint price2, uint price3) public onlyOwner{
        slot1price = price1;
        slot2price = price2;
        slot3price = price3;
    }

    function register(uint id) external nonReentrant {

        User storage user = UserDetail[id];
        user.id = id;
        user.userAddresses.push(msg.sender);
        isRegistered[id] = true;
        generateKey(id);
    }
    function AddSponser(uint id) external{
        AlottedSponser[id] = id;
    }
    function addAddress(uint userId) external {
      require(isRegistered[userId], "You are not registered");
  
      User storage user = UserDetail[userId];
      // Check if the address already exists in the user's addresses
      for (uint i = 0; i < user.userAddresses.length; ++i) {
          require(user.userAddresses[i] != msg.sender, "Address already exists");
      }
      usdt.transferFrom(msg.sender, collector, feeToAddAddress);
      user.userAddresses.push(msg.sender);
    }

    function getUserMizzleStakings(uint userId) external view returns(uint){
        return UserDetail[userId].mizzleStaked;
    }
    
    function mint(string memory _nftName, string memory uri) external onlyOwner {
        NftIds++;
        uint newNftId = NftIds;
        
        // Create the NFT and allocate slots
        Nft storage nft = NftDetails[newNftId];
        nft.id = newNftId;
        nft.uri = uri;
        nft.nftName = _nftName;
        nft.TotalNftFractions = 1000;

        nft.slots[0] = Slot({number: 1, price: 100*slot1price, amountLeft: 350, totalEarning: 0, isSold: false});
        nft.slots[1] = Slot({number: 2, price: 100*slot2price, amountLeft: 350, totalEarning: 0, isSold: false});
        nft.slots[2] = Slot({number: 3, price: 100*slot3price, amountLeft: 300, totalEarning: 0, isSold: false});

        // Mint all 1000 NFT fractions to this contract
        _mint(contractowner, newNftId, nft.TotalNftFractions, "");

        // Place the first slot on the marketplace
        setApprovalForAll(address(this), true);

        placeNextSlotOnMarket(newNftId);
    }

    // Place the current active slot of the NFT on the marketplace
    function placeNextSlotOnMarket(uint nftId) internal {
        uint currentSlotIndex = getCurrentSlot(nftId);
        Nft storage nft = NftDetails[nftId];
        Slot memory currentSlot = nft.slots[currentSlotIndex];

        MarketItemIds++;
        uint newMarketItemId = MarketItemIds;
        // Place the slot on the marketplace
        MarketItem storage marketItem = MarketItemDetails[newMarketItemId];
        marketItem.nftId = nftId;
        marketItem.nftName = nft.nftName;
        marketItem.slotIndex = currentSlotIndex;
        marketItem.price = currentSlot.price;
        marketItem.amount = currentSlot.amountLeft;
    }
    function updateMarketItemPrice(uint _marketItemId, uint newPrice) external {
        MarketItem storage marketItem = MarketItemDetails[_marketItemId];
        marketItem.price = newPrice;
    }
        // Buy NFTs from the marketplace
    function buyMarketItem(uint userId, uint marketItemId, uint year, bytes32 key) external nonReentrant {
        require(key == pass[userId], "Invalid Key");
        
        MarketItem storage marketItem = MarketItemDetails[marketItemId];
        Nft storage nft = NftDetails[marketItem.nftId];
        require(marketItem.amount>=1, "Not enough NFTs available in this slot");

        // Calculate the total cost and transfer tokens
        uint totalPrice = marketItem.price;
        usdt.transferFrom(msg.sender, collector, totalPrice);

        // Transfer the NFTs to the buyer
        _safeTransferFrom(contractowner, msg.sender, marketItem.nftId, 1, "");
        nft.NftFractionsSold++;
        uint fractionId = marketItem.nftId*1000+nft.NftFractionsSold;

        UserDetail[userId].mizzleStaked += 8000;

        UserDetail[userId].nftOwned.push(PurchasedNft({
           nftId: marketItem.nftId,
           fractionId: fractionId,
           price: totalPrice
        }));
        // Update the slot data
        nft.slots[marketItem.slotIndex].amountLeft -= 1;
        MarketItemDetails[marketItemId].amount -= 1;
       
        OrderId++;

        GetOrderDetail[OrderId] = OrderDetail({
            nftId: nft.id,
            price: totalPrice,
            amount: 1,
            buyerId: userId,
            mizzleStaked: 8000,
            stakeStartTime:block.timestamp,
            stakeEndTime:block.timestamp+31536000*year
        });
        
        if (nft.slots[marketItem.slotIndex].amountLeft == 0) {
            placeNextSlotOnMarket(marketItem.nftId);
        }
        generateKey(userId);
        
        emit NftPurchased(marketItem.nftId, nft.NftFractionsSold, userId, OrderId);
    }
    
    function renewMizzleStakingPeriod(uint year, uint _orderId) public onlyOwner{
        OrderDetail storage order = GetOrderDetail[_orderId];
        order.stakeStartTime = block.timestamp;
        order.stakeEndTime = block.timestamp+31536000*year;
    }
    // Fetch all active market items for the frontend
    function getAllActiveMarketItems() external view returns (MarketItem[] memory) {
        uint activeCount = 0;
        for (uint i = 1; i <= MarketItemIds; i++) {
            if (MarketItemDetails[i].amount>=1) {
                activeCount++;
            }
        }

        MarketItem[] memory activeItems = new MarketItem[](activeCount);
        uint currentIndex = 0;
        for (uint i = 1; i <= MarketItemIds; i++) {
            if (MarketItemDetails[i].amount>=1) {
                activeItems[currentIndex] = MarketItemDetails[i];
                currentIndex++;
            }
        }

        return activeItems;
    }

    // Fetch the latest active slot for an NFT
    function getLatestSlotInfo(uint nftId) external view returns (Slot memory) {
        uint currentSlotIndex = getCurrentSlot(nftId);
        return NftDetails[nftId].slots[currentSlotIndex];
    }

    // Helper function to find the current active slot for an NFT
    function getCurrentSlot(uint nftId) internal view returns (uint) {
        Nft storage nft = NftDetails[nftId];
        for (uint i = 0; i < 3; i++) {
            if (nft.slots[i].amountLeft > 0) {
                return i;
            }
        }
        revert("All slots are sold out");
    }

     function getUser(uint id) external view returns (uint, address[] memory, uint, PurchasedNft[] memory) {
       User storage user = UserDetail[id];  // Fetch the user details from storage
       return (user.id, user.userAddresses, user.mizzleStaked, user.nftOwned);
    }

    function generateKey(uint user) private returns (bytes32){  

      bytes32 randomHash = keccak256(abi.encodePacked(block.timestamp, block.prevrandao, user));

      pass[user] = randomHash;
      return randomHash;     
    }

    function getCode(uint userId) public view returns(bytes32){
      require(msg.sender == keeper, "you are not authorized to call the function");
      require(isRegistered[userId], "User not registered");

      return pass[userId]; 
    }
}

