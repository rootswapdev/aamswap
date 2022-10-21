// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SwapBank {
    address public governance;
    address public pendingGovernance;
    address public operator;
    uint256 public effectTime;

    constructor(address operator_) {
        governance = msg.sender;
        operator = operator_;
        effectTime = block.timestamp + 60 days;
    }

    function acceptGovernance() external {
        require(msg.sender == pendingGovernance, "!pendingGovernance");
        governance = msg.sender;
        pendingGovernance = address(0);
    }
    function setPendingGovernance(address pendingGovernance_) external {
        require(msg.sender == governance, "!governance");
        pendingGovernance = pendingGovernance_;
    }

    function setOperator(address operator_) external {
        require(msg.sender == governance, "!governance");
        require(block.timestamp > effectTime, "!effectTime");
        operator = operator_;
    }

    function onERC721Received(
        address _operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function withdraw(IERC721 nft, address to, uint256[] calldata tokenIds) public {
        require(msg.sender == operator, "!operator");
        uint256 tokenId;
        uint256 numNFTs = tokenIds.length;
        for (uint256 i; i < numNFTs; ) {
            tokenId = tokenIds[i];
            nft.safeTransferFrom(address(this), to, tokenId);

            unchecked {
                ++i;
            }
        }
    }
}
