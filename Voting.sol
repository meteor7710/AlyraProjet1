//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

//Open Zepplin Ownable import
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Admin is Ownable{

    //List of workflow status
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    //Vote Structure 
    struct Vote{
        WorkflowStatus voteStatus;
        mapping (address => Voter) voters;
        Proposal[] proposals;
        uint winnerVoteCount;
        uint[] winnerProposals;
    }

    Vote newVote;
    uint voteSession = 1;

    //Voter Structure
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    //Proposal Structure
    struct Proposal {
        string description;
        uint voteCount;
    }

    //Voter registration event
    event VoterRegistered(address voterAddress);

    //Voter removal event
    event VoterRemoved(address voterAddress);

    //Workflow status change event
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

    //Proposal registration event
    event ProposalRegistered(uint proposalId);

    //Vote results event
    event VotesResults(uint[] winnerProposals,uint winnerVoteCount, uint voteSession);

    //Can add or remove voter
    modifier voterModificationAllowed(){
        require ( (newVote.voteStatus == WorkflowStatus.RegisteringVoters),"You can not add or remove voter at this step");
        _;
    }

    //Add new Voter
    function registerVoter (address _address) public voterModificationAllowed onlyOwner{
        require(!newVote.voters[_address].isRegistered, "This voter is already registered !");
        newVote.voters[_address].isRegistered=true;
        emit VoterRegistered (_address);
    }

    //Remove Voter
    function removeVoter (address _address) public voterModificationAllowed onlyOwner{
        require(newVote.voters[_address].isRegistered, "This voter is not registered !");
        delete newVote.voters[_address];
        emit VoterRemoved (_address);
    }

    //Get workflow status
    function getWorkflowStatus () public view returns (WorkflowStatus) {
        return newVote.voteStatus;
    }

    //Change vote status to next step
    function changeWorkflowStatus () public onlyOwner{
        require((newVote.voteStatus != WorkflowStatus.VotesTallied), "This vote is already finished !");
        WorkflowStatus previousStatus = newVote.voteStatus;
        newVote.voteStatus = WorkflowStatus(uint(newVote.voteStatus) + 1);
        emit WorkflowStatusChange (previousStatus, newVote.voteStatus);
    }

    //Validate voter
    modifier voterAllowed(){
        require ( newVote.voters[msg.sender].isRegistered,"You are not registered as voter");
        _;
    }

    // Allow proposal registration only in correct state
    modifier proposalAllowed()  {
        require ( newVote.voteStatus == WorkflowStatus.ProposalsRegistrationStarted,"Proposals registration is not started or already closed");
        _;
    }

    //Register a proposal
    function registerProposal (string memory _decription) public proposalAllowed voterAllowed{
        uint proposalId = newVote.proposals.length + 1;
        Proposal memory newProposal = Proposal (_decription,0);
        newVote.proposals.push(newProposal);
        emit ProposalRegistered(proposalId);

    }

    //Allow vote only in correct state
    modifier voteOpened()  {
        require ( newVote.voteStatus == WorkflowStatus.VotingSessionStarted,"Vote submission is not started or already closed");
        _;
    }

    //Validate voter has not already voted
    modifier canVote()  {
        require ( !newVote.voters[msg.sender].hasVoted ,"You have already voted");
        _;
    }

    //Validate voter has not already voted
    modifier hasVoted()  {
        require ( newVote.voters[msg.sender].hasVoted ,"You have not voted");
        _;
    }


   //Submit vote
    function submitVote (uint _proposalId) public voteOpened voterAllowed canVote{
        require ( _proposalId != 0 ,"Your proposal does not exist");
        require ( _proposalId <= (newVote.proposals.length + 1) ,"Your proposal does not exist");
        newVote.proposals[(_proposalId-1)].voteCount++;
        newVote.voters[msg.sender].hasVoted =  true;
        newVote.voters[msg.sender].votedProposalId =  _proposalId;
    }

    //Remove vote
    function removeVote() public voteOpened voterAllowed hasVoted{
        uint previousVote = newVote.voters[msg.sender].votedProposalId;
        newVote.proposals[(previousVote-1)].voteCount--;
        newVote.voters[msg.sender].hasVoted =  false;
        newVote.voters[msg.sender].votedProposalId = 0 ;
    }


    // Allow vote computation only in VotingSessionEnded state
    modifier voteClosed()  {
        require ( newVote.voteStatus == WorkflowStatus.VotingSessionEnded,"Vote are not closed or already released");
        _;
    }


    //Compute winning proposals
    function computeWinner() public voteClosed onlyOwner{
        uint i;
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


    //Allow vote computation only in VotingSessionEnded state
    modifier voteTallied()  {
        require ( newVote.voteStatus == WorkflowStatus.VotesTallied,"Vote are not tallied");
        _;
    }

    //returns winning proposals
    function getWinner() public view  voteTallied returns (uint[] memory winnerProposals_, uint winnerVoteCount_) {
        winnerProposals_= newVote.winnerProposals;
        winnerVoteCount_=newVote.winnerVoteCount;
    }

    //Start new vote or reset current vote
    function startNewVote() public  onlyOwner {
        delete newVote;
        voteSession++;
    }


}