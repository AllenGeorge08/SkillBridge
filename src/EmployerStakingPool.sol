// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EmployerStakingPool is Ownable {
    uint256 public fee;
    uint256 public MIN_SALARY;
    uint256 public MIN_STAKE_AMOUNT;

    struct Skills {
        string name;
        string experience;
    }

    struct Employer {
        address employer;
        string name;
        string companyName;
        uint256 salary;
        Skills skills;
        uint256 stakedAmount;
    }

    mapping(address => IERC20) approvedTokens;
    mapping(uint256 => Employer) employers;
    mapping(address => uint256) employerIds;
    mapping(address => bool) public hasStaked;
    uint256 public employerNonce;
    uint256 totalAmountStaked;

    event EmployerStaked(address indexed employer, uint256 indexed employerId, uint256 stakedAmount);
    event TokensApproved(address indexed token);

    constructor(uint256 _minSalary, uint256 _minStakeAmount) Ownable(msg.sender) {
        MIN_SALARY = _minSalary;
        MIN_STAKE_AMOUNT = _minStakeAmount;
    }

    function approveTokens(address _token) external onlyOwner {
        approvedTokens[_token] = IERC20(_token);
        emit TokensApproved(_token);
    }

    function stakeAndHire(
        address token,
        address _employer,
        string calldata _name,
        string calldata _companyName,
        uint256 _desiredSalary,
        Skills calldata _skills,
        uint256 stakingAmount
    ) external returns (uint256 employerId) {
        require(_employer != address(0), "Employer cannot be a zero address");
        require(_desiredSalary >= MIN_SALARY, "Not enough salary");
        require(stakingAmount >= MIN_STAKE_AMOUNT, "Not enough Stake amount");
        require(approvedTokens[token] != IERC20(address(0)), "Token not approved");

        IERC20(token).transferFrom(msg.sender, address(this), stakingAmount);

        Employer memory newEmployer = Employer({
            employer: _employer,
            name: _name,
            companyName: _companyName,
            salary: _desiredSalary,
            skills: _skills,
            stakedAmount: stakingAmount
        });

        employerId = employerNonce++;
        employers[employerId] = newEmployer;
        employerIds[_employer] = employerId;
        hasStaked[_employer] = true;
        totalAmountStaked += stakingAmount;

        emit EmployerStaked(_employer, employerId, stakingAmount);
    }

    function withdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(IERC20(token).transfer(msg.sender, balance), "Transfer failed");
    }

    function getEmployer(uint256 employerId) external view returns (Employer memory) {
        require(employerId < employerNonce, "Employer does not exist");
        return employers[employerId];
    }

    function getEmployerByAddress(address employerAddress) external view returns (Employer memory) {
        uint256 employerId = employerIds[employerAddress];
        require(employerId > 0 || (employerId == 0 && hasStaked[employerAddress]), "Employer not found");
        return employers[employerId];
    }

    function getEmployerId(address employerAddress) external view returns (uint256) {
        return employerIds[employerAddress];
    }

    function isEmployerStaked(address employerAddress) external view returns (bool) {
        return hasStaked[employerAddress];
    }

    function getTotalStakedAmount() external view returns (uint256) {
        return totalAmountStaked;
    }

    function getEmployerCount() external view returns (uint256) {
        return employerNonce;
    }

    function getStakedAmount(address employerAddress) external view returns (uint256) {
        uint256 employerId = employerIds[employerAddress];
        if (employerId == 0 && !hasStaked[employerAddress]) {
            return 0;
        }
        return employers[employerId].stakedAmount;
    }
}
