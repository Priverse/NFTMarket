// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./StructuredLinkedList.sol";
import "./Minter.sol";


interface ITradeMarket {
    function tokenOrderMap(uint256 tokenId) view external returns(uint256, address, address, uint256, uint256, uint256);
}

contract TimeListInterface is IStructureInterface {
    ITradeMarket public tradeMarket;
    
    constructor(address _tradeMarket) public {
        tradeMarket = (ITradeMarket)(_tradeMarket);
    }
    
    function getValue(uint256 _tokenId) view public override returns(uint256) {
        (,,,,uint256 hangTime,) = tradeMarket.tokenOrderMap(_tokenId);
        return hangTime;
    }
}

contract TradeMarket is Minter, IStructureInterface {
    using SafeMath for uint256;
    using StructuredLinkedList for StructuredLinkedList.List;
    using EnumerableSet for EnumerableSet.UintSet;
    
    struct OrderInfo {
        uint256 id;
        address seller;
        address buyer;
        uint256 price;
        uint256 hangTime;
        uint256 dealTime;
    }

    uint256 public ProfitPercent = 5;
    uint256 constant public BasePercent = 100;
    
    uint256 public totalAmount = 0; 
    // uint256 public breedingOwnerFee = 0;
    // mapping(uint256 => uint256) public breedingCatFeeMap;
    // mapping(address => uint256) public breedingCatOwnerFeeMap;
    mapping(address => EnumerableSet.UintSet) private ownerOrdersMap;
    
    StructuredLinkedList.List private orderListByTime;
    StructuredLinkedList.List private orderListByPrice;
    mapping(uint256 => OrderInfo) public tokenOrderMap;
    
    OrderInfo[] public dealedOrders;
    mapping(address => uint256[]) public sellerOrdersMap;
    mapping(address => uint256[]) public buyerOrdersMap;
    
    IERC721 public nft;
    IERC20 public erc20;
    TimeListInterface public timeListInterface;
    
    modifier onlySeller(uint256 _tokenId) {
        require(orderListByPrice.nodeExists(_tokenId), "TradeMarket: order is NOT exist in order list.");
        require(tokenOrderMap[_tokenId].seller == msg.sender, "TradeMarket: only seller has the authority.");
        _;
    }
    
    constructor(address _nft, address _erc20) public {
        nft = (IERC721)(_nft);
        erc20 = (IERC20)(_erc20);
        timeListInterface = new TimeListInterface(address(this));
    }
    
    // 根据tokenID获得下单价格
    function getValue(uint256 _tokenId) view public override returns(uint256) {
        return tokenOrderMap[_tokenId].price;
    }
    
    // 添加订单，按价格从低到高排序
    function addOrder(uint256 _tokenId, uint256 _price) public {
        nft.transferFrom(msg.sender, address(this), _tokenId);  // approve firstly
        tokenOrderMap[_tokenId] = OrderInfo({id: _tokenId, seller: msg.sender, buyer: address(0), price: _price, hangTime: block.timestamp, dealTime: 0});
        
        uint256 nextIndexByPrice = orderListByPrice.getSortedSpot(address(this), _price);  // price descending order
        orderListByPrice.insertBefore(nextIndexByPrice, _tokenId);
        
        uint256 nextIndexByTime = orderListByTime.getSortedSpot(address(timeListInterface), block.timestamp);  // time descending order
        orderListByTime.insertBefore(nextIndexByTime, _tokenId);
        
        ownerOrdersMap[msg.sender].add(_tokenId);
    }
    
    function getOrderCount() view public returns(uint256) {
        return orderListByPrice.sizeOf();
    }
    
    // _startNodeId is excluded from the result
    function getOrderIdsByPrice(uint256 _startNodeId, uint256 _length, bool descending) view public returns(uint256[] memory orderIds) {
        orderIds = new uint256[](_length);
        uint256 index = 0;
        (bool exist, uint256 orderId) = descending ? orderListByPrice.getNextNode(_startNodeId) : orderListByPrice.getPreviousNode(_startNodeId);
        while(exist) {
            orderIds[index++] = orderId;
            if (index == _length) break;
            
            (exist, orderId) = descending ? orderListByPrice.getNextNode(orderId) : orderListByPrice.getPreviousNode(orderId);
        }
    }
    
    function getMinPriceId() view public returns(uint256) {
         (, uint256 orderId) = orderListByPrice.getNextNode(0);
         return orderId;
    }
    
    function getMaxPriceId() view public returns(uint256) {
        (, uint256 orderId) = orderListByPrice.getPreviousNode(0);
         return orderId;
    }
    
    function getSpotPriceId(uint256 _spotPrice) view public returns(uint256) {
        uint256 nextIndex = orderListByPrice.getSortedSpot(address(this), _spotPrice);
        return nextIndex;
    }
    
    function getOrderIdsByTime(uint256 _startNodeId, uint256 _length, bool descending) view public returns(uint256[] memory orderIds) {
        orderIds = new uint256[](_length);
        uint256 index = 0;
        (bool exist, uint256 orderId) = descending ? orderListByTime.getNextNode(_startNodeId) : orderListByTime.getPreviousNode(_startNodeId);
        while(exist) {
            orderIds[index++] = orderId;
            if (index == _length) break;
            
            (exist, orderId) = descending ? orderListByTime.getNextNode(orderId) : orderListByTime.getPreviousNode(orderId);
        }
    }
    
    function getMinTimeId() view public returns(uint256) {
         (, uint256 orderId) = orderListByTime.getNextNode(0);
         return orderId;
    }
    
    function getMaxTimeId() view public returns(uint256) {
        (, uint256 orderId) = orderListByTime.getPreviousNode(0);
         return orderId;
    }
    
    function getSpotTimeId(uint256 _spotTime) view public returns(uint256) {
        uint256 nextIndex = orderListByTime.getSortedSpot(address(timeListInterface), _spotTime);
        return nextIndex;
    }
    
    function cancelOrder(uint256 _tokenId) public onlySeller(_tokenId) {
        OrderInfo memory orderInfo = tokenOrderMap[_tokenId];
        nft.transferFrom(address(this), orderInfo.seller, _tokenId);
        orderListByPrice.remove(_tokenId);
        orderListByTime.remove(_tokenId);
        delete tokenOrderMap[_tokenId];
        ownerOrdersMap[msg.sender].remove(_tokenId);
    }
    
    function buyCat(uint256 _tokenId) public {
        require(orderListByPrice.nodeExists(_tokenId), "TradeMarket: order is NOT exist in order list.");
        uint256 platformFee = tokenOrderMap[_tokenId].price.mul(ProfitPercent).div(BasePercent);
        erc20.transferFrom(msg.sender, address(this), tokenOrderMap[_tokenId].price);
        erc20.transfer(tokenOrderMap[_tokenId].seller, tokenOrderMap[_tokenId].price.sub(platformFee));
        
        totalAmount = totalAmount.add(tokenOrderMap[_tokenId].price);
        
        nft.transferFrom(address(this), msg.sender, _tokenId);
        tokenOrderMap[_tokenId].buyer = msg.sender;
        tokenOrderMap[_tokenId].dealTime = block.timestamp;
        orderListByPrice.remove(_tokenId);
        orderListByTime.remove(_tokenId);
        processDealedOrder(_tokenId);
        ownerOrdersMap[tokenOrderMap[_tokenId].seller].remove(_tokenId);
        delete tokenOrderMap[_tokenId];
    }
    
    function processDealedOrder(uint256 _tokenId) private {
        dealedOrders.push(tokenOrderMap[_tokenId]);
        uint256 length = dealedOrders.length;
        sellerOrdersMap[tokenOrderMap[_tokenId].seller].push(length - 1);
        buyerOrdersMap[tokenOrderMap[_tokenId].buyer].push(length - 1);
    }
    
    function getDealedOrderNumber() view public returns(uint256) {
        return dealedOrders.length;
    }
    
    function getOrderNumOfSeller(address _seller)  view public returns(uint256) {
        return sellerOrdersMap[_seller].length;
    }
    
    function getOrderNumOfBuyer(address _buyer)  view public returns(uint256) {
        return buyerOrdersMap[_buyer].length;
    }
    
    function sellingOrdersNumber(address _owner) view public returns(uint256) {
        return ownerOrdersMap[_owner].length();
    }
    
    function getSellingOrders(address _owner, uint256 _fromId, uint256 _toId) view public returns(uint256[] memory ids) {
        uint256 length = ownerOrdersMap[_owner].length();
        require(_fromId < _toId && _toId <= length, "TradeMarket: index out of range!");
        
        ids = new uint256[](_toId - _fromId);
        uint256 count = 0;
        for (uint256 i = _fromId; i < _toId; i++) {
            ids[count++] = ownerOrdersMap[_owner].at(i);
        }
    }
    
    function setProfitPercent(uint256 _profitPercent) public onlyOwner {
        ProfitPercent = _profitPercent;
    }
    
    function withdraw(address _fundAddr) public onlyOwner {
        erc20.transfer(_fundAddr, erc20.balanceOf(address(this)));
    }
}