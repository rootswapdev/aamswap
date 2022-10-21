// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface NFTExtension {
    function mint(address to) external returns(uint256);
    function getNextId() external view returns (uint256);
}

interface NFTStake {
    function whiteList(address stake) external view returns (uint256);
}

contract SwapMint {
    address public governance;
    address public pendingGovernance;
    address public addressTreasury;
    address public swapStake;
    address public nft;

    uint256 public privatePrice;
    uint256 public publicPrice;
    uint256 public startTime;
    uint256 public endTime;

    bool public started;

    mapping(address => uint256) public whiteList;
    mapping(address => uint256) public minerList;

    event MintToken(address indexed account, uint256 amount, uint256[] tokenIds);

    constructor(address nft_, address swapStake_) {
        nft = nft_;
        swapStake = swapStake_;
        governance = msg.sender;
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

    function initialize(address addressTreasury_, uint256 privatePrice_, uint256 publicPrice_, uint256 startTime_, uint256 endTime_) external returns(bool) {
        require(msg.sender == governance, "!governance");
        require(started == false, 'Already initialized');

        started = true;

        addressTreasury = addressTreasury_;
        privatePrice = privatePrice_;
        publicPrice = publicPrice_;
        startTime = startTime_;
        endTime = endTime_;

        return true;
    }

    function mint(uint256 numNFTs) external payable {
        require(true == started, '!started');
        require(block.timestamp < endTime, '!endTime');

        uint256 amount = calculateAmount(msg.sender, numNFTs);
        require(msg.value >= amount, '!msg.value');
        minerList[msg.sender] += numNFTs;

        uint256[] memory tokenIds = new uint256[](numNFTs);
        uint256 tokenId;
        for (uint256 i = 0; i < numNFTs; ) {
            tokenId = NFTExtension(nft).mint(msg.sender);
            tokenIds[i] = tokenId;

            unchecked {
                ++i;
            }
        }

        payable(addressTreasury).transfer(amount);
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }

        emit MintToken(msg.sender, amount, tokenIds);
    }

    function calculateAmount(address miner, uint256 numNFTs) public view returns (uint256 amount) {
        if (block.timestamp < startTime) {
            require(numNFTs <= getPrivateNum(miner), '!numNFTs');
            return numNFTs * privatePrice;
        }
        return numNFTs * publicPrice;
    }

    function setWhiteList(address miner, uint256 numNFTs) public {
        require(msg.sender == governance, "!governance");
        whiteList[miner] = numNFTs;
    }

    function getPrivateNum(address miner) public view returns (uint256 numNFTs) {
        return whiteList[miner] + NFTStake(swapStake).whiteList(miner) - minerList[miner];
    }

    function inCaseTokensGetStuck(address token_) external {
        require(msg.sender == governance, "!governance");
        uint _balance = IERC20(token_).balanceOf(address(this));
        IERC20(token_).transfer(governance, _balance);
    }
}
