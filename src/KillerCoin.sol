//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KillerCoin is ERC20Burnable, Ownable{
    error KillerCoin__InValidAddress();
    error KillerCoin__InValidAmount();

    constructor() Ownable(msg.sender) ERC20("KillerCoin","KILL"){}

    function mint(address _to, uint256 _amount) public onlyOwner returns(bool){
        if(_to == address(0)){
            revert KillerCoin__InValidAddress();
        }
        if(_amount == 0){
            revert KillerCoin__InValidAmount();
        }
        _mint(_to,_amount);
        return true;
    }

    function burn(uint256 _amount) public onlyOwner override{
        if(msg.sender == address(0)){
            revert KillerCoin__InValidAddress();
        }
        if(_amount == 0){
            revert KillerCoin__InValidAmount();
        }
        super.burn(_amount);
    }
}