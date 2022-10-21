// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SwapNFT is ERC721 {
    using Strings for uint256;

    address public governance;
    address public pendingGovernance;
    address public operator;

    uint256 public nextId = 1;
    string public baseURI;

    constructor(string memory name_, string memory symbol_, string memory baseURI_) ERC721(name_, symbol_) {
        governance = msg.sender;
        baseURI = baseURI_;
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
        operator = operator_;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId));
        return string(abi.encodePacked(baseURI, tokenId.toString()));
    }

    function mint(address to) external returns(uint256 tokenId) {
        require(msg.sender == operator, "!operator");

        tokenId = nextId++;
        _mint(to, tokenId);

        return tokenId;
    }

    function getNextId() external view returns (uint256) {
        return nextId;
    }
}
