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
    mapping(uint256 => Employer) employerId;
    uint256 public employerNonce;
    uint256 totalAmountStaked;

    constructor(uint256 _minSalary, uint256 _minStakeAmount) Ownable(msg.sender) {
        MIN_SALARY = _minSalary;
        MIN_STAKE_AMOUNT = _minStakeAmount;
    }

    function approveTokens(address _token) external onlyOwner {}

    function stakeAndHire(
        address token,
        address _employer,
        string calldata _name,
        string calldata _companyName,
        uint256 _desiredSalary,
        Skills calldata _skills,
        uint256 stakingAmount
    ) external {
        require(_employer != address(0), "Employer cannot be a zero address");
        require(_desiredSalary >= MIN_SALARY, "Not enough salary");
        require(stakingAmount > MIN_STAKE_AMOUNT, "Not enough Stake amount");
        IERC20(token).transferFrom(msg.sender, address(this), stakingAmount);
        Employer memory employer = Employer({
            employer: _employer,
            name: _name,
            companyName: _companyName,
            salary: _desiredSalary,
            skills: _skills,
            stakedAmount: stakingAmount
        });

        employerId[employerNonce++];
        totalAmountStaked += stakingAmount;
    }

    function withdraw(address token) external onlyOwner {
        IERC20(token).transfer(msg.sender, address(this).balance);
    }
}
