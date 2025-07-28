// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DonationPool is Ownable, UUPSUpgradeable {
    constructor() Ownable(msg.sender) {}

    mapping(address => uint256) tokenDonations;
    uint256 public nativeDonations;

    function donate(address token, uint256 amount) external {
        require(IERC20(token).transferFrom(msg.sender, address(this), amount));
        tokenDonations[token] += amount;
    }

    function donateNativeEth(uint256 amount) external payable {
        require(msg.value > 0, "Must send some ETH");
        nativeDonations += msg.value;
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

    function _authorizeUpgrade(address newImplementation) internal virtual override {}

    receive() external payable {
        nativeDonations += msg.value;
    }
}
