// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";


contract UserManager is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using Counters for Counters.Counter;

    struct User {
        uint id;
        bool status;
        address userAddress;
        uint time;
    }

    struct UserRewards {
        uint rewardId;
        address userAddress;
        uint marketItemId;
        uint purchasePrice;
        uint timeStart;
        uint timeEnd;
        uint claimTimesLeft;
        uint tokenRewardPerMonth;
    }

    event RewardCreated(address user, uint rewardId, uint marketItemId, uint purchasePrice, uint tokenRewardPerMonth);
    event RewardClaimed(address user, uint rewardId, uint amount);

    Counters.Counter private rewardIds;
    mapping(address => User) private _userDetail;
    mapping(address => uint[]) public getUserRewardsIds;
    mapping(uint => UserRewards) public getRewardDetails;
    mapping(address => uint[]) public _userNFTDetail;
 
    IERC20 public ecotoken;
    uint public ecoprice;
    address public MarketPlace;
    uint public RewardDurationMonths;
    
    function initialize(address _owner, address _ecotoken, address _MarketPlace) public initializer {
        __Ownable_init(_owner);
        ecotoken = IERC20(_ecotoken);
        ecoprice = 1;
        RewardDurationMonths = 12;
        MarketPlace = _MarketPlace;
    }
    modifier onlyMarketPlace() {
      require(msg.sender == MarketPlace, "Only MarketPlace can call this function");
      _;
    }
    
    function setMarketPlace(address _MarketPlace) public onlyOwner {
        MarketPlace = _MarketPlace;
    }

    function setPrice(uint256 _newPrice) public onlyOwner {
        ecoprice = _newPrice;
    }
    function setRewardDurationInMonths(uint _newDuration) public onlyOwner {
        RewardDurationMonths = _newDuration;
    }
    function getPrice() public view returns (uint) {
        return ecoprice;
    }

    function register(uint backId) external {
        _userDetail[msg.sender] = User(backId, true, msg.sender, block.timestamp);
    }

    function isregister(address user) public view returns (bool) {
        return _userDetail[user].status;
    }

    function addUserNFT(address user, uint tokenId) external onlyMarketPlace {
        require(isregister(user), "User not registered");
        _userNFTDetail[user].push(tokenId);
    }
     
     function fetchmyNft() public view returns (uint [] memory){ 
        return _userNFTDetail[msg.sender];
     }
   
    function createReward(address buyer, uint marketItemId, uint totalPrice)  external onlyMarketPlace returns (uint) {
        require(isregister(buyer), "User not registered");
        require(buyer != address(0), "Invalid buyer address");
        require(totalPrice > 0, "Total price must be greater than 0");
        require(ecoprice > 0, "ECO price not set");
    
        rewardIds.increment();
        uint newRewardId = rewardIds.current();
        getUserRewardsIds[buyer].push(newRewardId);
    
        uint monthlyReward = ((totalPrice * 10) / 100 / ecoprice) / 12; // 10% annual reward, divided by 12
        uint duration = RewardDurationMonths * 30 days; // Duration in seconds
    
        getRewardDetails[newRewardId] = UserRewards(
            newRewardId,
            buyer,
            marketItemId,
            totalPrice,
            block.timestamp,
            block.timestamp + duration,
            RewardDurationMonths, // Total claims match duration in months
            monthlyReward
        );
    
        emit RewardCreated(buyer, newRewardId, marketItemId, totalPrice, monthlyReward);
        return newRewardId;
    }
    
    function getUserRewards() public view returns (UserRewards[] memory) {
        uint[] memory userRewardIds = getUserRewardsIds[msg.sender];
        UserRewards[] memory rewards = new UserRewards[](userRewardIds.length);
        for (uint i = 0; i < userRewardIds.length; i++) {
            rewards[i] = getRewardDetails[userRewardIds[i]];
        }
        return rewards;
    }
  
    function claimReward(uint _rewardId, address _user) public nonReentrant {
      require(isregister(_user), "User not registered");
  
      uint[] storage rewards = getUserRewardsIds[_user];
      bool rewardExists = false;
      for (uint i = 0; i < rewards.length; i++)  if (rewards[i] == _rewardId) rewardExists = true;
      
      require(rewardExists, "RewardId not found");
  
      UserRewards storage reward = getRewardDetails[_rewardId];
      require(reward.claimTimesLeft > 0, "No more claims left");
  
      uint totalMonths = (reward.timeEnd - reward.timeStart) / 30 days; // Total months from duration
      uint elapsedMonths = (block.timestamp - reward.timeStart) / 30 days;
      uint claimableMonths = elapsedMonths - (totalMonths - reward.claimTimesLeft);
      require(claimableMonths > 0, "No new claims available");
  
      claimableMonths = claimableMonths > reward.claimTimesLeft ? reward.claimTimesLeft : claimableMonths;
      reward.claimTimesLeft -= claimableMonths;
  
      uint rewardAmount = claimableMonths * reward.tokenRewardPerMonth;
      require(ecotoken.transfer(_user, rewardAmount), "ECO transfer failed");
      
      emit RewardClaimed(_user, _rewardId, rewardAmount);
    }
}  