pragma solidity ^0.4.15;
// Testing this contract with a new branch.
contract Overflow {
    uint private sellerBalance=0;
    
    function add(uint value) returns (bool){
        sellerBalance += value; // possible overflow

        // possible auditor assert
        // assert(sellerBalance >= value); 
    } 

    function safe_add(uint value) returns (bool){
        require(value + sellerBalance >= sellerBalance);
        sellerBalance += value; 
    } 
}
