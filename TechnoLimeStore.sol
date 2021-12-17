//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

contract TechnoLimeStore{
    address public immutable owner;

    struct Product{
        uint id;
        string name;
        uint quantity;
    }
    uint private productIdCounter;
    Product[] private products;

    struct Order{
        uint id;
        address clientId;
        uint productId;
        uint orderTime;
        bool exists;
    }
    uint private orderIdCounter;

    uint private constant REFUND_TIME_SECONDS = 100;

    //client address => product id => order id
    mapping(address => mapping(uint => Order)) private clientOrders;
    mapping(uint => address[]) private productOrders;
    mapping(string => uint) private productFromName;

    event ProductCreated(
        uint productId, 
        string productName, 
        uint productQuantity);   
    event ProductUpdated(
        uint productId, 
        uint productQuantity);   
    event ProductPurchased(
        uint productId, 
        address clientAddress); 
    event ProductReturned(
        uint productId, 
        address clientAddress);     

    constructor(){
        owner = msg.sender;
    }

    modifier isOwner(){
        require(msg.sender == owner, "Current user is not the owner!");
        _;
    }
  
    modifier isNotOwner(){
        require(msg.sender != owner, "Current user is the owner!");
        _;
    }

    modifier ProductExists(uint productId) 
    {
         require(productId < products.length, "Product does not exist!");
        _;
    }   

    modifier PositiveQuantityValue(uint productQuantity) 
    {
         require(productQuantity > 0, "Zero product quantity!");
        _;
    }   

    function addProduct(string calldata productName, uint productQuantity) external isOwner PositiveQuantityValue(productQuantity){
        uint productId = productFromName[productName];      

        if(productId < products.length && compareStrings(products[productId].name, productName))
        {
            Product storage product = products[productFromName[productName]];
            product.quantity += productQuantity;
            
            emit ProductUpdated(productId, productQuantity);
        }else{
            Product memory newProduct = Product(productIdCounter, productName, productQuantity);
            products.push(newProduct);
            productFromName[productName] = productIdCounter;

            emit ProductCreated(productIdCounter, productName, productQuantity);
            productIdCounter++;        
        }
    }

    function buyProduct(uint productId) external ProductExists(productId) isNotOwner{
        Product storage product = products[productId];
        if(product.quantity == 0)
        {
            string memory errorMsg = string(abi.encodePacked("Product '", product.name, "' is out of stock!"));
            revert(errorMsg);                  
        }
        if(clientOrders[msg.sender][productId].exists){
            string memory errorMsg = string(abi.encodePacked("You already bought the product: '", product.name, "'!"));
            revert(errorMsg); 
        }
        product.quantity -=1;
        Order memory newOrder = Order(orderIdCounter, msg.sender, productId, block.timestamp, true);
        clientOrders[msg.sender][productId] = newOrder;
        productOrders[productId].push(msg.sender);
        
        emit ProductPurchased(productId, msg.sender);
        orderIdCounter++;
    }

    function returnProduct(uint productId) external ProductExists(productId){
        Product storage currentProduct = products[productId];
        Order memory currentOrder = clientOrders[msg.sender][productId];
        if(currentOrder.exists == false){
            string memory errorMsg = string(abi.encodePacked("No purchase of product: '", currentProduct.name, "' has been made by you!"));
            revert(errorMsg); 
        }
        if(currentOrder.orderTime + REFUND_TIME_SECONDS < block.timestamp)
        {
            revert("Return time over!"); 
        }
        currentProduct.quantity += 1;
        delete clientOrders[msg.sender][productId];
        removeProductOrder(productId);
        emit ProductReturned(productId, msg.sender);
    }

    function allProducts() external view returns (Product[] memory){
        return products;
    }

    function productPurchaseHistory(uint productId) external view ProductExists(productId) returns (uint, address[] memory){
        return (productId , productOrders[productId]);
    }

    function compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function removeProductOrder(uint productId) private {
        address[] storage _productOrders = productOrders[productId];
        for(uint i=0; i < _productOrders.length; i++){
            if(_productOrders[i] == msg.sender)
            {
                _productOrders[i] = _productOrders[_productOrders.length-1];
                _productOrders.pop();
            }
        }
    }
}
