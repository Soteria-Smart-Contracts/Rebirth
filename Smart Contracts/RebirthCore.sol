// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

contract RebirthCore{
    //Variable Declarations
    address SRBH_Admin;

    //Struct Declarations

    //Mapping Declarations

    //Event Declarations

    //Modifier Declarations
    modifier onlyOwner() {
        require(msg.sender == SRBH_Admin);
        _;
    }

    //Constructor
    constructor() public {
        SRBH_Admin = msg.sender;
    }

    //OnlyOwner Functions
    function setAdmin(address _newAdmin) public onlyOwner {
        SRBH_Admin = _newAdmin;
    }
}