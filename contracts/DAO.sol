// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

interface IMizzleMarket {
    function getUserMizzleStakings(uint userId) external view returns (uint);
}

contract DAO is OwnableUpgradeable, ReentrancyGuardUpgradeable{
    IMizzleMarket public mizzleMarket;
    uint public proposalThreshold;
    enum ProposalState { Pending, Active, Succeeded, Defeated, Cancelled, Executed, Rejected }

    struct Proposal {
        uint id;
        uint creatorId;
        string title;
        string description;
        uint voteCountFor;
        uint voteCountAgainst;
        uint weightageYes;
        uint weightageNo;
        ProposalState state;
        ProposalState AdminAction;
        uint startTime;
        uint endTime;
    }
    struct Voters{
        uint userId;
        bool vote;
    }
    uint public proposalId;
    mapping(uint => bool) public voters;
    mapping(uint => Proposal) public ProposalDetail;
    mapping(uint => Proposal) public QueuedProposals;
    mapping(uint => Voters[]) public getVoters;
    mapping(uint => Proposal[]) public userProposals;

    event ProposalCreated(uint proposalId, uint creatorId, string description, uint endTime);
    event Voted(uint proposalId, uint userId, bool vote);
    event ProposalRejected(uint proposalId);
    event ProposalExecuted(uint proposalId);
    event ProposalResult(uint proposalId, ProposalState);
    event ProposalCancelled(uint proposalId, uint creatorId);

    function initialize(address owner, address _mizzleMarketAddress, uint _proposalThreshold) public initializer {
        mizzleMarket = IMizzleMarket(_mizzleMarketAddress);
        __Ownable_init(owner);
        proposalThreshold = _proposalThreshold; 
        __ReentrancyGuard_init();
    }
    function updateMizzleMarket(address _mizzleMarket) external onlyOwner{
        mizzleMarket = IMizzleMarket(_mizzleMarket);
    }
    function updateThreshold(uint newAmount) public onlyOwner{
        proposalThreshold = newAmount;
    }

    function createProposal(uint _id, string memory title, string memory _description, uint userId, uint starttime, uint endtime) external nonReentrant{
        uint mizzleStaked = mizzleMarket.getUserMizzleStakings(userId);
        require(mizzleStaked >= proposalThreshold, "Insufficient Mizzle tokens staked");
        proposalId++;
        Proposal storage newProposal = ProposalDetail[proposalId];
        newProposal.id = _id;
        newProposal.id = proposalId;
        newProposal.creatorId = userId;
        newProposal.title = title;
        newProposal.description = _description;
        newProposal.state = ProposalState.Pending;
        newProposal.startTime = starttime;
        newProposal.endTime = endtime;

        userProposals[userId].push(newProposal);
        
        emit ProposalCreated(proposalId, userId, _description, newProposal.endTime);
    }

    function voteOnProposal(uint _proposalId, bool _vote, uint userId) external nonReentrant {
       uint mizzleStaked = mizzleMarket.getUserMizzleStakings(userId);
       require(mizzleStaked > 0, "Must stake mizzle tokens to vote");
       Proposal storage proposal = ProposalDetail[_proposalId];
   
       require(proposal.startTime <= block.timestamp && block.timestamp <= proposal.endTime, "Voting period is not started or has ended");
   
       // Check if the user has already voted
       Voters[] memory votersList = getVoters[_proposalId];
       for (uint i = 0; i < votersList.length; ++i) {
           require(votersList[i].userId != userId, "You have already voted on this proposal");
       }
   
       // Add the new voter to the voters array
       Voters memory newVoter = Voters({
           userId: userId,
           vote: _vote
       });
       getVoters[_proposalId].push(newVoter);
   
       // Update the vote counts and weightage based on the vote
       if (_vote) {
           proposal.voteCountFor++;
           proposal.weightageYes += mizzleStaked;
       } else {
           proposal.voteCountAgainst++;
           proposal.weightageNo += mizzleStaked;
       }
   
       proposal.state = ProposalState.Active;
   
       emit Voted(_proposalId, userId, _vote);
    }

    function getUpdatesOnProp(uint _proposalId) external view returns(Proposal memory) {
       Proposal memory proposal = ProposalDetail[_proposalId];
    
       // Check if the voting period has ended
        if (block.timestamp < proposal.startTime) {
              // Voting has not started yet, proposal is Pending
              proposal.state = ProposalState.Pending;
          } else if (proposal.startTime <= block.timestamp && block.timestamp <= proposal.endTime) {
              // Proposal is within the voting period, Active
              proposal.state = ProposalState.Active;
          } else if (block.timestamp > proposal.endTime && proposal.state != ProposalState.Executed && proposal.state != ProposalState.Rejected) {
              // Voting period has ended, determine if Succeeded or Defeated
              if (proposal.voteCountFor > proposal.voteCountAgainst) {
                  proposal.state = ProposalState.Succeeded;
              } else {
                  proposal.state = ProposalState.Defeated;
              }
        }

       return proposal;
    }

    function cancelProposal(uint _proposalId, uint userId) external {
        Proposal storage proposal = ProposalDetail[_proposalId];
        require(proposal.creatorId == userId, "Only the creator can cancel the proposal");
        require(proposal.state == ProposalState.Pending, "Proposal is not in Pending state");

        proposal.state = ProposalState.Cancelled;

        emit ProposalCancelled(_proposalId, proposal.creatorId);
    }

    function rejectProposal(uint _proposalId) external onlyOwner{

        Proposal storage proposal = ProposalDetail[_proposalId];
        proposal.AdminAction = ProposalState.Rejected;
        
        emit ProposalRejected(_proposalId);
    }
    
    function executeProposal(uint _proposalId) external onlyOwner{

        Proposal storage proposal = ProposalDetail[_proposalId];
        require(proposal.state == ProposalState.Succeeded, "Proposal not succeeded");

        //Logic for execution

        proposal.AdminAction = ProposalState.Executed;
        emit ProposalExecuted(_proposalId);
    }
    function getAllProposals(bool onlyActive) public view returns (Proposal[] memory) {
      Proposal[] memory allProposals = new Proposal[](proposalId);
      
        for (uint i = 1; i <= proposalId; i++) {
          Proposal memory proposal = ProposalDetail[i];
          
          // Handle different states of the proposal
          if (block.timestamp < proposal.startTime) {
              // Voting has not started yet, proposal is Pending
              proposal.state = ProposalState.Pending;
          } else if (proposal.startTime <= block.timestamp && block.timestamp <= proposal.endTime) {
              // Proposal is within the voting period, Active
              proposal.state = ProposalState.Active;
          } else if (block.timestamp > proposal.endTime && proposal.state != ProposalState.Executed && proposal.state != ProposalState.Rejected) {
              // Voting period has ended, determine if Succeeded or Defeated
              if (proposal.voteCountFor > proposal.voteCountAgainst) {
                  proposal.state = ProposalState.Succeeded;
              } else {
                  proposal.state = ProposalState.Defeated;
              }
          }
  
          // If `onlyActive` is true, return only active proposals
          if (onlyActive && proposal.state == ProposalState.Active) {
              allProposals[i - 1] = proposal;
          } else{
              allProposals[i - 1] = proposal;
          }
        }

      return allProposals;
    }
   function getSucceededProposals() external view returns (Proposal[] memory) {
    // First, get all proposals (including their updated states)
    Proposal[] memory allProposals = getAllProposals(false);
    
    uint count = 0;
    // Count how many proposals have succeeded
    for (uint i = 0; i < allProposals.length; i++) {
        if (allProposals[i].state == ProposalState.Succeeded) {
            count++;
        }
    }
    
    // Create an array of the correct size for succeeded proposals
    Proposal[] memory succeededProposals = new Proposal[](count);
    uint index = 0;
    
    // Populate the array with succeeded proposals
    for (uint i = 0; i < allProposals.length; i++) {
        if (allProposals[i].state == ProposalState.Succeeded) {
            succeededProposals[index] = allProposals[i];
            index++;
        }
    }
    
    return succeededProposals;
   }
    
    function getUserProposals(uint user_Id) external view returns (Proposal[] memory) {
    // First, get all proposals with updated states
       Proposal[] memory allProposals = getAllProposals(false);
       
       uint count = 0;
       // Count how many proposals belong to the user
       for (uint i = 0; i < allProposals.length; i++) {
           if (allProposals[i].creatorId == user_Id) {
               count++;
           }
       }
       
       // Create an array of the correct size for user's proposals
       Proposal[] memory userProposalsArray = new Proposal[](count);
       uint index = 0;
       
       // Populate the array with user's proposals
       for (uint i = 0; i < allProposals.length; i++) {
           if (allProposals[i].creatorId == user_Id) {
               userProposalsArray[index] = allProposals[i];
               index++;
           }
        }
       
       return userProposalsArray;
    }
    function getAllVoters(uint _proposalId) external view returns (Voters[] memory){

        return getVoters[_proposalId];
    }
}
