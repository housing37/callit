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

import "./ICallitVault.sol";

contract CallitToken is ERC20, Ownable {
    /* -------------------------------------------------------- */
    /* GLOBALS
    /* -------------------------------------------------------- */
    string public tVERSION = '0.13';
    string private TOK_SYMB = string(abi.encodePacked("tCALL", tVERSION));
    string private TOK_NAME = string(abi.encodePacked("tCALL-IT_", tVERSION));
    // string private TOK_SYMB = "CALL";
    // string private TOK_NAME = "CALL-IT VOTE";
    bool private ONCE_ = true;
    mapping(address => uint256) public ACCT_CALL_VOTE_LOCK_TIME; // track EOA to their call token lock timestamp; remember to reset to 0 (ie. 'not locked') ***
    mapping(address => string) public ACCT_HANDLES; // market makers (etc.) can set their own handles

    address public ADDR_VAULT = address(0x4f7242cC8715f3935Ccec21012D32978e42C7763); // CallitVault v0.28
    address public ADDR_FACT; // set via INIT_factory()
    ICallitVault private VAULT = ICallitVault(ADDR_VAULT);

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR SUPPORT
    /* -------------------------------------------------------- */
    constructor() ERC20(TOK_NAME, TOK_SYMB) Ownable(msg.sender) {     
        // _mint(msg.sender, _initSupply * 10**uint8(decimals())); // 'emit Transfer'

        // NOTE: init supply minted to KEEPER of FACTORY 
        //  via FACTORY._mintCallToksEarned in FACTORY.constructor
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyFactory() {
        require(msg.sender == ADDR_FACT, " !fact :p ");
        _;
    }
    modifier onlyOnce() {
        require(ONCE_, ' never again :/ ' );
        ONCE_ = false;
        _;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - UI (CALLIT)
    /* -------------------------------------------------------- */
    // handle contract USD value deposits (convert PLS to USD stable)
    // extract & send PLS to vault for processing (handle swap for usd stable)
    receive() external payable {        
        uint256 amntIn = msg.value; 
        VAULT.deposit{value: amntIn}(msg.sender);
        // NOTE: at this point, the vault has the deposited stable and the vault has stored accont balances
    }

    /* -------------------------------------------------------- */
    /* FACTORY SUPPORT
    /* -------------------------------------------------------- */
    function INIT_factory() external onlyOnce {
        require(ADDR_FACT == address(0), ' factor already set :) ');
        ADDR_FACT = msg.sender;
    }
    function FACT_setContracts(address _fact, address _vault) external onlyFactory {
        ADDR_FACT = _fact;
        ADDR_VAULT = _vault;
        VAULT = ICallitVault(ADDR_VAULT);
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
    function balanceOf_voteCnt(address _voter) external view returns(uint64) {
        return _uint64_from_uint256(balanceOf(_voter) / 10**uint8(decimals())); // do not return decimals
            // NOTE: _uint64_from_uint256 checks out OK
    }
    function setAcctHandle(string calldata _handle) external {
        require(bytes(_handle).length >= 1 && bytes(_handle)[0] != 0x20, ' !_handle :[] ');
        if (_validNonWhiteSpaceString(_handle))
            ACCT_HANDLES[msg.sender] = _handle;
        else
            revert(' !blank space handles :-[=] ');     
    }

    /* -------------------------------------------------------- */
    /* ERC20 - OVERRIDES                                        */
    /* -------------------------------------------------------- */
    // function symbol() public view override returns (string memory) {
    //     return TOK_SYMB;
    // }
    // function name() public view override returns (string memory) {
    //     return TOK_NAME;
    // }
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


    /* -------------------------------------------------------- */
    /* PRIVATE HELPERS
    /* -------------------------------------------------------- */
    function _uint64_from_uint256(uint256 value) private pure returns (uint64) { // from CallitLib.sol
        require(value <= type(uint64).max, "Value exceeds uint64 range :0 ");
        uint64 convertedValue = uint64(value);
        return convertedValue;
    }
    function _validNonWhiteSpaceString(string calldata _s) private pure returns(bool) { // from CallitLib.sol
        for (uint8 i=0; i < bytes(_s).length;) {
            if (bytes(_s)[i] != 0x20) {
                // Found a non-space character, return true
                return true; 
            }
            unchecked {
                i++;
            }
        }

        // found string with all whitespaces as chars
        return false;
    }
} 