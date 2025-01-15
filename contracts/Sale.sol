// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./IERC20.sol";
import "./AggregatorV3Interface.sol";

contract XRPETFPresale is Ownable, ReentrancyGuard {
    struct PresaleRound {
        // Price 0.008 contains 3 decimals and 8 as token price
        uint256 tokenPrice; // Price per XRPETF in USD
        uint256 priceDecimals; // Decimals of the token price
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

    uint256 public minBuyInUSD = 5;

    AggregatorV3Interface internal priceFeed;
    IERC20 public token;
    IERC20 public usdt;

    event RoundStarted(uint256 round, uint256 tokenPrice, uint256 targetGoal);
    event TokensPurchased(address buyer, uint256 amount, uint256 price);
    // Testing logs
    event LogA(uint256 value);
    event LogB(uint256 value);
    event LogC(uint256 value);

    constructor() Ownable(msg.sender) {
        token = IERC20(0x1F53f6F7c0B1d7f7d6f9E7f1B3C3f5F6f6F7F7F7);
        priceFeed = AggregatorV3Interface(
            0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526
        );
        usdt = IERC20(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd);
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
        uint256 _usdValue = (getBNBPrice() * msg.value) / 10 ** 26;
        emit LogA(_usdValue);
        require(_usdValue > minBuyInUSD, "Insufficient amount");

        uint256 _xrpetfValue = _calcXRPETF(msg.value);
        emit LogB(_xrpetfValue);
        require(_xrpetfValue <= _remainingTokens(), "Insufficient tokens");
        require(
            _xrpetfValue <= token.balanceOf(address(this)),
            "Insufficient balance"
        );

        EthRaised += msg.value;
        payable(owner()).transfer(msg.value);
        totalSold += _xrpetfValue * 10 ** 18;
        rounds[currentRound].tokensSold += _xrpetfValue;
        token.transfer(msg.sender, _xrpetfValue * 10 ** 18);

        emit TokensPurchased(
            msg.sender,
            _xrpetfValue * 10 ** 18,
            rounds[currentRound].tokenPrice
        );
    }

    function buyWithUsdt(uint256 _amount) external nonReentrant {
        require(rounds[currentRound].active, "No active round");
        require(
            block.timestamp >= rounds[currentRound].startTime,
            "Presale not started"
        );
        require(
            block.timestamp <= rounds[currentRound].endTime,
            "Presale ended"
        );
        emit LogA(_amount);
        require((_amount / 1 ether) > minBuyInUSD, "Insufficient amount");

        uint256 _usdValue = _amount / 1 ether;
        emit LogB(_usdValue);

        uint256 _xrpetfValue = _usdValue *
            ((10 ** rounds[currentRound].priceDecimals) /
                rounds[currentRound].tokenPrice);
        emit LogC(_xrpetfValue);
        require(_xrpetfValue <= _remainingTokens(), "Insufficient tokens");
        require(
            _xrpetfValue <= token.balanceOf(address(this)),
            "Insufficient balance"
        );

        usdt.transferFrom(msg.sender, owner(), _amount);
        usdtRaised += _amount;
        token.transfer(msg.sender, _xrpetfValue * 10 ** 18);
        totalSold += _xrpetfValue * 10 ** 18;
        rounds[currentRound].tokensSold += _xrpetfValue;

        emit TokensPurchased(
            msg.sender,
            _xrpetfValue * 10 ** 18,
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

    // Respectively calculation: 1000/8, 1000/9, 1000/10, 10000/125, 1000/15
    function _calcXRPETF(uint256 _msgValue) private view returns (uint256) {
        uint256 bnbPrice = getBNBPrice();
        uint256 usdValue = (_msgValue * bnbPrice) / 10 ** 26;
        return
            usdValue *
            ((10 ** rounds[currentRound].priceDecimals) /
                rounds[currentRound].tokenPrice);
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
        require(!rounds[currentRound].active, "Presale still active");
        token.transfer(owner(), _amount);
    }

    function updateTokenPrice(
        uint256 _tokenPrice,
        uint256 _priceDecimals,
        uint256 _round
    ) external onlyOwner {
        rounds[_round].tokenPrice = _tokenPrice;
        rounds[_round].priceDecimals = _priceDecimals;
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

    function updateTokenAddress(address _token) external onlyOwner {
        require(_token != address(0), "Invalid address");
        token = IERC20(_token);
    }

    function updateMinBuyInUSD(uint256 _minBuyInUSD) external onlyOwner {
        require(_minBuyInUSD > 0, "Invalid value");
        require(_minBuyInUSD < 100000000, "Invalid value");
        minBuyInUSD = _minBuyInUSD;
    }

    receive() external payable {}
}
