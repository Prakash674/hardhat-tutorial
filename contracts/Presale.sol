// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./AggregatorV3Interface.sol";
import "hardhat/console.sol";

contract XRPETFPresale is Ownable, ReentrancyGuard {
    struct PresaleRound {
        uint256 tokenPrice; // Price per XRPETF in USD
        uint256 priceDecimals;
        uint256 tokensSold;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    mapping(uint256 => PresaleRound) public rounds;

    uint256 public currentRound;
    uint256 public EthRaised;
    uint256 public usdtRaised;
    uint256 public totalSold;
    uint256 public constant tokenForAllRound = 482777777;
    uint256 private constant tokenForFirstRound = 125000000;
    uint256 private constant tokenForSecondRound = 111111111;
    uint256 private constant tokenForThirdRound = 100000000;
    uint256 private constant tokenForFourthRound = 80000000;
    uint256 private constant tokenForFifthRound = 66666666;

    uint256 public minBuyInUSD = 5 * 10 ** 8;

    AggregatorV3Interface internal priceFeed;
    IERC20 public token;
    IERC20 public usdt;

    event RoundStarted(uint256 round, uint256 tokenPrice, uint256 targetGoal);
    event TokensPurchased(address buyer, uint256 amount, uint256 price);
    event TokenPurchasedWithUSDT(address buyer, uint256 amount, uint256 price);

    constructor(address _tokenAddress) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
        usdt = IERC20(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd);
        priceFeed = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );
        EthRaised = 0;
        totalSold = 0;
    }

    function getBNBPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function initializeRound(
        uint256 price,
        uint256 _priceDecimals,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(block.timestamp < _startTime, "Invalid start time");
        require(_startTime < _endTime, "Invalid end time");

        if (currentRound == 0) {
            currentRound = 1;
            rounds[currentRound].tokenPrice = price;
            rounds[currentRound].priceDecimals = _priceDecimals;
            rounds[currentRound].startTime = _startTime;
            rounds[currentRound].endTime = _endTime;
            rounds[currentRound].active = true;
            emit RoundStarted(
                currentRound,
                rounds[currentRound].tokenPrice,
                tokenForFirstRound
            );
        } else {
            rounds[currentRound].active = false;
            currentRound++;
            rounds[currentRound].tokenPrice = price;
            rounds[currentRound].priceDecimals = _priceDecimals;
            rounds[currentRound].startTime = _startTime;
            rounds[currentRound].endTime = _endTime;
            rounds[currentRound].active = true;
            emit RoundStarted(
                currentRound,
                rounds[currentRound].tokenPrice,
                tokenForSecondRound
            );
        }
    }

    function buyTokens() external payable nonReentrant {
        require(rounds[currentRound].active, "No active round");
        require(
            block.timestamp >= rounds[currentRound].startTime,
            "Presale not started"
        );
        require(
            block.timestamp <= rounds[currentRound].endTime,
            "Presale ended"
        );

        // Calculate USD value of BNB
        uint256 _usdValue = (getBNBPrice() * msg.value) / 10 ** 8;
        require(_usdValue > minBuyInUSD, "Insufficient amount");

        uint256 _xrpetfValue = _calcXRPETF(msg.value);
        require(_xrpetfValue <= _remainingTokens(), "Insufficient tokens");
        require(
            _xrpetfValue <= token.balanceOf(address(this)),
            "Insufficient balance"
        );

        EthRaised += msg.value;
        payable(owner()).transfer(msg.value);
        totalSold += _xrpetfValue;
        rounds[currentRound].tokensSold += _xrpetfValue;
        token.transfer(msg.sender, _xrpetfValue);

        emit TokensPurchased(
            msg.sender,
            _xrpetfValue,
            rounds[currentRound].tokenPrice
        );
    }

    function buyWithUSDT(uint256 _amount) external nonReentrant {
        require(rounds[currentRound].active, "No active round");
        require(
            block.timestamp >= rounds[currentRound].startTime,
            "Presale not started"
        );
        require(
            block.timestamp <= rounds[currentRound].endTime,
            "Presale ended"
        );
        require(usdt.balanceOf(msg.sender) >= _amount, "Insufficient balance");

        uint256 _xrpetfValue = (_amount / rounds[currentRound].tokenPrice) *
            10 ** rounds[currentRound].priceDecimals;
        require(_xrpetfValue <= _remainingTokens(), "Insufficient tokens");
        require(
            _xrpetfValue <= token.balanceOf(address(this)),
            "Insufficient balance"
        );
        usdt.transferFrom(msg.sender, owner(), _amount);
        usdtRaised += _amount;
        totalSold += _xrpetfValue;
        rounds[currentRound].tokensSold += _xrpetfValue;
        token.transfer(msg.sender, _xrpetfValue);

        emit TokenPurchasedWithUSDT(
            msg.sender,
            _xrpetfValue,
            rounds[currentRound].tokenPrice
        );
    }

    function _remainingTokens() private view returns (uint256) {
        if (currentRound == 1) {
            return tokenForFirstRound - rounds[currentRound].tokensSold;
        } else if (currentRound == 2) {
            return tokenForSecondRound - rounds[currentRound].tokensSold;
        } else if (currentRound == 3) {
            return tokenForThirdRound - rounds[currentRound].tokensSold;
        } else if (currentRound == 4) {
            return tokenForFourthRound - rounds[currentRound].tokensSold;
        } else if (currentRound == 5) {
            return tokenForFifthRound - rounds[currentRound].tokensSold;
        }
        return 0;
    }

    function _calcXRPETF(uint256 _msgValue) private view returns (uint256) {
        uint256 bnbPrice = getBNBPrice();
        uint256 usdValue = (_msgValue * bnbPrice) / 10 ** 8;
        uint256 xrpetfValue = (usdValue / rounds[currentRound].tokenPrice) *
            10 ** rounds[currentRound].priceDecimals;
        return xrpetfValue;
    }

    function withdrawBNB() external onlyOwner {
        require(!rounds[currentRound].active, "Presale still active");
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawTokens(uint256 _amount) external onlyOwner {
        require(
            _amount <= token.balanceOf(address(this)),
            "Insufficient balance"
        );
        require(rounds[currentRound].endTime > block.timestamp, "Presale not ended");
        token.transfer(owner(), _amount);
    }

    function updateTokenPrice(
        uint256 _tokenPrice,
        uint256 _round
    ) external onlyOwner {
        require(_round > currentRound && _round <= 5, "Invalid round");
        rounds[_round].tokenPrice = _tokenPrice;
    }

    function updateRoundTime(
        uint256 _endTime,
        uint256 _round
    ) external onlyOwner {
        require(_round >= currentRound, "Invalid round");
        require(block.timestamp < _endTime, "Invalid end time");
        require(_round <= 5, "Invalid round");
        rounds[_round].endTime = _endTime;
    }

    function updateMinBuyInUSD(uint256 _minBuyInUSD) external onlyOwner {
        require(_minBuyInUSD > 0, "Invalid value");
        require(_minBuyInUSD < 100000000, "Invalid value");
        minBuyInUSD = _minBuyInUSD * 10 ** 8;
    }

    receive() external payable {}
}
