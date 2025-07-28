// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {EmployerStakingPool} from "./EmployerStakingPool.sol";

contract HiringRegistry is UUPSUpgradeable, Ownable {
    struct Skill {
        address issuedTo;
        string skillName;
        string level;
        string issuer;
        uint256 issuedAt;
    }

    struct Quote {
        uint256 amount;
        address employer;
        bool isApproved;
        bool isRejected;
        uint256 timestamp;
    }

    address[] graduates;
    mapping(address => bool) public isGraduate;
    mapping(address => Skill) skills;
    mapping(address => bool) isHired;
    mapping(address => Quote) hiringQuotes;
    mapping(address => address) public hiredBy;

    EmployerStakingPool public stakingPool;

    event GraduateAdded(address indexed graduate, string skillName, string level, string issuer);
    event HireQuoted(address indexed candidate, address indexed employer, uint256 quote);
    event QuoteApproved(address indexed candidate, address indexed employer, uint256 quote);
    event QuoteRejected(address indexed candidate, address indexed employer, uint256 quote);
    event CandidateHired(address indexed candidate, address indexed employer);

    constructor(address _stakingPool) Ownable(msg.sender) {
        stakingPool = EmployerStakingPool(_stakingPool);
    }

    function addGraduate(address graduate, string memory skillName, string memory level, string memory issuer)
        public
        onlyOwner
    {
        if (!isGraduate[graduate]) {
            graduates.push(graduate);
            isGraduate[graduate] = true;
        }

        skills[graduate] =
            Skill({issuedTo: graduate, skillName: skillName, level: level, issuer: issuer, issuedAt: block.timestamp});

        emit GraduateAdded(graduate, skillName, level, issuer);
    }

    function quoteHire(address candidate, uint256 quote) public {
        require(isGraduate[candidate], "Candidate is not a graduate");
        require(!isHired[candidate], "Candidate already Hired");
        require(stakingPool.isEmployerStaked(msg.sender), "Employer must stake before hiring");
        require(quote > 0, "Quote must be greater than 0");

        hiringQuotes[candidate] = Quote({
            amount: quote,
            employer: msg.sender,
            isApproved: false,
            isRejected: false,
            timestamp: block.timestamp
        });

        emit HireQuoted(candidate, msg.sender, quote);
    }

    function approveQuote() public {
        require(isGraduate[msg.sender], "Only graduates can approve quotes");
        require(!isHired[msg.sender], "Already hired");
        require(hiringQuotes[msg.sender].amount > 0, "No quote to approve");
        require(!hiringQuotes[msg.sender].isApproved, "Quote already approved");
        require(!hiringQuotes[msg.sender].isRejected, "Quote already rejected");

        hiringQuotes[msg.sender].isApproved = true;

        emit QuoteApproved(msg.sender, hiringQuotes[msg.sender].employer, hiringQuotes[msg.sender].amount);
    }

    function rejectQuote() public {
        require(isGraduate[msg.sender], "Only graduates can reject quotes");
        require(!isHired[msg.sender], "Already hired");
        require(hiringQuotes[msg.sender].amount > 0, "No quote to reject");
        require(!hiringQuotes[msg.sender].isApproved, "Quote already approved");
        require(!hiringQuotes[msg.sender].isRejected, "Quote already rejected");

        hiringQuotes[msg.sender].isRejected = true;

        emit QuoteRejected(msg.sender, hiringQuotes[msg.sender].employer, hiringQuotes[msg.sender].amount);
    }

    function hire(address candidate) public {
        require(isGraduate[candidate], "Candidate is not a graduate");
        require(!isHired[candidate], "Candidate already Hired");
        require(stakingPool.isEmployerStaked(msg.sender), "Employer must stake before hiring");
        require(hiringQuotes[candidate].amount > 0, "No quote provided for this candidate");
        require(hiringQuotes[candidate].employer == msg.sender, "Only quote provider can hire");
        require(hiringQuotes[candidate].isApproved, "Quote must be approved by candidate");
        require(!hiringQuotes[candidate].isRejected, "Quote was rejected by candidate");

        isHired[candidate] = true;
        hiredBy[candidate] = msg.sender;

        emit CandidateHired(candidate, msg.sender);
    }

    function getSkills(address candidate) external view returns (Skill memory) {
        return skills[candidate];
    }

    function isCandidateHired(address candidate) external view returns (bool) {
        return isHired[candidate];
    }

    function getHiringQuote(address candidate) external view returns (Quote memory) {
        return hiringQuotes[candidate];
    }

    function getHiredBy(address candidate) external view returns (address) {
        return hiredBy[candidate];
    }

    function getGraduates() external view returns (address[] memory) {
        return graduates;
    }

    function getGraduateCount() external view returns (uint256) {
        return graduates.length;
    }

    function isEmployerStaked(address employer) external view returns (bool) {
        return stakingPool.isEmployerStaked(employer);
    }

    function getEmployerStakedAmount(address employer) external view returns (uint256) {
        return stakingPool.getStakedAmount(employer);
    }

    function hasApprovedQuote(address candidate) external view returns (bool) {
        return hiringQuotes[candidate].isApproved;
    }

    function hasRejectedQuote(address candidate) external view returns (bool) {
        return hiringQuotes[candidate].isRejected;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}
