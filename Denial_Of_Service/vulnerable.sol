// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VulnerableAuction {
    address public highestBidder;
    uint256 public highestBid;

    function bid() external payable {
        require(msg.value > highestBid, "Bid too low");

        // VULNERABLE: Push-over-pull pattern. Direct external call to refund previous highest bidder.
        // If the highest bidder is a smart contract that reverts on receiving ETH (or has no payable fallback),
        // all future bid() calls will revert, permanently freezing the auction.
        if (highestBidder != address(0)) {
            (bool success, ) = payable(highestBidder).call{value: highestBid}("");
            require(success, "Refund failed");
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
