// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";
import "./Context.sol";
import "./Ownable.sol";
import "./IERC20Errors.sol";
import "./IPancakeRouter.sol";
import "./IPancakeFactory.sol";

/// @title XRP ETF Token
/// @author Cadillacs
/// @notice This contract is used to create the XRP ETF Token
/// @dev This contract implements the functionality of an BEP20 token with additional features such as automated market maker pairs, fee calculations, whitelist management, and trading enable/disable functionality.

contract XRPEFTToken is Context, IERC20, Ownable, IERC20Errors {
    mapping(address account => uint256) private _balances;
    mapping(address account => mapping(address spender => uint256))
        private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    // Taxes goes to dead address
    uint256 public buyTax = 250;
    uint256 public sellTax = 500;

    // Boolean
    bool public tradingEnabled = false;
    bool public feeBurnEnabled = false;

    // Events
    event TradingEnabled(bool enabled);
    event FeeBurnEnabled(bool enabled);
    event WalletWhitelisted(address _address);
    event WhitelistRemoved(address _address);
    event TaxUpdate(uint256 buyTax, uint256 sellTax);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);

    address public constant deadAddress =
        0x000000000000000000000000000000000000dEaD;
    address public taxWallet;
    address public teamWallet =0x817c7A5DDb37F4532CaA097109406d43C8BB48ba;
    IPancakeRouter02 public pancakeRouter;
    address public pancakePair;

    // Constructor
    constructor() Ownable(msg.sender) {
        _name = "XRP ETF Token";
        _symbol = "XRPETF";
        _totalSupply = 1000000000 * 10 ** decimals();
        taxWallet = address(this);
        // Mainnet Binance Uniswap
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
        // Mainnet Binance PCS
        // IPancakeRouter02 _pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // Testnet BNB
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        );
        pancakeRouter = _pancakeRouter;
        pancakePair = IPancakeFactory(_pancakeRouter.factory()).createPair(
            address(this),
            _pancakeRouter.WETH()
        );
        _setAutomatedMarketMakerPair(address(pancakePair), true);
        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[address(this)] = true;
        _mint(msg.sender, (_totalSupply * 95) / 100);
        _mint(teamWallet, (_totalSupply * 5) / 100);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address _owner,
        address spender
    ) public view virtual returns (uint256) {
        return _allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount, true);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        _spendAllowance(sender, _msgSender(), amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(
            pair != pancakePair,
            "The Pancake pair cannot be removed from automatedMarketMakerPairs"
        );
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address _owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
        if (_owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[_owner][spender] = value;
        if (emitEvent) {
            emit Approval(_owner, spender, value);
        }
    }

    function _spendAllowance(
        address _owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(_owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(_owner, spender, currentAllowance - value, false);
            }
        }
    }

    function _burnFrom(address account, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount, true);
        }
        _burn(account, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 fee = 0;
        bool takeFee = true;

        if (!_isExcludedFromFee[sender] && !_isExcludedFromFee[recipient]) {
            require(tradingEnabled, "Trading is not enabled");
        }

        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            fee = 0;
            takeFee = false;
        }

        if (takeFee) {
            if (automatedMarketMakerPairs[sender]) {
                fee = (amount * buyTax) / 10000;
            } else if (automatedMarketMakerPairs[recipient]) {
                fee = (amount * sellTax) / 10000;
            }
        }

        _balances[sender] -= amount;
        _balances[recipient] += (amount - fee);
        emit Transfer(sender, recipient, (amount - fee));

        if (fee > 0 && feeBurnEnabled) {
            _balances[deadAddress] += fee;
            emit Transfer(sender, deadAddress, fee);
        }
        if (fee > 0 && !feeBurnEnabled) {
            _balances[taxWallet] += fee;
            emit Transfer(sender, taxWallet, fee);
        }
    }

    function _addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        _approve(address(this), address(pancakeRouter), tokenAmount, true);
        try
            pancakeRouter.addLiquidityETH{value: bnbAmount}(
                address(this),
                tokenAmount,
                0,
                0,
                deadAddress,
                block.timestamp
            )
        {
            emit LiquidityAdded(tokenAmount, bnbAmount);
        } catch {}
    }

    function whiteListWallet(address _address) public onlyOwner {
        require(
            _isExcludedFromFee[_address] == false,
            "Address is already whitelisted"
        );
        _isExcludedFromFee[_address] = true;
        emit WalletWhitelisted(_address);
    }

    function removeWalletFromWhiteList(address _address) public onlyOwner {
        require(
            _isExcludedFromFee[_address] == true,
            "Address is not whitelisted"
        );
        _isExcludedFromFee[_address] = false;
        emit WhitelistRemoved(_address);
    }

    function updateTax(uint256 _buyTax, uint256 _sellTax) public onlyOwner {
        require(_buyTax <= 500, "Buy tax cannot be more than 5%");
        require(_sellTax <= 1000, "Sell tax cannot be more than 10%");
        buyTax = _buyTax;
        sellTax = _sellTax;
        emit TaxUpdate(_buyTax, _sellTax);
    }

    function updateTaxWallet(address _wallet) public onlyOwner {
        require(taxWallet != _wallet, "Wallet already in use");
        require(_wallet != address(0), "Tax wallet cannot be a deadAddress");
        taxWallet = _wallet;
    }

    function enableTrading() public onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled(true);
    }

    function disableTrading() public onlyOwner {
        tradingEnabled = false;
        emit TradingEnabled(false);
    }

    function enableFeeBurn() public onlyOwner {
        feeBurnEnabled = true;
        emit FeeBurnEnabled(true);
    }

    function disableFeeBurn() public onlyOwner {
        feeBurnEnabled = false;
        emit FeeBurnEnabled(false);
    }

    receive() external payable {}

    function withdrawBNB() public onlyOwner {
        require(address(this).balance > 0, "Insufficient balance");
        payable(owner()).transfer(address(this).balance);
    }

    function withdrawBEP20(address _tokenAddress) public onlyOwner {
        require(_tokenAddress != address(this), "Cannot withdraw MATAR tokens");
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) > 0,
            "Insufficient balance"
        );
        IERC20(_tokenAddress).transfer(
            owner(),
            IERC20(_tokenAddress).balanceOf(address(this))
        );
    }
}