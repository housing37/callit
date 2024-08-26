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
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CallitToken is ERC20, Ownable {
    /* -------------------------------------------------------- */
    /* GLOBALS
    /* -------------------------------------------------------- */
    string public tVERSION = '0.1';
    string private TOK_SYMB = string(abi.encodePacked("tCALL", tVERSION));
    string private TOK_NAME = string(abi.encodePacked("tCALL-IT_", tVERSION));
    // string private TOK_SYMB = "CALL";
    // string private TOK_NAME = "CALL-IT VOTE";
    address public FACT_ADDR;
    bool private ONCE_ = true;
    mapping(address => uint256) public ACCT_CALL_VOTE_LOCK_TIME; // track EOA to their call token lock timestamp; remember to reset to 0 (ie. 'not locked') ***

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR SUPPORT
    /* -------------------------------------------------------- */
    constructor(uint256 _initSupply) ERC20(TOK_NAME, TOK_SYMB) Ownable(msg.sender) {     
        _mint(msg.sender, _initSupply * 10**uint8(decimals())); // 'emit Transfer'
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyFactory() {
        require(msg.sender == FACT_ADDR, " !fact :p ");
        _;
    }
    modifier onlyOnce() {
        require(ONCE_, ' never again :/ ' );
        ONCE_ = false;
        _;
    }

    /* -------------------------------------------------------- */
    /* FACTORY SUPPORT
    /* -------------------------------------------------------- */
    function INIT_factory() external onlyOnce {
        require(FACT_ADDR == address(0), ' factor already set :) ');
        FACT_ADDR == msg.sender;
    }
    function mintCallToksEarned(address _receiver, uint256 _callAmnt) external onlyFactory {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        //  NOTE: _callAmnt decimals should be accounted for on factory invoking side
        //      allows for factory minting fractions of a token if needed
        _mint(_receiver, _callAmnt);
    }
    /* -------------------------------------------------------- */
    /* PUBLIC SETTERS
    /* -------------------------------------------------------- */
    function setCallTokenVoteLock(bool _lock) external {
        ACCT_CALL_VOTE_LOCK_TIME[msg.sender] = _lock ? block.timestamp : 0;
    }
    /* -------------------------------------------------------- */
    /* ERC20 - OVERRIDES                                        */
    /* -------------------------------------------------------- */
    function burn(uint256 _burnAmnt) external {
        require(_burnAmnt > 0, ' burn nothing? :0 ');
        _burn(msg.sender, _burnAmnt); // NOTE: checks _balance[msg.sender]
    }
    function decimals() public pure override returns (uint8) {
        // return 6; // (6 decimals) 
            // * min USD = 0.000001 (6 decimals) 
            // uint16 max USD: ~0.06 -> 0.065535 (6 decimals)
            // uint32 max USD: ~4K -> 4,294.967295 USD (6 decimals) _ max num: ~4B -> 4,294,967,295
            // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
        return 18; // (18 decimals) 
            // * min USD = 0.000000000000000001 (18 decimals) 
            // uint64 max USD: ~18 -> 18.446744073709551615 (18 decimals)
            // uint128 max USD: ~340T -> 340,282,366,920,938,463,463.374607431768211455 (18 decimals)
    }
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(ACCT_CALL_VOTE_LOCK_TIME[msg.sender] == 0, ' tokens locked ;) ');
        // checks msg.sender 'allowance(from, msg.sender, value)' 
        //  then invokes '_transfer(from, to, value)'
        return super.transferFrom(from, to, value);
    }
    function transfer(address to, uint256 value) public override returns (bool) {
        require(ACCT_CALL_VOTE_LOCK_TIME[msg.sender] == 0, ' tokens locked ;0 ');
        return super.transfer(to, value); // invokes '_transfer(msg.sender, to, value)'
    }

} 