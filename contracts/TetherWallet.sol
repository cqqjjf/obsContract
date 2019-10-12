pragma solidity >=0.4.21 <0.6.0;

import "./TetherToken.sol";
import "./SafeMath.sol";

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