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
        mapping (address => Voter) voter;
    }

    Vote newVote;

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

    //Voter mapping
    //mapping (address => Voter) private _voter;


    //Add new Voter
    function registerVoter (address _address) public onlyOwner{
        require(!newVote.voter[_address].isRegistered, "This voter is already registered !");
        newVote.voter[_address].isRegistered=true;
        emit VoterRegistered (_address);
    }

    //Remove Voter
    function removeVoter (address _address) public onlyOwner{
        require(newVote.voter[_address].isRegistered, "This voter is not registered !");
        delete newVote.voter[_address];
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





     

}