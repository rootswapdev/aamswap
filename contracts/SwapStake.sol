// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./SwapBank.sol";
import "./ILSSVMPairFactoryLike.sol";
import "./bonding-curves/ICurve.sol";
import "./lib/OwnableWithTransferCallback.sol";

contract SwapStake {
    address public governance;
    address public pendingGovernance;
    address public bank;
    address public factory;

    uint256 public startTime;
    uint256 public endTime;

    mapping(IERC721 => uint256) public nftTotal;
    mapping(IERC721 => uint256) public nftStake;
    mapping(address => uint256) public whiteList;
    mapping(IERC721 => mapping(address => uint256[])) public tokenIds;

    event Deposit(IERC721 indexed nft, address indexed account, uint256[] tokenIds);
    event Withdraw(IERC721 indexed nft, address indexed from, address indexed to, uint256[] tokenIds);

    constructor() {
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

    function initialize(
        address _bank,
        address _factory,
        uint256 _startTime,
        uint256 _endTime
    ) external {
        require(msg.sender == governance, "!governance");
        require(0 == startTime, "!init");
        require(_startTime > block.timestamp, "!_startTime");
        require(_endTime > _startTime, "!_endTime");

        bank = _bank;
        factory = _factory;
        startTime = _startTime;
        endTime = _endTime;
    }

    function setTotal(IERC721 nft, uint256 total) public {
        require(msg.sender == governance, "!governance");
        nftTotal[nft] = total;
    }

    function deposit(
        IERC721 nft,
        uint256[] calldata nftIds
    ) public {
        require(block.timestamp < startTime, "!start");
        uint256 numNFTs = nftIds.length;
        nftStake[nft] += numNFTs;
        require(nftStake[nft] <= nftTotal[nft], "!nftStake");
        whiteList[msg.sender] += numNFTs;

        uint256 tokenId;
        uint256[] storage _tokenIds = tokenIds[nft][msg.sender];

        for (uint256 i; i < numNFTs; ) {
            tokenId = nftIds[i];
            IERC721(nft).safeTransferFrom(msg.sender, bank, tokenId);
            _tokenIds.push(tokenId);

            unchecked {
                ++i;
            }
        }
        whiteList[msg.sender] += numNFTs;
        emit Deposit(nft, msg.sender, nftIds);
    }

    function withdraw(IERC721 nft, address to) public {
        require(block.timestamp < startTime || block.timestamp > endTime, "stake");
        _withdraw(nft, msg.sender, to);
    }

    function createPair(
        IERC721 nft,
        ICurve curve,
        address payable recipient,
        ILSSVMPairFactoryLike.PoolType poolType,
        uint128 delta,
        uint96 fee,
        uint128 spotPrice
    ) public payable returns (address pair){
        require(msg.sender == governance, "!governance");
        require(block.timestamp > endTime, "!endTime");

        uint256[] memory _tokenIds = tokenIds[nft][msg.sender];
        _withdraw(nft, msg.sender, address(this));

        IERC721(nft).setApprovalForAll(factory, true);
        pair = ILSSVMPairFactoryLike(factory).createPairETH{
            value: msg.value
        }(
            nft,
            curve,
            recipient,
            poolType,
            delta,
            fee,
            spotPrice,
            _tokenIds
        );
        OwnableWithTransferCallback(pair).transferOwnership(msg.sender);
    }

    function stakeTokenIds(IERC721 nft, address staker) public view returns (uint256[] memory) {
        return tokenIds[nft][staker];
    }

    function _withdraw(IERC721 nft, address from, address to) internal {
        uint256[] memory _tokenIds = tokenIds[nft][from];
        SwapBank(bank).withdraw(nft, to, _tokenIds);
        if (block.timestamp < startTime) {
            whiteList[from] -= _tokenIds.length;
            nftStake[nft] -= _tokenIds.length;
        }
        delete tokenIds[nft][from];
        emit Withdraw(nft, from, to, _tokenIds);
    }

    function onERC721Received(
        address _operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
