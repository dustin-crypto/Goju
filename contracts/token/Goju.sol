pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";  // OpenZeppelin package contains implementation of the ERC 20 standard, which our NFT smart contract will inherit

contract Goju is Ownable, ERC20 {
    //  uint constant _initial_supply = 100 * (10**18);  // setting variable for how many of your own tokens are initially put into your wallet, feel free to edit the first number but make sure to leave the second number because we want to make sure our supply has 18 decimals

    /* ERC 20 constructor takes in 2 strings, feel free to change the first string to the name of your token name, and the second string to the corresponding symbol for your custom token name */
    constructor() ERC20("GojuSatoru", "Goju") {
        // _mint(msg.sender, _initial_supply);
    }

    function decimals() public view override returns (uint8) {
        return 6;
    }

    function mint(address account, uint256 amount) public onlyOwner {
      _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}
