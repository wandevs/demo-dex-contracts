pragma solidity ^0.4.23;

import './ERC20Protocol.sol';
import './Halt.sol';
import './SafeMath.sol';

contract Exchange is Halt {
    using SafeMath for uint;

    /**
    *
    * STRUCTURES
    *
    */
    struct Token {
        address addr;
        string  symbol;
		uint    timestamp;
    }

    /**
    *
    * VARIABLES
    *
    */
    /// @notice fee rate (parts per 10000)
	uint public feeRate;

    /// @notice fee rate precise
    /// @notice for example: if feeRate is 100, the fee ratio is 100/10000
    uint public constant RATIO_PRECISE = 10000;

    /// @notice fee recipient
	address public feeRecipient;

    /// @notice list of supported tokens
	mapping(address => Token) public mapSupportedTokens;

    /// @notice list of token addresses
	address[] public supportedTokens;

    /**
    *
    * EVENTS
    *
    **/

    /// @notice              event of token added to exchange
    /// @param symbol        symbol of token
    /// @param tokenAddress  address of token contract
    /// @param timestamp     timestamp when token add occurred
    event TokenAdded(string indexed symbol, address indexed tokenAddress, uint indexed timestamp);

    /// @notice              event of token removed from exchange
    /// @param tokenAddress  address of token contract
    /// @param timestamp     timestamp when token add occurred
    event TokenRemoved(address indexed tokenAddress, uint indexed timestamp);

    /// @notice              event of trade complete
    /// @param makerToken    contract address that maker wants to sell
    /// @param takerToken    contract address that taker wants to sell
    /// @param makerAddress  maker wan address
    /// @param takerAddress  taker wan address
    /// @param makerAmount   amount that maker gives
    /// @param takerAmount   amount that taker gives
    // event TradeFulfilled(address indexed makerToken, address indexed takerToken, address makerAddress, address takerAddress, uint makerAmount, uint takerAmount);

    /// @notice        event of trade failure
    /// @param code    error code
    /// @param amount  the incorrect amount (either allowance or balance)
    event TradeFailed(int indexed code, uint indexed amount);

    /**
    *
    * MODIFIERS
    *
    */

    modifier initialized() {
        require(feeRecipient != address(0));
        _;
    }

    /**
    *
    * MANIPULATIONS
    *
    */

    /// @notice default tranfer to contract
    constructor() public {
       feeRate = 0;
    }

    /// @notice default tranfer to contract
    function () public payable {
       revert();
    }

    /// @notice       set the address of the fee recipient
    /// @param  addr  address of fee recipient
    function setFeeRecipient(address addr)
		public
        onlyOwner
        returns(bool)
	{
        require(addr != address(0x00));

        // set the fee recipient
		feeRecipient = addr;

        return true;
    }

    /// @notice       set the fee rate
    /// @param  rate  rate of the fee (parts per 10000)
    function setFeeRate(uint rate)
		public
        onlyOwner
        returns(bool)
	{
        require(rate >= 0 && rate <= RATIO_PRECISE);

        // set the fee rate
		feeRate = rate;

        return true;
    }

    /// @notice  get count of supported tokens
	function getSupportedTokenCount()
		public
		constant
		returns(uint count)
	{
		return supportedTokens.length;
	}

    /// @notice         add token to exchange
    /// @param  symbol  symbol of token
    /// @param  addr    address of token contract
    function addToken(string symbol, address addr)
		public
        onlyOwner
        returns(bool)
	{
        require(addr != address(0x00));

		// check that the given token address is not already registered with
		// the Exchange
        require(!hasToken(addr));

		// add token to supported tokens map
        mapSupportedTokens[addr].symbol = symbol;
        mapSupportedTokens[addr].addr = addr;
        mapSupportedTokens[addr].timestamp = now;

		// add to tokens array
		supportedTokens.push(addr);

		// trigger event
        emit TokenAdded(symbol, addr, now);

        return true;
    }

    /// @notice       remove token from exchange
    /// @param  addr  address of token contract
    /// @return       true if token was deregistered
    function removeToken(address addr)
		public
        onlyOwner
        returns(bool)
	{
		// check that the given token address is registered with the Exchange
        require(hasToken(addr));

		// remove token from map of supported tokens
        delete mapSupportedTokens[addr];

		// remove from supported tokens array
		for (uint i = 0; i < supportedTokens.length; i++) {
			if (supportedTokens[i] == addr) {

				supportedTokens[i] = supportedTokens[supportedTokens.length-1];
				delete supportedTokens[supportedTokens.length-1];
				supportedTokens.length--;

				// trigger event
				emit TokenRemoved(addr, now);

				return true;
			}
		}

		return false;
    }

    /// @notice       check if token is registered
    /// @param  addr  address of token contract
    /// @return       true if `addr` is a registered token
    function hasToken(address addr)
		internal
		constant
		returns(bool)
	{
        Token storage token = mapSupportedTokens[addr];
        if (token.addr == address(0)) {
            return false;
        }
        return true;
    }

    /// @notice              fulfill trade
    /// @param makerToken    contract address that maker wants to sell
    /// @param takerToken    contract address that taker wants to sell
    /// @param makerAddress  maker wan address
    /// @param takerAddress  taker wan address
    /// @param makerAmount   amount that maker gives
    /// @param takerAmount   amount that taker gives
    function fulfillOrder(address makerToken, address takerToken, address makerAddress, address takerAddress, uint makerAmount, uint takerAmount)
		public
		// onlyOwner
		notHalted
		initialized
		returns(bool)
	{
        require(hasToken(makerToken));
        require(hasToken(takerToken));
        require(makerAddress != address(0x00));
        require(takerAddress != address(0x00));
        require(makerAmount > 0);
        require(takerAmount > 0);

        ERC20Protocol tokenA = ERC20Protocol(makerToken);
        ERC20Protocol tokenB = ERC20Protocol(takerToken);

        // check maker allowance
		if (tokenA.allowance(makerAddress, this) < makerAmount) {
			emit TradeFailed(0x1, tokenA.allowance(makerAddress, this));
			return false;
		}

        // check maker balance
		if (tokenA.balanceOf(makerAddress) < makerAmount) {
			emit TradeFailed(0x2, tokenA.balanceOf(makerAddress));
			return false;
		}

        // check taker allowance
		if (tokenB.allowance(takerAddress, this) < takerAmount) {
			emit TradeFailed(0x11, tokenB.allowance(takerAddress, this));
			return false;
		}

        // check taker balance
		if (tokenB.balanceOf(takerAddress) < takerAmount) {
			emit TradeFailed(0x12, tokenB.balanceOf(takerAddress));
			return false;
		}

        // calculate fees
        uint feeAmountA = makerAmount.mul(feeRate).div(RATIO_PRECISE);
        uint feeAmountB = takerAmount.mul(feeRate).div(RATIO_PRECISE);

        // transfer tokens to traders
        tokenA.transferFrom(makerAddress, takerAddress, makerAmount.sub(feeAmountA));
        tokenB.transferFrom(takerAddress, makerAddress, takerAmount.sub(feeAmountB));

		// transfer fees to recipient
        if (feeRate > 0) {
			tokenA.transferFrom(makerAddress, feeRecipient, feeAmountA);
			tokenB.transferFrom(takerAddress, feeRecipient, feeAmountB);
		}

		return true;
	}
}
