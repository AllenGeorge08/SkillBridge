// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AIChatAssistant is Ownable, ReentrancyGuard {
    struct ChatSession {
        address user;
        uint256 sessionId;
        uint256 startTime;
        uint256 lastActivity;
        bool isActive;
        uint256 messageCount;
    }

    struct Message {
        address sender;
        string content;
        uint256 timestamp;
        bool isAIResponse;
        string messageType; // "question", "answer", "guidance", "resource"
    }

    struct EducationalResource {
        string title;
        string description;
        string url;
        string category; // "math", "science", "language", "career", "scholarship"
        bool isActive;
        uint256 addedAt;
    }

    mapping(address => ChatSession[]) public userSessions;
    mapping(uint256 => Message[]) public sessionMessages;
    mapping(string => EducationalResource) public resources;
    mapping(address => bool) public verifiedStudents;
    mapping(address => uint256) public userCredits;
    mapping(address => string[]) public userInterests;

    uint256 public sessionCounter;
    uint256 public creditCost = 1; // Credits per message
    uint256 public maxMessageLength = 500;
    uint256 public maxSessionsPerUser = 10;

    event SessionStarted(address indexed user, uint256 indexed sessionId);
    event MessageSent(address indexed user, uint256 indexed sessionId, string content);
    event AIResponse(address indexed user, uint256 indexed sessionId, string response);
    event ResourceAdded(string indexed category, string title);
    event CreditsPurchased(address indexed user, uint256 amount);
    event StudentVerified(address indexed student);

    constructor() Ownable(msg.sender) {
        // Initialize with basic educational resources
        _addDefaultResources();
    }

    function startChatSession() external returns (uint256) {
        require(userSessions[msg.sender].length < maxSessionsPerUser, "Too many active sessions");
        
        uint256 sessionId = sessionCounter++;
        ChatSession memory newSession = ChatSession({
            user: msg.sender,
            sessionId: sessionId,
            startTime: block.timestamp,
            lastActivity: block.timestamp,
            isActive: true,
            messageCount: 0
        });

        userSessions[msg.sender].push(newSession);
        
        emit SessionStarted(msg.sender, sessionId);
        return sessionId;
    }

    function sendMessage(uint256 sessionId, string memory content) external {
        require(bytes(content).length <= maxMessageLength, "Message too long");
        require(bytes(content).length > 0, "Message cannot be empty");
        require(userCredits[msg.sender] >= creditCost, "Insufficient credits");

        // Find the session
        bool sessionFound = false;
        for (uint i = 0; i < userSessions[msg.sender].length; i++) {
            if (userSessions[msg.sender][i].sessionId == sessionId && 
                userSessions[msg.sender][i].isActive) {
                sessionFound = true;
                userSessions[msg.sender][i].lastActivity = block.timestamp;
                userSessions[msg.sender][i].messageCount++;
                break;
            }
        }
        require(sessionFound, "Session not found or inactive");

        // Deduct credits
        userCredits[msg.sender] -= creditCost;

        // Add user message
        sessionMessages[sessionId].push(Message({
            sender: msg.sender,
            content: content,
            timestamp: block.timestamp,
            isAIResponse: false,
            messageType: "question"
        }));

        emit MessageSent(msg.sender, sessionId, content);

        // Generate AI response (this would be handled off-chain)
        _generateAIResponse(sessionId, content);
    }

    function _generateAIResponse(uint256 sessionId, string memory userMessage) internal {
        // This is a placeholder for AI response generation
        // In a real implementation, this would trigger an off-chain AI service
        
        string memory aiResponse = _getEducationalResponse(userMessage);
        
        sessionMessages[sessionId].push(Message({
            sender: address(this),
            content: aiResponse,
            timestamp: block.timestamp,
            isAIResponse: true,
            messageType: "answer"
        }));

        emit AIResponse(msg.sender, sessionId, aiResponse);
    }

    function _getEducationalResponse(string memory userMessage) internal view returns (string memory) {
        // Simple keyword-based responses (in real implementation, this would be AI-powered)
        if (_contains(userMessage, "scholarship")) {
            return "I can help you find scholarships! Check our scholarship database or apply for funding through our platform. What's your field of study?";
        } else if (_contains(userMessage, "math")) {
            return "Great! I can help with math. Here are some resources: Khan Academy, Coursera, and local tutoring programs. What specific math topic do you need help with?";
        } else if (_contains(userMessage, "career")) {
            return "Career guidance is important! I can help you explore different career paths, find internships, and connect with mentors. What interests you?";
        } else {
            return "I'm here to help with your education! I can assist with scholarships, study resources, career guidance, and more. What would you like to know?";
        }
    }

    function _contains(string memory source, string memory search) internal pure returns (bool) {
        bytes memory sourceBytes = bytes(source);
        bytes memory searchBytes = bytes(search);
        
        if (searchBytes.length > sourceBytes.length) {
            return false;
        }
        
        for (uint i = 0; i <= sourceBytes.length - searchBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < searchBytes.length; j++) {
                if (sourceBytes[i + j] != searchBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        return false;
    }

    function addEducationalResource(
        string memory title,
        string memory description,
        string memory url,
        string memory category
    ) external onlyOwner {
        resources[title] = EducationalResource({
            title: title,
            description: description,
            url: url,
            category: category,
            isActive: true,
            addedAt: block.timestamp
        });

        emit ResourceAdded(category, title);
    }

    function getSessionMessages(uint256 sessionId) external view returns (Message[] memory) {
        return sessionMessages[sessionId];
    }

    function getUserSessions(address user) external view returns (ChatSession[] memory) {
        return userSessions[user];
    }

    function getEducationalResources(string memory category) external view returns (EducationalResource[] memory) {
        // This would need to be implemented with a more complex data structure
        // For now, returning empty array
        EducationalResource[] memory result = new EducationalResource[](0);
        return result;
    }

    function purchaseCredits() external payable {
        require(msg.value > 0, "Must send ETH to purchase credits");
        uint256 creditsToAdd = msg.value / 0.01 ether; // 1 credit per 0.01 ETH
        userCredits[msg.sender] += creditsToAdd;
        
        emit CreditsPurchased(msg.sender, creditsToAdd);
    }

    function verifyStudent(address student) external onlyOwner {
        verifiedStudents[student] = true;
        userCredits[student] += 10; // Give verified students free credits
        emit StudentVerified(student);
    }

    function addUserInterest(address user, string memory interest) external onlyOwner {
        userInterests[user].push(interest);
    }

    function getUserCredits(address user) external view returns (uint256) {
        return userCredits[user];
    }

    function isStudentVerified(address student) external view returns (bool) {
        return verifiedStudents[student];
    }

    function updateCreditCost(uint256 newCost) external onlyOwner {
        creditCost = newCost;
    }

    function updateMaxMessageLength(uint256 newLength) external onlyOwner {
        maxMessageLength = newLength;
    }

    function _addDefaultResources() internal {
        resources["Khan Academy"] = EducationalResource({
            title: "Khan Academy",
            description: "Free online courses in math, science, and more",
            url: "https://khanacademy.org",
            category: "general",
            isActive: true,
            addedAt: block.timestamp
        });
        
        resources["Coursera"] = EducationalResource({
            title: "Coursera",
            description: "Online courses from top universities",
            url: "https://coursera.org",
            category: "general",
            isActive: true,
            addedAt: block.timestamp
        });
        
        resources["Scholarship Database"] = EducationalResource({
            title: "Scholarship Database",
            description: "Find scholarships for African students",
            url: "https://scholarships.africa",
            category: "scholarship",
            isActive: true,
            addedAt: block.timestamp
        });
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }
} 