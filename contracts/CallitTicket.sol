// SPDX-License-Identifier: UNLICENSED
// ref: https://ethereum.org/en/history
//  code size limit = 24576 bytes (a limit introduced in Spurious Dragon _ 2016)
//  code size limit = 49152 bytes (a limit introduced in Shanghai _ 2023)
// model ref: LUSDST.sol (081024)
// NOTE: uint type precision ...
//  uint8 max = 255
//  uint16 max = ~65K -> 65,535
//  uint32 max = ~4B -> 4,294,967,295
//  uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
pragma solidity ^0.8.24;

// inherited contracts
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // deploy
// import "@openzeppelin/contracts/access/Ownable.sol"; // deploy

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract CallitTicket is ERC20, Ownable {
    string public tVERSION = '0.1';
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    address public VAULT_ADDR;
    event MintedForPriceParity(address _receiver, uint256 _amount);
    event BurnForWinClaim(address _account, uint256 _amount);

    constructor(uint256 _initSupply, address _vault, string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {
        VAULT_ADDR = _vault;
        // NOTE: uint64 = ~18,000Q max
        _mint(VAULT_ADDR, _initSupply * 10**uint8(decimals())); // 'emit Transfer'
    }

    function mintForPriceParity(address _receiver, uint256 _amount) external onlyOwner() {
        _mint(_receiver, _amount);
        emit MintedForPriceParity(_receiver, _amount);
    }
    function burnForWinLoseClaim(address _account) external onlyOwner() {
        _burn(_account, balanceOf(_account)); // NOTE: checks _balance[_account]
        emit BurnForWinClaim(_account, balanceOf(_account));
    }
}