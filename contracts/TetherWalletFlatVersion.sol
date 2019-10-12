
// File: contracts/TetherToken.sol

pragma solidity >=0.4.21 <0.6.0;

contract TetherToken {
    uint public _totalSupply;
    function totalSupply() public view returns (uint);
    function balanceOf(address who) public view returns (uint);
    function transfer(address to, uint value) public;
    function allowance(address owner, address spender) public view returns (uint);
    function transferFrom(address from, address to, uint value) public;
    function approve(address spender, uint value) public;
}

// File: contracts/SafeMath.sol

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

// File: contracts/TetherWallet.sol

pragma solidity >=0.4.21 <0.6.0;



/**
 *  @dev 任何人都可以将自己的 ERC20 USDT 转入转出
 */
contract TetherWallet {
    using SafeMath for uint256;

    TetherToken public usdtToken;

    mapping(address => uint256) private balances;

    event Received(address indexed sender, uint256 amount);
    event Withdrawn(address indexed to, uint256 value);

    constructor(address tetherToken) public {
        usdtToken = TetherToken(tetherToken);
    }

    /**
     * @dev 存入一定数量的 ERC20 USDT
     * 在调用此方法钱，请先调用 ERC20 USDT 合约的 approve 方法进行授权
     */
    function deposit(uint256 usdtWeiAmount) public {
        require(usdtToken.allowance(msg.sender, address(this)) >= usdtWeiAmount);

        usdtToken.transferFrom(msg.sender, address(this), usdtWeiAmount);

        balances[msg.sender] = balances[msg.sender].add(usdtWeiAmount);

        emit Received(msg.sender, usdtWeiAmount);
    }

    /**
     * @dev 将一定数量的 ERC20 USDT 转出到指定地址
     */
    function withdraw(address to, uint256 usdtWeiAmount) public {
        require(balances[msg.sender] > usdtWeiAmount);

        balances[msg.sender] = balances[msg.sender].sub(usdtWeiAmount);

        usdtToken.transfer(to, usdtWeiAmount);

        emit Withdrawn(to, usdtWeiAmount);
    }

    /**
     * @dev 将一定数量的 ERC20 USDT 提现到自己钱包
     */
    function withdraw(uint256 usdtWeiAmount) public {
        require(balances[msg.sender] > usdtWeiAmount);

        withdraw(msg.sender, usdtWeiAmount);
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }
}
