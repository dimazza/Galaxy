pragma solidity ^0.4.17;

interface token {
    function transfer(address receiver, uint amount);
    function burn(uint256 _value);
}

contract Crowdsale {
    address public beneficiary;
    uint public fundingGoal;
    uint public amountRaised;
    uint public deadline;
    uint public firstStage;
    uint public secondStage;
    uint public priceFirstStage;
    uint public priceSecondStage;
    uint public priceLastStage;
    uint public tokensForSale;
    uint public tokensForBurn;
    token public tokenReward;
    mapping(address => uint256) public balanceOf;
    bool fundingGoalReached = false;
    bool crowdsaleClosed = false;

    event GoalReached(address recipient, uint totalAmountRaised);
    event FundTransfer(address backer, uint amount, bool isContribution);


    function Crowdsale(
        address ifSuccessfulSendTo,
        uint tokensForBeneficiary,
        uint fundingGoalInEthers,
        uint durationFirstStageInMinutes,
        uint durationSecondStageInMinutes,
        uint durationInMinutes,
        uint etherCostOfEachTokenFirstStage,
        uint etherCostOfEachTokenSecondStage,
        uint etherCostOfEachTokenLateStage,
        uint forSale,
        uint forBurn,
        address addressOfTokenUsedAsReward
    ) {
        beneficiary = ifSuccessfulSendTo;
        tokenReward.transfer(beneficiary, tokensForBeneficiary);
        FundTransfer(beneficiary, tokensForBeneficiary, true);
        fundingGoal = fundingGoalInEthers * 1 ether;
        tokensForSale = forSale;
        tokensForBurn = forBurn;
        uint start = now;
        firstStage = start + durationFirstStageInMinutes * 1 minutes;
        secondStage = start + durationSecondStageInMinutes * 1 minutes;
        deadline = start + durationInMinutes * 1 minutes;
        priceFirstStage = etherCostOfEachTokenFirstStage * 1 ether;
        priceSecondStage = etherCostOfEachTokenSecondStage * 1 ether;
        priceLastStage = etherCostOfEachTokenLateStage * 1 ether;
        tokenReward = token(addressOfTokenUsedAsReward);
    }

    function () payable {
        require(!crowdsaleClosed);
        uint amount = msg.value;
        uint price = 0;
        if (now < firstStage)
            price = priceFirstStage;
        else {
                if (now < secondStage)
                    price = priceSecondStage;
                else
                    price = priceLastStage;
        }
        uint tokens = amount / price;
        require(tokens <= tokensForSale);
        balanceOf[msg.sender] += amount;
        amountRaised += amount;
        tokenReward.transfer(msg.sender, tokens);
        tokensForSale -= tokens;
        FundTransfer(msg.sender, amount, true);
    }

    modifier afterDeadline() { if (now >= deadline) _; }

    /**
     * Check if goal was reached
     *
     * Checks if the goal or time limit has been reached and ends the campaign
     */
    function checkGoalReached() afterDeadline {
        if (amountRaised >= fundingGoal){
            fundingGoalReached = true;
            GoalReached(beneficiary, amountRaised);
        }
        crowdsaleClosed = true;
    }

    /**
     * Withdraw the funds
     *
     * Checks to see if goal or time limit has been reached, and if so, and the funding goal was reached,
     * sends the entire amount to the beneficiary. If goal was not reached, each contributor can withdraw
     * the amount they contributed.
     */
    function safeWithdrawal() afterDeadline {
        if (!fundingGoalReached) {
            uint amount = balanceOf[msg.sender];
            balanceOf[msg.sender] = 0;
            if (amount > 0) {
                if (msg.sender.send(amount)) {
                    FundTransfer(msg.sender, amount, false);
                } else {
                    balanceOf[msg.sender] = amount;
                }
            }
        }

        if (fundingGoalReached && beneficiary == msg.sender) {
            if (beneficiary.send(amountRaised)) {
                FundTransfer(beneficiary, amountRaised, false);
                tokenReward.burn(tokensForSale + tokensForBurn);
            } else {
                //If we fail to send the funds to beneficiary, unlock funders balance
                fundingGoalReached = false;
            }
        }
    }
}

