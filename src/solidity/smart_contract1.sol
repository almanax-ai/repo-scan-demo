pragma solidity ^0.4.15;

contract Overflow {
    uint private sellerBalance=0;
    
    function add(uint value) returns (bool){
        require(value + sellerBalance >= sellerBalance);
        sellerBalance += value; // possible overflow
        return true;
        // Fixed!
        // possible auditor assert
        // assert(sellerBalance >= value); 
    } 

    function safe_add(uint value) returns (bool){
        require(value + sellerBalance >= sellerBalance);
        sellerBalance += value; 
    } 
}
