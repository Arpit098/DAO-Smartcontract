// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    uint256 public price;
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, 1000000*10**decimals());
    }
    function setPrice(uint256 _newPrice) public onlyOwner {
        price = _newPrice;
    }
    function getPrice() public view returns (uint256) {
        return price;
    }
}
