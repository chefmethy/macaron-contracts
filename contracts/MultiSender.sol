/*
$$\      $$\  $$$$$$\   $$$$$$\   $$$$$$\  $$$$$$$\   $$$$$$\  $$\   $$\  $$$$$$\  $$\      $$\  $$$$$$\  $$$$$$$\  
$$$\    $$$ |$$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\ $$  __$$\ $$$\  $$ |$$  __$$\ $$ | $\  $$ |$$  __$$\ $$  __$$\ 
$$$$\  $$$$ |$$ /  $$ |$$ /  \__|$$ /  $$ |$$ |  $$ |$$ /  $$ |$$$$\ $$ |$$ /  \__|$$ |$$$\ $$ |$$ /  $$ |$$ |  $$ |
$$\$$\$$ $$ |$$$$$$$$ |$$ |      $$$$$$$$ |$$$$$$$  |$$ |  $$ |$$ $$\$$ |\$$$$$$\  $$ $$ $$\$$ |$$$$$$$$ |$$$$$$$  |
$$ \$$$  $$ |$$  __$$ |$$ |      $$  __$$ |$$  __$$< $$ |  $$ |$$ \$$$$ | \____$$\ $$$$  _$$$$ |$$  __$$ |$$  ____/ 
$$ |\$  /$$ |$$ |  $$ |$$ |  $$\ $$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |\$$$ |$$\   $$ |$$$  / \$$$ |$$ |  $$ |$$ |      
$$ | \_/ $$ |$$ |  $$ |\$$$$$$  |$$ |  $$ |$$ |  $$ | $$$$$$  |$$ | \$$ |\$$$$$$  |$$  /   \$$ |$$ |  $$ |$$ |      
\__|     \__|\__|  \__| \______/ \__|  \__|\__|  \__| \______/ \__|  \__| \______/ \__/     \__|\__|  \__|\__|      
*/

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^ 0.4.0;

/**
 * @title MacaronMultiSender, support BNB and BEP20 Tokens
*/

library SafeMath {
    function mul(uint a, uint b) internal pure returns(uint) {
        uint c = a * b;
        require(a == 0 || c / a == b);
        return c;
    }
    function div(uint a, uint b) internal pure returns(uint) {
        require(b > 0);
        uint c = a / b;
        require(a == b * c + a % b);
        return c;
    }
    function sub(uint a, uint b) internal pure returns(uint) {
        require(b <= a);
        return a - b;
    }
    function add(uint a, uint b) internal pure returns(uint) {
        uint c = a + b;
        require(c >= a);
        return c;
    }
    function max64(uint64 a, uint64 b) internal pure returns(uint64) {
        return a >= b ? a: b;
    }
    function min64(uint64 a, uint64 b) internal pure returns(uint64) {
        return a < b ? a: b;
    }
    function max256(uint256 a, uint256 b) internal pure returns(uint256) {
        return a >= b ? a: b;
    }
    function min256(uint256 a, uint256 b) internal pure returns(uint256) {
        return a < b ? a: b;
    }
}

