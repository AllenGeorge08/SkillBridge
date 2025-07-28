// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract HiringRegistry is UUPSUpgradeable,Ownable {
    struct Skill {
        address issuedTo;
        string skillName;
        string level;
        string issuer;
        uint256 issuedAt;
    }

    address[] graduates;
    mapping(address => bool) public isGraduate;
    mapping(address => Skill) skills;
    mapping(address => bool) isHired;
    mapping (address => uint256) hiringQuotes;

    constructor()  Ownable(msg.sender){}

    function addGraduate(address graduate, string memory skillName, string memory level, string memory issuer) public onlyOwner{
        if (!isGraduate[graduate]) {
            graduates.push(graduate);
            isGraduate[graduate] = true;
        }

        skills[graduate] =
            Skill({issuedTo: graduate,skillName: skillName, level: level, issuer: issuer, issuedAt: block.timestamp});
        
    }

    function quoteHire(address candidate,uint256 quote) public {
        require(isGraduate[candidate], "Candidate is not a graduate");
        require(!isHired[candidate], "Candidate already Hired");

        hiringQuotes[candidate] = quote;

    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {}
}
