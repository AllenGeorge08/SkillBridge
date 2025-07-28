// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SkillCredential} from "./SkillCredential.sol";
import {HiringRegistry} from "./HiringRegistry.sol";
import {EmployerStakingPool} from "./EmployerStakingPool.sol";
import {DonationPool} from "./DonationPool.sol";
import {ScholarshipPool} from "./ScholarshipPool.sol";
import {AIChatAssistant} from "./AIChatAssistant.sol";

contract SkillBridge is ERC721, Ownable {
    struct EcosystemStats {
        uint256 totalStudents;
        uint256 totalEmployers;
        uint256 totalDonations;
        uint256 totalScholarships;
        uint256 totalSkillsIssued;
        uint256 totalHires;
    }

    struct UserProfile {
        address userAddress;
        string name;
        string country;
        string educationLevel;
        bool isStudent;
        bool isEmployer;
        bool isDonor;
        uint256 reputationScore;
        uint256 joinedAt;
        string[] skills;
        string[] interests;
    }

    // Contract addresses
    SkillCredential public skillCredential;
    HiringRegistry public hiringRegistry;
    EmployerStakingPool public employerStakingPool;
    DonationPool public donationPool;
    ScholarshipPool public scholarshipPool;
    AIChatAssistant public aiChatAssistant;

    // User management
    mapping(address => UserProfile) public userProfiles;
    mapping(address => bool) public registeredUsers;
    mapping(string => address[]) public usersByCountry;
    mapping(string => address[]) public usersBySkill;

    // Ecosystem statistics
    EcosystemStats public ecosystemStats;
    uint256 public totalUsers;
    uint256 public reputationMultiplier = 1;

    // Events
    event UserRegistered(address indexed user, string name, string country);
    event SkillIssued(address indexed user, string skillName, string level);
    event JobMatch(address indexed student, address indexed employer, uint256 salary);
    event DonationReceived(address indexed donor, uint256 amount, string message);
    event ScholarshipAwarded(address indexed student, uint256 amount);
    event ReputationUpdated(address indexed user, uint256 newScore);

    constructor(
        address _skillCredential,
        address _hiringRegistry,
        address _employerStakingPool,
        address _donationPool,
        address _scholarshipPool,
        address _aiChatAssistant
    ) ERC721("SkillBridge", "SKILL") Ownable(msg.sender) {
        skillCredential = SkillCredential(_skillCredential);
        hiringRegistry = HiringRegistry(_hiringRegistry);
        employerStakingPool = EmployerStakingPool(_employerStakingPool);
        donationPool = DonationPool(_donationPool);
        scholarshipPool = ScholarshipPool(_scholarshipPool);
        aiChatAssistant = AIChatAssistant(_aiChatAssistant);
    }

    function registerUser(
        string memory name,
        string memory country,
        string memory educationLevel,
        bool isStudent,
        bool isEmployer,
        bool isDonor,
        string[] memory skills,
        string[] memory interests
    ) external {
        require(!registeredUsers[msg.sender], "User already registered");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(country).length > 0, "Country cannot be empty");

        UserProfile memory newProfile = UserProfile({
            userAddress: msg.sender,
            name: name,
            country: country,
            educationLevel: educationLevel,
            isStudent: isStudent,
            isEmployer: isEmployer,
            isDonor: isDonor,
            reputationScore: 0,
            joinedAt: block.timestamp,
            skills: skills,
            interests: interests
        });

        userProfiles[msg.sender] = newProfile;
        registeredUsers[msg.sender] = true;
        usersByCountry[country].push(msg.sender);
        
        for (uint i = 0; i < skills.length; i++) {
            usersBySkill[skills[i]].push(msg.sender);
        }

        totalUsers++;
        _updateEcosystemStats();

        emit UserRegistered(msg.sender, name, country);
    }

    function issueSkillCredential(
        address student,
        string memory skillName,
        string memory level,
        string memory issuer,
        string memory tokenURI
    ) external onlyOwner returns (uint256) {
        require(registeredUsers[student], "Student not registered");
        require(userProfiles[student].isStudent, "User is not a student");

        uint256 tokenId = skillCredential.mintCredential(student, skillName, level, issuer, tokenURI);
        
        // Update user profile
        userProfiles[student].skills.push(skillName);
        usersBySkill[skillName].push(student);
        
        // Update reputation
        _updateReputation(student, 10);
        
        ecosystemStats.totalSkillsIssued++;
        _updateEcosystemStats();

        emit SkillIssued(student, skillName, level);
        return tokenId;
    }

    function processJobMatch(
        address student,
        address employer,
        uint256 salary
    ) external {
        require(registeredUsers[student], "Student not registered");
        require(registeredUsers[employer], "Employer not registered");
        require(userProfiles[student].isStudent, "User is not a student");
        require(userProfiles[employer].isEmployer, "User is not an employer");

        // Update reputation for both parties
        _updateReputation(student, 20);
        _updateReputation(employer, 15);
        
        ecosystemStats.totalHires++;
        _updateEcosystemStats();

        emit JobMatch(student, employer, salary);
    }

    function processDonation(
        address donor,
        uint256 amount,
        string memory message
    ) external {
        require(registeredUsers[donor], "Donor not registered");
        require(userProfiles[donor].isDonor, "User is not a donor");

        _updateReputation(donor, 5);
        ecosystemStats.totalDonations++;
        _updateEcosystemStats();

        emit DonationReceived(donor, amount, message);
    }

    function awardScholarship(
        address student,
        uint256 amount
    ) external onlyOwner {
        require(registeredUsers[student], "Student not registered");
        require(userProfiles[student].isStudent, "User is not a student");

        _updateReputation(student, 25);
        ecosystemStats.totalScholarships++;
        _updateEcosystemStats();

        emit ScholarshipAwarded(student, amount);
    }

    function getUserProfile(address user) external view returns (UserProfile memory) {
        return userProfiles[user];
    }

    function getUsersByCountry(string memory country) external view returns (address[] memory) {
        return usersByCountry[country];
    }

    function getUsersBySkill(string memory skill) external view returns (address[] memory) {
        return usersBySkill[skill];
    }

    function getEcosystemStats() external view returns (EcosystemStats memory) {
        return ecosystemStats;
    }

    function updateReputationMultiplier(uint256 newMultiplier) external onlyOwner {
        reputationMultiplier = newMultiplier;
    }

    function _updateReputation(address user, uint256 points) internal {
        userProfiles[user].reputationScore += points * reputationMultiplier;
        emit ReputationUpdated(user, userProfiles[user].reputationScore);
    }

    function _updateEcosystemStats() internal {
        ecosystemStats.totalStudents = _countUsersByType(true, false, false);
        ecosystemStats.totalEmployers = _countUsersByType(false, true, false);
        ecosystemStats.totalDonations = donationPool.nativeDonations();
    }

    function _countUsersByType(bool isStudent, bool isEmployer, bool isDonor) internal view returns (uint256) {
        uint256 count = 0;
        // This would need to be implemented with a more complex data structure
        // For now, returning a placeholder
        return count;
    }

    // Integration functions
    function connectToHiringRegistry() external view returns (address) {
        return address(hiringRegistry);
    }

    function connectToScholarshipPool() external view returns (address) {
        return address(scholarshipPool);
    }

    function connectToDonationPool() external view returns (address) {
        return address(donationPool);
    }

    function connectToAIChat() external view returns (address) {
        return address(aiChatAssistant);
    }

    function connectToEmployerStaking() external view returns (address) {
        return address(employerStakingPool);
    }

    function connectToSkillCredential() external view returns (address) {
        return address(skillCredential);
    }
}
