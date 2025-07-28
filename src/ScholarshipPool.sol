// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ScholarshipPool is Ownable, ReentrancyGuard {
    struct Student {
        address studentAddress;
        string name;
        string country;
        string educationLevel;
        uint256 totalFunded;
        uint256 totalWithdrawn;
        bool isActive;
        uint256 createdAt;
        string story;
    }

    struct Donation {
        address donor;
        uint256 amount;
        uint256 timestamp;
        string message;
    }

    struct Milestone {
        string description;
        uint256 targetAmount;
        bool isCompleted;
        uint256 completedAt;
    }

    mapping(address => Student) public students;
    mapping(address => Donation[]) public studentDonations;
    mapping(address => Milestone[]) public studentMilestones;
    mapping(address => bool) public verifiedStudents;
    mapping(address => uint256) public donorTotalDonations;

    uint256 public totalStudents;
    uint256 public totalDonations;
    uint256 public minDonationAmount = 0.01 ether;
    uint256 public platformFee = 2; // 2% platform fee

    event StudentRegistered(address indexed student, string name, string country);
    event DonationMade(address indexed donor, address indexed student, uint256 amount, string message);
    event MilestoneCompleted(address indexed student, string description);
    event StudentVerified(address indexed student);
    event FundsWithdrawn(address indexed student, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function registerStudent(
        address studentAddress,
        string memory name,
        string memory country,
        string memory educationLevel,
        string memory story
    ) external {
        require(!students[studentAddress].isActive, "Student already registered");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(country).length > 0, "Country cannot be empty");

        students[studentAddress] = Student({
            studentAddress: studentAddress,
            name: name,
            country: country,
            educationLevel: educationLevel,
            totalFunded: 0,
            totalWithdrawn: 0,
            isActive: true,
            createdAt: block.timestamp,
            story: story
        });

        totalStudents++;
        emit StudentRegistered(studentAddress, name, country);
    }

    function donateToStudent(
        address studentAddress,
        string memory message
    ) external payable nonReentrant {
        require(students[studentAddress].isActive, "Student not found or inactive");
        require(msg.value >= minDonationAmount, "Donation too small");
        require(bytes(message).length <= 200, "Message too long");

        uint256 platformFeeAmount = (msg.value * platformFee) / 100;
        uint256 studentAmount = msg.value - platformFeeAmount;

        students[studentAddress].totalFunded += studentAmount;
        totalDonations += msg.value;
        donorTotalDonations[msg.sender] += msg.value;

        studentDonations[studentAddress].push(Donation({
            donor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            message: message
        }));

        emit DonationMade(msg.sender, studentAddress, msg.value, message);
    }

    function donateTokenToStudent(
        address studentAddress,
        address token,
        uint256 amount,
        string memory message
    ) external nonReentrant {
        require(students[studentAddress].isActive, "Student not found or inactive");
        require(amount > 0, "Amount must be greater than 0");
        require(bytes(message).length <= 200, "Message too long");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        students[studentAddress].totalFunded += amount;
        totalDonations += amount;
        donorTotalDonations[msg.sender] += amount;

        studentDonations[studentAddress].push(Donation({
            donor: msg.sender,
            amount: amount,
            timestamp: block.timestamp,
            message: message
        }));

        emit DonationMade(msg.sender, studentAddress, amount, message);
    }

    function addMilestone(
        address studentAddress,
        string memory description,
        uint256 targetAmount
    ) external onlyOwner {
        require(students[studentAddress].isActive, "Student not found or inactive");
        
        studentMilestones[studentAddress].push(Milestone({
            description: description,
            targetAmount: targetAmount,
            isCompleted: false,
            completedAt: 0
        }));
    }

    function completeMilestone(address studentAddress, uint256 milestoneIndex) external onlyOwner {
        require(milestoneIndex < studentMilestones[studentAddress].length, "Milestone does not exist");
        require(!studentMilestones[studentAddress][milestoneIndex].isCompleted, "Milestone already completed");

        studentMilestones[studentAddress][milestoneIndex].isCompleted = true;
        studentMilestones[studentAddress][milestoneIndex].completedAt = block.timestamp;

        emit MilestoneCompleted(studentAddress, studentMilestones[studentAddress][milestoneIndex].description);
    }

    function verifyStudent(address studentAddress) external onlyOwner {
        require(students[studentAddress].isActive, "Student not found or inactive");
        verifiedStudents[studentAddress] = true;
        emit StudentVerified(studentAddress);
    }

    function withdrawFunds(uint256 amount) external nonReentrant {
        require(students[msg.sender].isActive, "Student not registered");
        require(verifiedStudents[msg.sender], "Student not verified");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= getAvailableBalance(msg.sender), "Insufficient available balance");

        students[msg.sender].totalWithdrawn += amount;
        payable(msg.sender).transfer(amount);

        emit FundsWithdrawn(msg.sender, amount);
    }

    function getAvailableBalance(address studentAddress) public view returns (uint256) {
        Student memory student = students[studentAddress];
        return student.totalFunded - student.totalWithdrawn;
    }

    function getStudentDonations(address studentAddress) external view returns (Donation[] memory) {
        return studentDonations[studentAddress];
    }

    function getStudentMilestones(address studentAddress) external view returns (Milestone[] memory) {
        return studentMilestones[studentAddress];
    }

    function getDonorStats(address donor) external view returns (uint256) {
        return donorTotalDonations[donor];
    }

    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Fee cannot exceed 10%");
        platformFee = newFee;
    }

    function updateMinDonation(uint256 newMin) external onlyOwner {
        minDonationAmount = newMin;
    }

    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    receive() external payable {
        // Accept ETH donations
    }
} 