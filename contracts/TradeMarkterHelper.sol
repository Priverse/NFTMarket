// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./TradeMarket.sol";
pragma experimental ABIEncoderV2;

contract TradeMarketHelper is Ownable {
    struct Statistic {
        uint256 onSaleAmount;
        uint256 tradedAmount;
        uint256 totalAmount;
        uint256 minPrice;
        uint256 maxPrice;
    }
    
    constructor() public {
    }
    
    function getOrderOnSale(address _tradeMarket, address _userAddr) view public returns(TradeMarket.OrderInfo[] memory orderInfos) {
        TradeMarket tradeMarket = (TradeMarket)(_tradeMarket);
        uint256 number = tradeMarket.sellingOrdersNumber(_userAddr);
        uint256[] memory tokenIds = tradeMarket.getSellingOrders(_userAddr, 0, number);
        orderInfos = new TradeMarket.OrderInfo[](number);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            (uint256 id, address seller, address buyer, uint256 price, uint256 hangTime, uint256 dealTime) = tradeMarket.tokenOrderMap(tokenIds[i]);
            orderInfos[i] = TradeMarket.OrderInfo(id, seller, buyer, price, hangTime, dealTime);
        }
    }
    
    function getSoldOrders(address _tradeMarket, address _userAddr) view public returns(TradeMarket.OrderInfo[] memory orderInfos) {
        TradeMarket tradeMarket = (TradeMarket)(_tradeMarket);
        uint256 number = tradeMarket.getOrderNumOfSeller(_userAddr);
        orderInfos = new TradeMarket.OrderInfo[](number);
        for (uint256 i = 0; i < number; i++) {
            uint256 orderId = tradeMarket.sellerOrdersMap(_userAddr, i);
            (uint256 id, address seller, address buyer, uint256 price, uint256 hangTime, uint256 dealTime) = tradeMarket.dealedOrders(orderId);
            orderInfos[i] = TradeMarket.OrderInfo(id, seller, buyer, price, hangTime, dealTime);
        }
    }
    
    function getBoughtOrders(address _tradeMarket, address _userAddr) view public returns(TradeMarket.OrderInfo[] memory orderInfos) {
        TradeMarket tradeMarket = (TradeMarket)(_tradeMarket);
        uint256 number = tradeMarket.getOrderNumOfBuyer(_userAddr);
        orderInfos = new TradeMarket.OrderInfo[](number);
        for (uint256 i = 0; i < number; i++) {
            uint256 orderId = tradeMarket.buyerOrdersMap(_userAddr, i);
            (uint256 id, address seller, address buyer, uint256 price, uint256 hangTime, uint256 dealTime) = tradeMarket.dealedOrders(orderId);
            orderInfos[i] = TradeMarket.OrderInfo(id, seller, buyer, price, hangTime, dealTime);
        }
    }
    
    function getStaticInfo(address _tradeMarket) view public returns(Statistic memory statistic) {
        TradeMarket tradeMarket = (TradeMarket)(_tradeMarket);
        statistic.totalAmount = tradeMarket.totalAmount();
        statistic.tradedAmount = tradeMarket.getDealedOrderNumber();
        statistic.onSaleAmount = tradeMarket.getOrderCount();
        
        uint256 minPriceTokenId = tradeMarket.getMinPriceId();
        (,,,statistic.minPrice,,) = tradeMarket.tokenOrderMap(minPriceTokenId);
        
        uint256 maxPriceTokenId = tradeMarket.getMaxPriceId();
        (,,,statistic.maxPrice,,) = tradeMarket.tokenOrderMap(maxPriceTokenId);
    }
 }
