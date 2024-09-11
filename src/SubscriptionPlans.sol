// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SubscriptionPlans {
    uint256 public nextPlanId;

    struct Plan {
        address merchant;
        address token;
        uint256 amount;
        uint256 frequency;
    }

    struct Subscription {
        address subscriber;
        address mentor;
        uint256 start;
        uint256 nextPayment;
    }

    mapping(uint256 => Plan) public plans;
    mapping(address => mapping(uint256 => Subscription)) public subscriptions;

    event PlanCreated(address merchant);
    event PlanDeleted(address merchant, uint256 planId, uint256 date);
    event SubscriptionCreated(address subscriber, address mentor, uint256 planId, uint256 date);
    event SubscriptionCancelled(address subscriber, uint256 planId, uint256 date);
    event PaymentSent(address from, address to, address to2, uint256 amount, uint256 planId, uint256 date);

    function createPlan(address token, uint256 amount, uint256 frequency) internal {
        require(token != address(0), "address cannot be null address");
        require(amount > 0, "amount needs to be > 0");
        require(frequency > 0, "frequency needs to be > 0");

        plans[nextPlanId] = Plan(msg.sender, token, amount, frequency);
        nextPlanId++;
        emit PlanCreated(msg.sender);
    }

    function deletePlan(uint256 planId) internal {
        Plan memory plan = plans[planId];
        require(plan.merchant == msg.sender, "Caller is not the merchant");
        require(planId < nextPlanId, "Plan does not exist");
        
        delete plans[planId];
        nextPlanId--;
        
        emit PlanDeleted(msg.sender, planId, block.timestamp);
    }

    function subscribe(uint256 planId, address mentor) internal {
        IERC20 token = IERC20(plans[planId].token);
        Plan storage plan = plans[planId];
        require(plan.merchant != address(0), "this plan does not exist");
        require(plan.token != address(0), 'Invalid token address');

        token.transferFrom(msg.sender, plan.merchant, plan.amount * 20 / 100); // Owner receives 20%
        token.transferFrom(msg.sender, mentor, plan.amount * 80 / 100); // Menotr receives 80%

        emit PaymentSent(msg.sender, mentor, plan.merchant, plan.amount, planId, block.timestamp);

        // WILL POSSIBLY IMPELEMENT THIS LOGIC INSTEAD
        // uint256 amount = plan.amount;
        // try token.transferFrom(msg.sender, plan.merchant, amount * 20 / 100) {
        //     token.transferFrom(msg.sender, mentor, amount * 80 / 100);
        // } catch {
        //     // If either transfer fails, revert and refund any previously transferred amounts
        //     token.transferFrom(plan.merchant, msg.sender, amount * 20 / 100);
        //     token.transferFrom(mentor, msg.sender, amount * 80 / 100);
        //     revert("Transfer failed");
        // }

        subscriptions[msg.sender][planId] = Subscription(msg.sender, mentor, block.timestamp, block.timestamp + plan.frequency);
        emit SubscriptionCreated(msg.sender, mentor, planId, block.timestamp);
    }

    function cancel(uint256 planId) internal {
        Subscription storage subscription = subscriptions[msg.sender][planId];
        require(subscription.subscriber != address(0), "this subscription does not exist");
        delete subscriptions[msg.sender][planId];
        emit SubscriptionCancelled(msg.sender, planId, block.timestamp);
    }

    function pay(address subscriber, uint256 planId) internal {
        Subscription storage subscription = subscriptions[subscriber][planId];
        Plan storage plan = plans[planId];
        IERC20 token = IERC20(plan.token);
        require(subscription.subscriber != address(0), "this subscription does not exist");
        require(block.timestamp > subscription.nextPayment, "not due yet");

        token.transferFrom(msg.sender, plan.merchant, plan.amount * 20 / 100); // Owner receives 20%
        token.transferFrom(msg.sender, subscription.mentor, plan.amount * 80 / 100); // Mentor receives 80%

        emit PaymentSent(subscriber, subscription.mentor, plan.merchant, plan.amount, planId, block.timestamp);
        subscription.nextPayment = subscription.nextPayment + plan.frequency;
    }
}
