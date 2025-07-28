// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DonationPool is Ownable, UUPSUpgradeable, ReentrancyGuard {
    struct Donation {
        address donor;
        uint256 amount;
        uint256 timestamp;
        string message;
        bool isRecurring;
        uint256 frequency; // 0 = one-time, 1 = monthly, 2 = quarterly, 3 = yearly
    }

    struct ImpactMetric {
        uint256 studentsFunded;
        uint256 totalEducationHours;
        uint256 scholarshipsAwarded;
        uint256 countriesReached;
        string[] supportedCountries;
    }

    struct Campaign {
        string name;
        string description;
        uint256 targetAmount;
        uint256 currentAmount;
        uint256 deadline;
        bool isActive;
        string category; // "education", "infrastructure", "technology", "emergency"
    }

    mapping(address => uint256) tokenDonations;
    mapping(address => Donation[]) public donorHistory;
    mapping(address => bool) public verifiedDonors;
    mapping(string => Campaign) public campaigns;
    mapping(address => uint256) public donorImpactScore;

    uint256 public nativeDonations;
    uint256 public totalDonors;
    uint256 public platformFee = 1; // 1% platform fee
    uint256 public minDonationAmount = 0.001 ether;
    
    ImpactMetric public impactMetrics;
    string[] public campaignCategories;

    event DonationMade(address indexed donor, uint256 amount, string message);
    event CampaignCreated(string indexed name, uint256 targetAmount, uint256 deadline);
    event CampaignFunded(string indexed name, uint256 amount);
    event DonorVerified(address indexed donor);
    event ImpactUpdated(uint256 studentsFunded, uint256 totalEducationHours);

    constructor() Ownable(msg.sender) {
        _initializeDefaultCampaigns();
    }

    function donate(address token, uint256 amount, string memory message) external nonReentrant {
        require(amount >= minDonationAmount, "Donation too small");
        require(bytes(message).length <= 200, "Message too long");
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        uint256 platformFeeAmount = (amount * platformFee) / 100;
        uint256 actualDonation = amount - platformFeeAmount;
        
        tokenDonations[token] += actualDonation;
        
        _recordDonation(msg.sender, amount, message, false, 0);
        _updateDonorStats(msg.sender);
        
        emit DonationMade(msg.sender, amount, message);
    }

    function donateNativeEth(string memory message) external payable nonReentrant {
        require(msg.value >= minDonationAmount, "Donation too small");
        require(bytes(message).length <= 200, "Message too long");
        
        uint256 platformFeeAmount = (msg.value * platformFee) / 100;
        uint256 actualDonation = msg.value - platformFeeAmount;
        
        nativeDonations += actualDonation;
        
        _recordDonation(msg.sender, msg.value, message, false, 0);
        _updateDonorStats(msg.sender);
        
        emit DonationMade(msg.sender, msg.value, message);
    }

    function setupRecurringDonation(
        address token,
        uint256 amount,
        uint256 frequency,
        string memory message
    ) external {
        require(amount >= minDonationAmount, "Donation too small");
        require(frequency <= 3, "Invalid frequency");
        require(bytes(message).length <= 200, "Message too long");
        
        _recordDonation(msg.sender, amount, message, true, frequency);
        _updateDonorStats(msg.sender);
        
        emit DonationMade(msg.sender, amount, message);
    }

    function createCampaign(
        string memory name,
        string memory description,
        uint256 targetAmount,
        uint256 durationInDays,
        string memory category
    ) external onlyOwner {
        require(bytes(name).length > 0, "Campaign name cannot be empty");
        require(targetAmount > 0, "Target amount must be greater than 0");
        require(durationInDays > 0, "Duration must be greater than 0");
        
        campaigns[name] = Campaign({
            name: name,
            description: description,
            targetAmount: targetAmount,
            currentAmount: 0,
            deadline: block.timestamp + (durationInDays * 1 days),
            isActive: true,
            category: category
        });
        
        campaignCategories.push(category);
        
        emit CampaignCreated(name, targetAmount, block.timestamp + (durationInDays * 1 days));
    }

    function fundCampaign(string memory campaignName, uint256 amount) external nonReentrant {
        Campaign storage campaign = campaigns[campaignName];
        require(campaign.isActive, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Campaign deadline passed");
        require(amount > 0, "Amount must be greater than 0");
        
        campaign.currentAmount += amount;
        
        emit CampaignFunded(campaignName, amount);
    }

    function verifyDonor(address donor) external onlyOwner {
        verifiedDonors[donor] = true;
        emit DonorVerified(donor);
    }

    function updateImpactMetrics(
        uint256 studentsFunded,
        uint256 totalEducationHours,
        uint256 scholarshipsAwarded,
        uint256 countriesReached
    ) external onlyOwner {
        impactMetrics.studentsFunded = studentsFunded;
        impactMetrics.totalEducationHours = totalEducationHours;
        impactMetrics.scholarshipsAwarded = scholarshipsAwarded;
        impactMetrics.countriesReached = countriesReached;
        
        emit ImpactUpdated(studentsFunded, totalEducationHours);
    }

    function addSupportedCountry(string memory country) external onlyOwner {
        impactMetrics.supportedCountries.push(country);
    }

    function _recordDonation(
        address donor,
        uint256 amount,
        string memory message,
        bool isRecurring,
        uint256 frequency
    ) internal {
        donorHistory[donor].push(Donation({
            donor: donor,
            amount: amount,
            timestamp: block.timestamp,
            message: message,
            isRecurring: isRecurring,
            frequency: frequency
        }));
    }

    function _updateDonorStats(address donor) internal {
        if (donorHistory[donor].length == 1) {
            totalDonors++;
        }
        
        // Calculate impact score based on donation amount and frequency
        uint256 totalDonated = 0;
        for (uint i = 0; i < donorHistory[donor].length; i++) {
            totalDonated += donorHistory[donor][i].amount;
        }
        
        donorImpactScore[donor] = totalDonated / 1 ether; // Score based on ETH equivalent
    }

    function _initializeDefaultCampaigns() internal {
        campaigns["Emergency Education Fund"] = Campaign({
            name: "Emergency Education Fund",
            description: "Provide immediate educational support for children in crisis",
            targetAmount: 100 ether,
            currentAmount: 0,
            deadline: block.timestamp + (30 days),
            isActive: true,
            category: "emergency"
        });
        
        campaigns["Technology for Learning"] = Campaign({
            name: "Technology for Learning",
            description: "Provide laptops, tablets, and internet access for remote learning",
            targetAmount: 50 ether,
            currentAmount: 0,
            deadline: block.timestamp + (60 days),
            isActive: true,
            category: "technology"
        });
        
        campaigns["School Infrastructure"] = Campaign({
            name: "School Infrastructure",
            description: "Build and repair schools in rural African communities",
            targetAmount: 200 ether,
            currentAmount: 0,
            deadline: block.timestamp + (90 days),
            isActive: true,
            category: "infrastructure"
        });
        
        campaignCategories.push("emergency");
        campaignCategories.push("technology");
        campaignCategories.push("infrastructure");
    }

    function getDonorHistory(address donor) external view returns (Donation[] memory) {
        return donorHistory[donor];
    }

    function getCampaign(string memory name) external view returns (Campaign memory) {
        return campaigns[name];
    }

    function getDonorImpactScore(address donor) external view returns (uint256) {
        return donorImpactScore[donor];
    }

    function getImpactMetrics() external view returns (ImpactMetric memory) {
        return impactMetrics;
    }

    function withdrawAllBalance(address to, address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        require(IERC20(token).transfer(to, balance));
        tokenDonations[token] = 0;
    }

    function withdrawNativeEth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        nativeDonations = 0;
        payable(owner()).transfer(balance);
    }

    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 5, "Fee cannot exceed 5%");
        platformFee = newFee;
    }

    function updateMinDonation(uint256 newMin) external onlyOwner {
        minDonationAmount = newMin;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {}

    receive() external payable {
        nativeDonations += msg.value;
    }
}
