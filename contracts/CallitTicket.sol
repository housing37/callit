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

interface ICallitConfig { // don't need everything in ICallitConfig.sol
    function ADDR_VAULT() external view returns(address);
    function ADDR_FACT() external view returns(address);
}
interface ICallitVault {
    function deposit(address _depositor) external payable;
}

contract CallitTicket is ERC20, Ownable {
    string public tVERSION = '0.5';
    address public ADDR_CONFIG; // set via constructor()
    ICallitConfig private CONF = ICallitConfig(ADDR_CONFIG);

    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    // address public ADDR_VAULT;
    // address public ADDR_FACT;
    event MintedForPriceParity(address _receiver, uint256 _amount);
    event BurnForWinLoseClaim(address _account, uint256 _amount);

    // constructor(uint256 _initSupply, address _vault, address _fact, string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(_vault) {
    //     VAULT_ADDR = _vault;
    //     FACT_ADDR = _fact;
    //     // NOTE: uint64 = ~18,000Q max
    //     _mint(VAULT_ADDR, _initSupply * 10**uint8(decimals())); // 'emit Transfer'
    // }
    constructor(uint256 _initSupply, string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(address(this)) {
        ADDR_CONFIG = msg.sender; // config invokes new CallitTicket(...)
        CONF = ICallitConfig(ADDR_CONFIG);
        address vault = CONF.ADDR_VAULT();
            // LEFT OFF HERE .. still failing here ^ with latest deploy
            // CallitConfig v0.11
        require(vault != address(0), ' !vault :7 '); // sanity check (msg.sender is a VAULT)
        transferOwnership(vault);
        _mint(vault, _initSupply * 10**uint8(decimals())); // 'emit Transfer'
    }
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT(), " !fact ;p ");
        _;
    }
    // inovked by vault
    function mintForPriceParity(address _receiver, uint256 _amount) external onlyOwner() {
        _mint(_receiver, _amount);
        emit MintedForPriceParity(_receiver, _amount);
    }
    // invoked by factory
    function burnForWinLoseClaim(address _account) external onlyFactory() {
        _burn(_account, balanceOf(_account)); // NOTE: checks _balance[_account]
        emit BurnForWinLoseClaim(_account, balanceOf(_account));
    }

    // NOTE: no way to change/update CONF after deployment

    // fwd any PLS recieved to VAULT (convert to USD stable & process deposit)
    receive() external payable {
        // process PLS value sent
        uint256 amntIn = msg.value;
        ICallitVault(CONF.ADDR_VAULT()).deposit{value: amntIn}(msg.sender);
    }
}