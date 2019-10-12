pragma solidity >=0.4.21 <0.6.0;

import "./TetherToken.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract OBSInvest is Ownable {
    using SafeMath for uint256;

    enum State { Init, Active, Refunding, Closed }

    TetherToken public usdtToken;
    uint256 public roundInterval = 7 days;
    uint256 public defaultCap = 10000000000;  
    uint256 public capIncrease = 30; 
    uint256 public interestRate = 14; 
    uint256 public withdrawFee = 2; 
    uint256 public refundRate = 65;
    uint256 public totalAmount;
    uint256 public roundIndex = 0; 
    mapping(address => mapping(uint256 => uint256)) public investRecords; 
    mapping(uint256 => Round) public roundInfo; 
    mapping(address => uint256) public waitingQueue; 
    mapping(uint256 => address[]) public waitingUsers;
    mapping(address => uint256) public reDepositRound; 
    mapping(uint256 => address[]) public reDepositUsers; 

    State public state; 

    struct Round {
        uint256 startTime;
        uint256 endTime;
        uint256 capInUsdtWei;
        uint256 investAmountInUsdtWei;
        uint256 index;
    }

    event StateChanged(State from, State to);
    event Received(address sender, uint256 amount);
    event Invested(address investor, uint256 amount, uint256 roundIndex);
    event RefundDone(uint256 size, uint256 amount);
    event WithdrawDone(uint256 size, uint256 amount);
    event MarkReInvested(address investor, uint256 roundIndex);
    event ReInvested(address investor, uint256 roundIndex, uint256 amount);
    event ReInvestDone(uint256 size);
    event WaitingQueueDone(uint256 size);

    constructor(address tetherToken) public {
      usdtToken = TetherToken(tetherToken);
      state = State.Init;
    }

    function start() onlyOwner public {
      require(state == State.Init);
      roundIndex++;
      roundInfo[roundIndex] = Round(now, now + roundInterval, defaultCap, 0, roundIndex);
      state = State.Active;
      emit StateChanged(State.Init, State.Active);
    }

    function deposit(uint256 usdtWeiAmount) public {
        require(state == State.Active);
        require(usdtToken.allowance(msg.sender, address(this)) >= usdtWeiAmount);

        usdtToken.transferFrom(msg.sender, address(this), usdtWeiAmount);

        _internalDeposit(msg.sender, usdtWeiAmount);
    }


    function adminDeposit(address investor, uint256 usdtWeiAmount) public onlyOwner {
        require(state == State.Active);
        _internalDeposit(investor, usdtWeiAmount);
    }


    function batchRefund(address[] memory investors) onlyOwner public {
        require(state == State.Refunding);

        uint256 batchRefundAmount;

        for (uint256 i = 0; i < investors.length; i++) {
            address currentInvestor = investors[i];
            uint256 totalRefundAmount = investRecords[currentInvestor][roundIndex];
            if (roundIndex >= 2 && investRecords[currentInvestor][roundIndex - 1] > 0) {
                uint256 refundAmount = investRecords[currentInvestor][roundIndex - 1].mul(refundRate).div(100);
                totalRefundAmount = totalRefundAmount.add(refundAmount);
                investRecords[currentInvestor][roundIndex - 1] = 0;
            }

            if (roundIndex >= 3 && investRecords[currentInvestor][roundIndex - 2] > 0) {
                uint256 refundAmount = investRecords[currentInvestor][roundIndex - 2].mul(refundRate).div(100);
                totalRefundAmount = totalRefundAmount.add(refundAmount);
                investRecords[currentInvestor][roundIndex - 2] = 0;
            }

            totalAmount = totalAmount.sub(totalRefundAmount);
            investRecords[currentInvestor][roundIndex] = 0;

            batchRefundAmount = batchRefundAmount.add(totalRefundAmount);
            usdtToken.transfer(currentInvestor, totalRefundAmount);
        }

        emit RefundDone(investors.length, batchRefundAmount);
    }


    function batchWithdraw(address[] memory investors) onlyOwner public {
        require(state == State.Active);
        require(roundIndex >= 4);

        uint256 batchWithdrawAmount;

        for (uint256 i = 0; i < investors.length; i++) {
            address currentInvestor = investors[i];
            uint256 principle = investRecords[investors[i]][roundIndex - 3];
            if (principle == 0) continue;
            uint256 interest = principle.mul(interestRate).div(100);
            uint256 withdrawAmount = principle.add(interest);
            uint256 withdrawFeeAmount = withdrawAmount.mul(withdrawFee).div(100);
            uint256 pureWithdraw = withdrawAmount.sub(withdrawFeeAmount);

            totalAmount = totalAmount.sub(pureWithdraw);
            investRecords[investors[i]][roundIndex - 3] = 0;
            usdtToken.transfer(currentInvestor, pureWithdraw);
            batchWithdrawAmount = batchWithdrawAmount.add(pureWithdraw);
        }

        emit WithdrawDone(investors.length, batchWithdrawAmount);
    }

    function reDeposit() public {
        require(state == State.Active);
        require(roundIndex >= 3);
        require(investRecords[msg.sender][roundIndex - 2] > 0);

        reDepositRound[msg.sender] = roundIndex + 1;
        reDepositUsers[roundIndex + 1].push(msg.sender);

        emit MarkReInvested(msg.sender, roundIndex + 1);
    }

    function adminReDeposit(address[] memory investors) onlyOwner public {
        require(state == State.Active);
        require(roundIndex >= 4);
        require(reDepositUsers[roundIndex].length > 0);

        for (uint256 i = 0; i < investors.length; i++) {
            address currentInvestor = investors[i];
            if (reDepositRound[currentInvestor] == 0) continue;
            uint256 principle = investRecords[currentInvestor][roundIndex - 3];
            uint256 interest = principle.mul(interestRate).div(100);
            uint256 amountToInvest = principle.add(interest);

            reDepositRound[currentInvestor] = 0;
            investRecords[currentInvestor][roundIndex] = investRecords[currentInvestor][roundIndex].add(amountToInvest);
            roundInfo[roundIndex].investAmountInUsdtWei = roundInfo[roundIndex].investAmountInUsdtWei.add(amountToInvest);
            investRecords[currentInvestor][roundIndex - 3] = 0;

            emit ReInvested(currentInvestor, roundIndex, amountToInvest);
        }

        emit ReInvestDone(investors.length);

    }


    function adminDepositForWaitingUsers(address[] memory investors) onlyOwner public {
        require(state == State.Active);
        require(waitingUsers[roundIndex].length > 0);

        for (uint256 i = 0; i < investors.length; i++) {
            address currentInvestor = investors[i];
            uint256 waitingAmount = waitingQueue[currentInvestor];
            if (waitingAmount == 0) continue;
            waitingQueue[currentInvestor] = 0;
            _internalDepositWithoutTransfer(currentInvestor, waitingAmount);
        }

        emit WaitingQueueDone(investors.length);
    }

    function adminStateCheck() onlyOwner public {
        require(state == State.Active);
        if (now > roundInfo[roundIndex].endTime) {
            if (roundInfo[roundIndex].investAmountInUsdtWei < roundInfo[roundIndex].capInUsdtWei) {
                state = State.Refunding;

                emit StateChanged(State.Active, State.Refunding);
            } else {
                _startNewRound();
            }
        }
    }

    function adminClose() onlyOwner public {
        require(state == State.Refunding);

        state = State.Closed;
        uint256 balance = usdtToken.balanceOf(address(this));
        totalAmount = totalAmount.sub(balance);
        usdtToken.transfer(msg.sender, balance);

        emit StateChanged(State.Refunding, State.Closed);
    }

    function getWaitingUsers() public view returns (address[] memory)  {
        return waitingUsers[roundIndex];
    }

    function getReDepositUsers() public view returns (address[] memory) {
        return reDepositUsers[roundIndex];
    }

    function kill() onlyOwner public {
        require(state == State.Closed);

        selfdestruct(msg.sender);
    }


    function _internalDeposit(address investor, uint256 usdtWeiAmount) private {
        totalAmount = totalAmount.add(usdtWeiAmount);

        require(usdtToken.balanceOf(address(this)) >= totalAmount);

        emit Received(investor, usdtWeiAmount);


        if (investor == owner()) return;

        if (now > roundInfo[roundIndex].endTime) {
            if (roundInfo[roundIndex].investAmountInUsdtWei < roundInfo[roundIndex].capInUsdtWei) {
                state = State.Refunding;
            }
        }

        _internalDepositWithoutTransfer(investor, usdtWeiAmount);

        if (now > roundInfo[roundIndex].endTime && state != State.Refunding) {
            _startNewRound();
        }
    }

    function _internalDepositWithoutTransfer(address investor, uint256 usdtWeiAmount) private {
        if (roundInfo[roundIndex].investAmountInUsdtWei.add(usdtWeiAmount) > roundInfo[roundIndex].capInUsdtWei && state != State.Refunding) {
            uint256 investAmount = 0;

            if (roundInfo[roundIndex].investAmountInUsdtWei < roundInfo[roundIndex].capInUsdtWei) {
                investAmount = roundInfo[roundIndex].capInUsdtWei.sub(roundInfo[roundIndex].investAmountInUsdtWei);
            }

            investRecords[investor][roundIndex] = investRecords[investor][roundIndex].add(investAmount);
            roundInfo[roundIndex].investAmountInUsdtWei = roundInfo[roundIndex].investAmountInUsdtWei.add(investAmount);
            emit Invested(investor, investAmount, roundIndex);

            _addToWaitingQueue(investor, usdtWeiAmount.sub(investAmount));
        } else {
            if (waitingUsers[roundIndex + 1].length > 0) {
                _addToWaitingQueue(investor, usdtWeiAmount);
            } else {
                investRecords[investor][roundIndex] = investRecords[investor][roundIndex].add(usdtWeiAmount);
                roundInfo[roundIndex].investAmountInUsdtWei = roundInfo[roundIndex].investAmountInUsdtWei.add(usdtWeiAmount);
                emit Invested(investor, usdtWeiAmount, roundIndex);
            }
        }
    }

    function _addToWaitingQueue(address investor, uint256 usdtWeiAmount) private {
        if (waitingQueue[investor] == 0) {
            waitingUsers[roundIndex + 1].push(investor);
        }
        waitingQueue[investor] = waitingQueue[investor].add(usdtWeiAmount);
    }

    function _startNewRound() private {
      roundIndex++;
      uint256 capToIncrease = roundInfo[roundIndex - 1].capInUsdtWei.mul(capIncrease).div(100);
      roundInfo[roundIndex] = Round(now, now + roundInterval, roundInfo[roundIndex - 1].capInUsdtWei.add(capToIncrease), 0, roundIndex);
    }

}