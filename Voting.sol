//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/*TODO:  add array to vote

*/

//Open Zepplin Ownable import
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Admin is Ownable{

    //States variables definitions
    Vote newVote;
    uint8 voteSession = 1;

    //Enumartions definitions
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //Mappings defnitions
    mapping(uint => mapping(address => Voter)) voters;
    mapping (uint => string) status;

    //Strutures definitions
    struct Vote{
        WorkflowStatus voteStatus;
        Proposal[] proposals;
        uint winnerVoteCount;
        uint8[] winnerProposals;
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint8 votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    //Events definitions
    event VoterRegistered(address voterAddress); //Voter registration event
    event VoterRemoved(address voterAddress); //Voter removal event
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus); //Workflow status change event
    event ProposalRegistered(uint proposalId); //Proposal registration event
    event VotesResults(uint8[] winnerProposals,uint winnerVoteCount, uint voteSession); //Vote results event

    //Modifier definitions
    modifier voterAllowed(){ //Validate voter is registered 
        require ( voters[voteSession][msg.sender].isRegistered,"You are not registered as voter");
        _;
    }

    modifier canVote()  { //Validate voter has not already voted
        require ( !voters[voteSession][msg.sender].hasVoted ,"You have already voted");
        _;
    }
       
    modifier hasVoted()  {  //Validate voter has not already voted
        require ( voters[voteSession][msg.sender].hasVoted ,"You have not voted");
        _;
    }

    modifier voteStatusValidation (uint8 _status) { //Validate the vote status is equal to a value (uint) of WorkflowStatus enum
        require ( newVote.voteStatus == WorkflowStatus(_status),string.concat("Vote status is: ", status[uint8(newVote.voteStatus)], ", not: ", status[_status]));
        _;
    }

    constructor (){
        //Set default value to status mapping
        status[0]="RegisteringVoters";
        status[1]="ProposalsRegistrationStarted";
        status[2]="ProposalsRegistrationEnded";
        status[3]="VotingSessionStarted";
        status[4]="VotingSessionEnded";
        status[5]="VotesTallied";
    }

    //Add new Voter
    //function registerVoter (address _address) public voterModificationAllowed onlyOwner{
    function registerVoter (address _address) external voteStatusValidation(0) onlyOwner{
        require(!voters[voteSession][_address].isRegistered, "This voter is already registered !");
        voters[voteSession][_address].isRegistered=true;
        emit VoterRegistered (_address);
    }

    //Remove Voter
    function removeVoter (address _address) external voteStatusValidation(0) onlyOwner{
        require(voters[voteSession][_address].isRegistered, "This voter is not registered !");
        delete voters[voteSession][_address];
        emit VoterRemoved (_address);
    }

    //Get workflow status
    function getWorkflowStatus () external view onlyOwner returns (string memory) {
        return status[uint(newVote.voteStatus)];
    }

    //Get Vote Session status
    function getVoteSession () external view onlyOwner returns (uint) {
        return voteSession ;
    }

    //Change vote status to next step
    function changeWorkflowStatus () external onlyOwner{
        require((newVote.voteStatus != WorkflowStatus.VotesTallied), "This vote is already finished !");
        WorkflowStatus previousStatus = newVote.voteStatus;
        newVote.voteStatus = WorkflowStatus(uint(newVote.voteStatus) + 1);
        emit WorkflowStatusChange (previousStatus, newVote.voteStatus);
    }

    //Register a proposal
    function registerProposal (string memory _decription) external voteStatusValidation(1) voterAllowed{
        uint proposalId = newVote.proposals.length + 1;
        Proposal memory newProposal = Proposal (_decription,0);
        newVote.proposals.push(newProposal);
        emit ProposalRegistered(proposalId);
    }

   //Submit vote
    function submitVote (uint8 _proposalId) external voteStatusValidation(3) voterAllowed canVote{
        require ( _proposalId != 0 ,"Your proposal does not exist");
        require ( _proposalId <= (newVote.proposals.length + 1) ,"Your proposal does not exist");
        newVote.proposals[(_proposalId-1)].voteCount++;
        voters[voteSession][msg.sender].hasVoted =  true;
        voters[voteSession][msg.sender].votedProposalId =  _proposalId;
    }

    //Remove vote
    function removeVote() external voteStatusValidation(3) voterAllowed hasVoted{
        uint previousVote = voters[voteSession][msg.sender].votedProposalId;
        newVote.proposals[(previousVote-1)].voteCount--;
        voters[voteSession][msg.sender].hasVoted =  false;
        voters[voteSession][msg.sender].votedProposalId = 0 ;
    }

    //Compute winning proposals
    function computeWinner() external voteStatusValidation(4) onlyOwner{
        uint8 i;
        for (i=0;i< newVote.proposals.length;i++){
            if (newVote.proposals[i].voteCount > newVote.winnerVoteCount){
                newVote.winnerVoteCount = newVote.proposals[i].voteCount;
                if (newVote.winnerProposals.length>0){
                    delete newVote.winnerProposals;
                }
                newVote.winnerProposals.push(i+1);
            }
            else if (newVote.proposals[i].voteCount == newVote.winnerVoteCount){
                newVote.winnerProposals.push(i+1);
             }
        }
        emit VotesResults(newVote.winnerProposals,newVote.winnerVoteCount,voteSession);
    }

    //returns winning proposals
    function getWinner() external view  voteStatusValidation(5) returns (uint8[] memory winnerProposals_,uint winnerVoteCount_) {
        winnerProposals_= newVote.winnerProposals;
        winnerVoteCount_= newVote.winnerVoteCount;
    }

    //Start new vote or reset current vote
    function startNewVote() public  onlyOwner {
        delete newVote;
        voteSession++;
    }

    //Start new vote or reset current vote
    function getVoteFromAddr(uint8 _voteSession,address _voterAddr) external view  voteStatusValidation(5) voterAllowed returns (uint8 proposalId_) {
        require ( voters[_voteSession][_voterAddr].isRegistered,"The address is not a voter");
        require ( voters[_voteSession][_voterAddr].hasVoted,"The address has not voted");
        proposalId_= voters[_voteSession][_voterAddr].votedProposalId;
    }
}