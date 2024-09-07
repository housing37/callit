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
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; // deploy
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./CallitTicket.sol"; // imports ERC20.sol
import "./ICallitLib.sol";

// interface IERC20x {
//     function decimals() external pure returns (uint8);
// }

contract CallitConfig {
    /* _ ADMIN SUPPORT (legacy) _ */
    address public KEEPER;
    uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    string public constant tVERSION = '0.1';
    address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
    address public ADDR_VAULT = address(0x15C49Ffd75998c04625Cb8d2d304416EdFb05387); // CallitVault v0.29
    address public ADDR_DELEGATE = address(0xD6380fc01f2eAD0725d71c87cd88e987b11D247B); // CallitDelegate v0.22
    address public ADDR_CALL = address(0x8Eb6d9c66104Ab29B0280687f7a483632A98d27D); // CallitToken v0.13
    address public ADDR_FACT = address(0xa72fcf6C1F9ebbBA50B51e2e0081caf3BCEa69aA); // CallitFactory v0.28
    ICallitLib private LIB = ICallitLib(ADDR_LIB);

    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    // note: makeNewMarket
    // call ticket token settings (note: init supply -> RATIO_LP_TOK_PER_USD)
    address public NEW_TICK_UNISWAP_V2_ROUTER;
    // address public NEW_TICK_UNISWAP_V2_FACTORY;
    address public NEW_TICK_USD_STABLE;

    // default all fees to 0 (KEEPER setter available)
    uint16 public PERC_MARKET_MAKER_FEE; // note: no other % fee
    uint16 public PERC_PROMO_BUY_FEE; // note: yes other % fee (promo.percReward)
    uint16 public PERC_ARB_EXE_FEE; // note: no other % fee
    uint16 public PERC_MARKET_CLOSE_FEE; // note: yes other % fee (PERC_PRIZEPOOL_VOTERS)
    uint16 public PERC_PRIZEPOOL_VOTERS = 200; // (2%) of total prize pool allocated to voter payout _ 10000 = %100.00
    uint16 public PERC_VOTER_CLAIM_FEE; // note: no other % fee
    uint16 public PERC_WINNER_CLAIM_FEE; // note: no other % fee

    // arb algorithm settings
    // market settings
    uint64 public MIN_USD_CALL_TICK_TARGET_PRICE = 10000; // 10000 == $0.010000 -> likely always be min (ie. $0.01 w/ _usd_decimals() = 6 decimals)
    // bool    public USE_SEC_DEFAULT_VOTE_TIME = true; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    // uint256 public SEC_DEFAULT_VOTE_TIME = 24 * 60 * 60; // 24 * 60 * 60 == 86,400 sec == 24 hours
    // uint16  public MAX_RESULTS = 10; // max # of result options a market may have (uint16 max = ~65K -> 65,535)
    // uint64  public MAX_EOA_MARKETS = type(uint8).max; // uint8 = 255 (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)

    /* _ ACCOUNT SUPPORT (legacy) _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    // NOTE: legacy public
    // mapping(address => uint64) public ACCT_USD_BALANCES; 
    // mapping(address => uint8) public USD_STABLE_DECIMALS;
    address[] public USWAP_V2_ROUTERS;
    mapping(address => address) public ROUTERS_TO_FACTORY;

    // NOTE: legacy private (was more secure; consider external KEEPER getter instead)
    // address[] public ACCOUNTS; 
    address[] public WHITELIST_USD_STABLES; // NOTE: private is more secure (legacy) consider KEEPER getter
    // address[] public USD_STABLES_HISTORY; // NOTE: private is more secure (legacy) consider KEEPER getter

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR
    /* -------------------------------------------------------- */
    constructor() {
        KEEPER = msg.sender; // set KEEPER

        // add default whiteliste stable: weDAI
        _editWhitelistStables(address(0xefD766cCb38EaF1dfd701853BFCe31359239F305), 18, true); // weDAI, decs, true = add

        // add default routers: pulsex (x2)
        // _editDexRouters(address(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02), address(0x1715a3E4A142d8b698131108995174F37aEBA10D), true); // pulseX v1, true = add
        _editDexRouters(address(0x165C3410fC91EF562C50559f7d2289fEbed552d9), address(0x29eA7545DEf87022BAdc76323F373EA1e707C523), true); // pulseX v2, true = add
            // NOTE: bug_fix_082724
            //  pulseX v1 was causing a failure when trying to swap 3000 PLS for ~1.04 weDAI
            //      the swap function kept returning 0 as amountsOut (or something like that)
            //  but pulseX v2 seems to be working fine
            //      tried 2 times with 3_000 and 30_000 PLS (both went through fine)
            //  *WARNING* should keep an eye on this

        // init settings for creating new CallitTicket.sol option results
        //  NOTE: VAULT should already be initialized
        NEW_TICK_UNISWAP_V2_ROUTER = USWAP_V2_ROUTERS[0];
        NEW_TICK_USD_STABLE = WHITELIST_USD_STABLES[0];

        // NOTE: ref pc dex addresses
        // ROUTER_pulsex_router02_v1='0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02' # PulseXRouter02 'v1' ref: https://www.irccloud.com/pastebin/6ftmqWuk
        // FACTORY_pulsex_router_02_v1='0x1715a3E4A142d8b698131108995174F37aEBA10D'
        // ROUTER_pulsex_router02_v2='0x165C3410fC91EF562C50559f7d2289fEbed552d9' # PulseXRouter02 'v2' ref: https://www.irccloud.com/pastebin/6ftmqWuk
        // FACTORY_pulsex_router_02_v2='0x29eA7545DEf87022BAdc76323F373EA1e707C523'
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == KEEPER, " !keeper :[ ");
        _;
    }
    modifier onlyVault() {
        require(msg.sender == ADDR_VAULT, " !vault ;[] ");
        _;
    }
    function keeperCheck(uint256 _check) external view onlyKeeper returns(bool) { 
        return _check == KEEPER_CHECK; 
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
    /* -------------------------------------------------------- */
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(KEEPER).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _tokAmnt must be in uint precision to _tokAddr.decimals()
            require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(KEEPER, _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }
    function KEEPER_setKeeper(address _newKeeper, uint16 _keeperCheck) external onlyKeeper {
        require(_newKeeper != address(0), 'err: 0 address');
        // address prev = address(KEEPER);
        KEEPER = _newKeeper;
        if (_keeperCheck > 0)
            KEEPER_CHECK = _keeperCheck;
        // emit KeeperTransfer(prev, KEEPER);
    }
    function KEEPER_setContracts(address _CALL, address _delegate, address _vault, address _lib, address _fact, bool _new) external onlyKeeper {
        // require(_delegate != address(0) && _vault != address(0) && _lib != address(0), ' invalid addies :0 ' );

        if (    _CALL != address(0)) ADDR_CALL = _CALL;
        if (    _fact != address(0)) ADDR_FACT = _fact; 
        if (_delegate != address(0)) ADDR_DELEGATE = _delegate;
        if (   _vault != address(0)) ADDR_VAULT = _vault;
        if (     _lib != address(0)) ADDR_LIB = _lib; LIB = ICallitLib(_lib);

        // EOA may indeed send 0x0 to "opt-in" for changing _fact address in support contracts
        //  if no _fact, update support contracts w/ current FACTORY address
        

        // // EOA may indeed send 0x0 to "opt-out" of changing addresses: _delegate, _vault, lib
        // // EOA may send _new = true to invoke 'INI_factory' for new contract deployments
        // if (_CALL != address(0)) {
        //     ADDR_CALL = _CALL;
        //     CALL = ICallitToken(address(_CALL));
        //     if (_new) {
        //         CALL.INIT_factory(); // set ADDR_FACT in CallitToken
                
        //         // mint initial CALl to keeper
        //         _mintCallToksEarned(KEEPER, 37); // LEFT OFF HERE ... testing only (comment out for production)
        //     }
            
        // }
        // if (_delegate != address(0)) {
        //     ADDR_DELEGATE = _delegate;
        //     DELEGATE = ICallitDelegate(address(_delegate));
        //     if (_new) DELEGATE.INIT_factory(); // set ADDR_FACT in DELEGATE
        // }
        // if (_vault != address(0)) {
        //     ADDR_VAULT = _vault;
        //     VAULT = ICallitVault(address(_vault));
        //     if (_new) {
        //         VAULT.INIT_factory(address(DELEGATE)); // set ADDR_FACT & ADDR_DELEGATE in VAULT
        //     }
        // }
        // if (_lib != address(0)) {
        //     ADDR_LIB = _lib;
        //     LIB = ICallitLib(address(_lib));
        // }

        // // EOA may indeed send 0x0 to "opt-in" for changing _fact address in support contracts
        // //  if no _fact, update support contracts w/ current FACTORY address
        // if (_fact == address(0)) {
        //     _fact = address(this); 
        // }

        // // update support contracts w/ OG|new addies accordingly
        // CALL.FACT_setContracts(_fact, address(VAULT));       
        // DELEGATE.KEEPER_setContracts(_fact, address(VAULT), address(LIB));
        // VAULT.KEEPER_setContracts(_fact, address(DELEGATE), address(LIB));
    }
    function KEEPER_setPercFees(uint16 _percMaker, uint16 _percPromo, uint16 _percArbExe, uint16 _percMarkClose, uint16 _percPrizeVoters, uint16 _percVoterClaim, uint16 _perWinnerClaim) external onlyKeeper {
        // no 2 percs taken out of market close
        require(_percPrizeVoters + _percMarkClose < 10000, ' close market perc error ;() ');
        require(_percMaker < 10000 && _percPromo < 10000 && _percArbExe < 10000 && _percMarkClose < 10000 && _percPrizeVoters < 10000 && _percVoterClaim < 10000 && _perWinnerClaim < 10000, ' invalid perc(s) :0 ');
        // require(_percPromo < 10000 && _percArbExe < 10000, ' invalid perc(s) :0 ');
        PERC_MARKET_MAKER_FEE = _percMaker; 
        PERC_PROMO_BUY_FEE = _percPromo; // note: yes other % fee (promo.percReward)
        PERC_ARB_EXE_FEE = _percArbExe;
        PERC_MARKET_CLOSE_FEE = _percMarkClose; // note: yes other % fee (PERC_PRIZEPOOL_VOTERS)
        PERC_PRIZEPOOL_VOTERS = _percPrizeVoters;
        PERC_VOTER_CLAIM_FEE = _percVoterClaim;
        PERC_WINNER_CLAIM_FEE = _perWinnerClaim;        
    }    
    function KEEPER_setNewTicketEnvironment(address _router, address _usdStable) external onlyKeeper {
        // max array size = 255 (uint8 loop)
        require(LIB._isAddressInArray(_router, USWAP_V2_ROUTERS) && LIB._isAddressInArray(_usdStable, WHITELIST_USD_STABLES), ' !whitelist router|factory|stable :() ');
        NEW_TICK_UNISWAP_V2_ROUTER = _router;
        NEW_TICK_USD_STABLE = _usdStable;
    }
    // // function KEEPER_setMarketSettings(uint16 _maxResultOpts, uint64 _maxEoaMarkets, uint64 _minUsdArbTargPrice, uint256 _secDefaultVoteTime, bool _useDefaultVotetime) external {
    function KEEPER_setMarketSettings(uint64 _minUsdArbTargPrice, bool _useDefaultVotetime) external {
        // MAX_RESULTS = _maxResultOpts; // max # of result options a market may have
        // MAX_EOA_MARKETS = _maxEoaMarkets;
        // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
        MIN_USD_CALL_TICK_TARGET_PRICE = _minUsdArbTargPrice;

        // SEC_DEFAULT_VOTE_TIME = _secDefaultVoteTime; // 24 * 60 * 60 == 86,400 sec == 24 hours
        USE_SEC_DEFAULT_VOTE_TIME = _useDefaultVotetime; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    }
    function KEEPER_editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) external onlyKeeper {
        _editWhitelistStables(_usdStable, _decimals, _add); // note: require check in local
        // emit WhitelistStableUpdated(_usdStable, _decimals, _add);
    }
    function KEEPER_editDexRouters(address _router, address factory, bool _add) external onlyKeeper {
        _editDexRouters(_router, factory, _add);
        // emit DexRouterUpdated(_router, _add);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - VAULT
    /* -------------------------------------------------------- */
    function VAULT_deployTicket(uint256 _initSupplyNoDecs, string calldata _tokName, string calldata _tokSymb) external onlyVault returns(address) {
        // Deploy a new ERC20 token for each result label (init supply = tokenAmount; transfered to VAULT to create LP)
        // (string memory tok_name, string memory tok_symb) = LIB._genTokenNameSymbol(_sender, _mark_num, i, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
        // address new_tick_tok = address (new CallitTicket(tokenAmount, address(this), tok_name, tok_symb));
        // address new_tick_tok = address (new CallitTicket(tokenAmount, address(VAULT), ADDR_FACT, "tTICKET_0", "tTCK0"));

        return address(new CallitTicket(_initSupplyNoDecs, _tokName, _tokSymb)); // _config = address(this)
    }
    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    // function getDexAddies() external view returns (address[] memory, address[] memory, address[] memory) {
    function getDexAddies() external view returns (address[] memory, address[] memory) {
        // return (WHITELIST_USD_STABLES,USD_STABLES_HISTORY,USWAP_V2_ROUTERS);
        return (WHITELIST_USD_STABLES, USWAP_V2_ROUTERS);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - SUPPORTING (CALLIT market management)
    /* -------------------------------------------------------- */
    // handle contract USD value deposits (convert PLS to USD stable)
    receive() external payable {
        // process PLS value sent
        // _deposit(msg.sender, msg.value);
    }


    /* -------------------------------------------------------- */
    /* PRIVATE SUPPORTING
    /* -------------------------------------------------------- */
    function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) private { // allows duplicates
        if (_add) {
            WHITELIST_USD_STABLES = LIB._addAddressToArraySafe(_usdStable, WHITELIST_USD_STABLES, true); // true = no dups
            // USD_STABLES_HISTORY = LIB._addAddressToArraySafe(_usdStable, USD_STABLES_HISTORY, true); // true = no dups
            // USD_STABLE_DECIMALS[_usdStable] = _decimals;
        } else {
            WHITELIST_USD_STABLES = LIB._remAddressFromArray(_usdStable, WHITELIST_USD_STABLES);
        }
    }
    function _editDexRouters(address _router, address _factory, bool _add) private {
        require(_router != address(0x0), "0 address");
        if (_add) {
            USWAP_V2_ROUTERS = LIB._addAddressToArraySafe(_router, USWAP_V2_ROUTERS, true); // true = no dups
            ROUTERS_TO_FACTORY[_router] = _factory;
        } else {
            USWAP_V2_ROUTERS = LIB._remAddressFromArray(_router, USWAP_V2_ROUTERS); // removes only one & order NOT maintained
            delete ROUTERS_TO_FACTORY[_router];
        }
    }
}