contract Ownable {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    function transferOwnership(address newOwner) onlyOwner public {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
}

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract MacaronSwapMultiSenderv2 is Ownable {
    using SafeMath for uint;

    IBEP20 public macaronToken;
    address public treasuryAddress;
    uint public txFee = 1 ether;
    uint public txFeeForToken = 0.1 ether;
    uint public minHodlAmount = 100 ether;

    uint public maxToCountForBNB = 1000;
    uint public maxToCountForToken = 1000;

    event LogBNBBulkSent(uint256 total);
    event LogTokenBulkSent(address token, uint256 total);

    constructor (
        IBEP20 _macaronToken
    ) public {
        macaronToken = _macaronToken;
        treasuryAddress = msg.sender;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyHodler() {
        require(macaronToken.balanceOf(msg.sender) > minHodlAmount, "Macaron amount under required Min HODL!");
        _;
    }
    
    /**
     * @notice Withdraw unexpected tokens sent to the owner
     */
    function inCaseTokensGetStuck(address _token) external onlyOwner {
        uint256 amount = IBEP20(_token).balanceOf(address(this));
        IBEP20(_token).transfer(msg.sender, amount);
    }

    function setTreasuryAddress(address _addr) external onlyOwner {
        require(_addr != address(0));
        treasuryAddress = _addr;
    }

    function setTxFee(uint _feeAsBNB) onlyOwner public {
        txFee = _feeAsBNB;
    }
    
    function setTxFeeForToken(uint _feeAsMacaron) onlyOwner public {
        txFeeForToken = _feeAsMacaron;
    }
    
    function setMaxToCountForBNB(uint _count) onlyOwner public {
        maxToCountForBNB = _count;
    }
    
    function setMaxToCountForToken(uint _count) onlyOwner public {
        maxToCountForToken = _count;
    }

    function ethSendSameValue(address[] _to, uint _value) external payable onlyHodler {

        uint sendAmount = _to.length.mul(_value);
        uint remainingValue = msg.value;

        require(remainingValue >= sendAmount.add(txFee), "insufficient amount!");
        require(_to.length <= maxToCountForBNB, "number of to addresses larger than expected");

        require(treasuryAddress.send(txFee));

        for (uint8 i = 0; i < _to.length; i++) {
            remainingValue = remainingValue.sub(_value);
            require(_to[i].send(_value));
        }

        emit LogBNBBulkSent(msg.value);
    }

    function ethSendDifferentValue(address[] _to, uint[] _value) external payable onlyHodler {
        
        uint remainingValue = msg.value;
        uint sendAmount = 0;
        for(uint i = 0; i < _to.length; i++) {
         sendAmount = sendAmount.add(_value[i]);
        }

        require(remainingValue >= sendAmount.add(txFee), "insufficient amount!");
        require(_to.length <= maxToCountForBNB, "number of to addresses larger than expected");
        require(_to.length == _value.length, "_to and _value counts not equal!");

        require(treasuryAddress.send(txFee));

        for (uint j = 0; j < _to.length; j++) {
            remainingValue = remainingValue.sub(_value[j]);
            require(_to[j].send(_value[j]));
        }
        emit LogBNBBulkSent(msg.value);

    }

    function tokenSendSameValue(address _tokenAddress, address[] _to, uint _value) external onlyHodler {

        require(_to.length <= maxToCountForToken, "number of to addresses larger than expected");

        uint256 sendAmount = _to.length.mul(_value);

        IBEP20 token = IBEP20(_tokenAddress);
        
        if(token == macaronToken)
            require(token.balanceOf(msg.sender) >= sendAmount.add(txFeeForToken), "insufficient amount");
        else
            require(token.balanceOf(msg.sender) >= sendAmount, "insufficient amount");
            
        macaronToken.transferFrom(msg.sender, treasuryAddress, txFeeForToken);
        
        for (uint i = 0; i < _to.length; i++) {
            token.transferFrom(msg.sender, _to[i], _value);
        }

        emit LogTokenBulkSent(_tokenAddress, sendAmount);

    }

    function tokenSendDifferentValue(address _tokenAddress, address[] _to, uint[] _value) external onlyHodler {
        
        require(_to.length == _value.length);
        require(_to.length <= maxToCountForToken, "number of to addresses larger than expected");

        uint sendAmount = 0;
        for(uint i = 0; i < _to.length; i++) {
         sendAmount = sendAmount.add(_value[i]);
        }
        
        IBEP20 token = IBEP20(_tokenAddress);

        if(token == macaronToken)
            require(token.balanceOf(msg.sender) >= sendAmount.add(txFeeForToken), "insufficient amount");
        else
            require(token.balanceOf(msg.sender) >= sendAmount, "insufficient amount");
            
        for (uint j = 0; j < _to.length; j++) {
            token.transferFrom(msg.sender, _to[j], _value[j]);
        }
        
        emit LogTokenBulkSent(_tokenAddress, sendAmount);
    }
}