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

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol"; 

interface ICallitConfig { // don't need everything in ICallitConfig.sol
    function ADDR_VAULT() external view returns(address);
    function ADDR_FACT() external view returns(address);
    function ADDR_DELEGATE() external view returns(address);
}
interface ICallitVault {
    function deposit(address _depositor) external payable;
}

contract CallitTicket is ERC20 {
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    string public tVERSION = '0.7'; 
    address public ADDR_CONFIG; // set via constructor()
    ICallitConfig private CONF; // set via constructor()
    event MintedForPriceParity(address _receiver, uint256 _amount);
    event BurnForRewardClaim(address _account, uint256 _amount);
    event DeadlineTransferLockUpdate(bool _prevLockStatus, bool _newLockStatus);

    bool DEADLINE_TRANSFER_LOCK = false;

    constructor(uint256 _initSupply, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        ADDR_CONFIG = msg.sender; // config invokes new CallitTicket(...)
        CONF = ICallitConfig(ADDR_CONFIG);
        address vault = CONF.ADDR_VAULT();

        // sanity check: access vault from msg.sender (ie. CONF)
        require(vault != address(0), ' !vault :7 '); 

        // mint to vault (vault creates and maintains LPs)
        _mint(vault, _initSupply * 10**uint8(decimals())); // 'emit Transfer'
        
        // NOTE: no way to change/update CONF after deployment (there will be too many)
        //  this results in ...
        //      only OG factory can burn (ie. claim winnings breaks, if factory changed)
        //      only OG vault can mint (ie. exe arb price parity breaks, if vault changed)
        //      OG vault gets fwd all 'receive()' deposits (not such a big deal)
        //  NOTE: this means that if factory or vault addresses ever need to be changed
        //      then all previously created tickets under them, will break
        //
        //      HOWEVER, there may be a work around since we are storing 
        //          ticket addies in struct MARKET.MARKET_RESULTS
    }
    modifier onlyVault() {
        require(msg.sender == CONF.ADDR_VAULT(), " !vault ;p ");
        _;        
    }
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.ADDR_DELEGATE(), " !fact|del ;p ");
        _;
    }
    // inovked by vault
    function mintForPriceParity(address _receiver, uint256 _amount) external onlyVault() {
        _mint(_receiver, _amount);
        emit MintedForPriceParity(_receiver, _amount);
    }
    // invoked by factory
    function burnForRewardClaim(address _account) external onlyFactory() {
        _burn(_account, balanceOf(_account)); // NOTE: checks _balance[_account]
        emit BurnForRewardClaim(_account, balanceOf(_account));
    }
    function setDeadlineTransferLock(bool _lock) external onlyFactory {
        bool prev = DEADLINE_TRANSFER_LOCK;
        DEADLINE_TRANSFER_LOCK = _lock;
        emit DeadlineTransferLockUpdate(prev, DEADLINE_TRANSFER_LOCK);
    }

    // invoked if function invoked doesn't exist OR no receive() implemented & ETH received w/o data
    fallback() external payable {
        // fwd any PLS recieved to VAULT (convert to USD stable & process deposit)    
        ICallitVault(CONF.ADDR_VAULT()).deposit{value: msg.value}(msg.sender);
    }

    /* -------------------------------------------------------- */
    /* ERC20 - OVERRIDES                                        */
    /* -------------------------------------------------------- */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(!DEADLINE_TRANSFER_LOCK, ' transfers deadline-locked :0 ');
        
        // checks msg.sender 'allowance(from, msg.sender, value)' 
        //  then invokes '_transfer(from, to, value)'
        return super.transferFrom(from, to, value);
    }
    function transfer(address to, uint256 value) public override returns (bool) {
        require(!DEADLINE_TRANSFER_LOCK, ' transfers deadline-locked :( ');
        return super.transfer(to, value); // invokes '_transfer(msg.sender, to, value)'
    }
}