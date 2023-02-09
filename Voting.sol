//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

//OpenZeppelin  import
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Voting is Ownable{

    //States variables definitions
    Vote[] voteHistory;
    uint8 voteSession;
    Vote currentVote;

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

    constructor (){
        //Set default value to status mapping
        status[0] = "RegisteringVoters";
        status[1] = "ProposalsRegistrationStarted";
        status[2] = "ProposalsRegistrationEnded";
        status[3] = "VotingSessionStarted";
        status[4] = "VotingSessionEnded";
        status[5] = "VotesTallied";

        //Set default Session number to 1
        voteSession = 1;
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
        require ( currentVote.voteStatus == WorkflowStatus(_status),string.concat("Vote status is: ", status[uint8(currentVote.voteStatus)], ", not: ", status[_status]));
        _;
    }


    //Add new Voter
    function registerVoter (address _address) external onlyOwner voteStatusValidation(0) {
        require(!voters[voteSession][_address].isRegistered, "This voter is already registered !");
        voters[voteSession][_address].isRegistered=true;
        emit VoterRegistered (_address);
    }

    //Remove Voter
    function removeVoter (address _address) external onlyOwner voteStatusValidation(0) {
        require(voters[voteSession][_address].isRegistered, "This voter is not registered !");
        delete voters[voteSession][_address];
        emit VoterRemoved (_address);
    }

    //Get workflow status
    function getWorkflowStatus () external view onlyOwner returns (string memory) {
        return status[uint(currentVote.voteStatus)];
    }

    //Get Vote Session status
    function getVoteSession () external view onlyOwner returns (uint) {
        return voteSession ;
    }

    //Change vote status to next step
    function changeWorkflowStatus () external onlyOwner{
        require((currentVote.voteStatus != WorkflowStatus.VotesTallied), "This vote is already finished !");
        WorkflowStatus previousStatus = currentVote.voteStatus;
        currentVote.voteStatus = WorkflowStatus(uint(currentVote.voteStatus) + 1);
        emit WorkflowStatusChange (previousStatus, currentVote.voteStatus);
    }

    //Register a proposal
    function registerProposal (string memory _decription) external voterAllowed voteStatusValidation(1) {
        uint proposalId = currentVote.proposals.length + 1;
        Proposal memory newProposal = Proposal (_decription,0);
        currentVote.proposals.push(newProposal);
        emit ProposalRegistered(proposalId);
    }

   //Submit vote
    function submitVote (uint8 _proposalId) external voterAllowed canVote voteStatusValidation(3)  {
        require ( _proposalId != 0 ,"Your proposal does not exist");
        require ( _proposalId <= (currentVote.proposals.length + 1) ,"Your proposal does not exist");
        currentVote.proposals[(_proposalId-1)].voteCount++;
        voters[voteSession][msg.sender].hasVoted =  true;
        voters[voteSession][msg.sender].votedProposalId =  _proposalId;
    }

    //Remove vote
    function removeVote() external voterAllowed hasVoted voteStatusValidation(3) {
        uint previousVote = voters[voteSession][msg.sender].votedProposalId;
        currentVote.proposals[(previousVote-1)].voteCount--;
        voters[voteSession][msg.sender].hasVoted =  false;
        voters[voteSession][msg.sender].votedProposalId = 0 ;
    }

    //Compute winning proposals
    function computeWinner() external onlyOwner voteStatusValidation(4) {
        uint8 i;
        for (i=0;i< currentVote.proposals.length;i++){
            if (currentVote.proposals[i].voteCount > currentVote.winnerVoteCount){
                currentVote.winnerVoteCount = currentVote.proposals[i].voteCount;
                if (currentVote.winnerProposals.length>0){
                    delete currentVote.winnerProposals;
                }
                currentVote.winnerProposals.push(i+1);
            }
            else if (currentVote.proposals[i].voteCount == currentVote.winnerVoteCount){
                currentVote.winnerProposals.push(i+1);
             }
        }
        emit VotesResults(currentVote.winnerProposals,currentVote.winnerVoteCount,voteSession);
    }

    //returns winning proposals
    function getWinner(uint8 _voteSession) external view returns (uint8[] memory winnerProposals_,uint winnerVoteCount_) {
        if (_voteSession == 0 || _voteSession == voteSession ) {  //if no vote is entered we use current session
            require ( currentVote.voteStatus == WorkflowStatus(5),string.concat("Vote status is: ", status[uint8(currentVote.voteStatus)], ", not: ", status[5]));
            winnerProposals_= currentVote.winnerProposals;
            winnerVoteCount_= currentVote.winnerVoteCount;
        }
        else{
            require ( _voteSession <= voteHistory.length ,"Your Vote Session does not exists");
            require ( voteHistory[_voteSession-1].voteStatus == WorkflowStatus(5),string.concat("Vote status is: ", status[uint8(voteHistory[_voteSession-1].voteStatus)], ", not: ", status[5]));
            winnerProposals_= voteHistory[_voteSession-1].winnerProposals;
            winnerVoteCount_= voteHistory[_voteSession-1].winnerVoteCount;
        }
    }

    //Start new vote or reset current vote
    function startnewVote() public  onlyOwner {
        voteHistory.push(currentVote);
        voteSession++;
        delete currentVote;
    }

    //Start new vote or reset current vote
    function getVoteFromAddr(uint8 _voteSession,address _voterAddr) external view  voterAllowed voteStatusValidation(5)  returns (uint8 proposalId_) {
        require ( voters[_voteSession][_voterAddr].isRegistered,"The address is not a voter");
        proposalId_= voters[_voteSession][_voterAddr].votedProposalId;
    }
}