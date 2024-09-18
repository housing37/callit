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
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// import "./CallitTicket.sol"; // imports ERC20.sol // declares ICallitVault.deposit
import "./ICallitLib.sol";
import "./ICallitConfig.sol";

interface IERC20x {
    function decimals() external pure returns (uint8);
    function approve(address spender, uint256 value) external returns (bool);
}

interface ICallitTicket { 
    function mintForPriceParity(address _receiver, uint256 _amount) external;
    function balanceOf(address account) external returns(uint256);
}

contract CallitVault {
    /* _ ADMIN SUPPORT (legacy) _ */
    // address public KEEPER;
    // uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    // bool private ONCE_ = true;
    bool private FIRST_ = true;
    string public constant tVERSION = '0.48'; 
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    ICallitLib private LIB;     // set via CONF_setConfig
    // address public ADDR_LIB = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
    // address public ADDR_FACT; // set via INIT_factory(address _delegate)
    // address public ADDR_DELEGATE; // set via INIT_factory(address _delegate)

    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    // // note: makeNewMarket
    // // call ticket token settings (note: init supply -> RATIO_LP_TOK_PER_USD)
    // address public NEW_TICK_UNISWAP_V2_ROUTER;
    // address public NEW_TICK_UNISWAP_V2_FACTORY;
    // address public NEW_TICK_USD_STABLE;

    // note: makeNewMarket
    // temp-arrays for 'makeNewMarket' support
    address[] private resultOptionTokens;
    address[] private resultTokenLPs;
    address[] private resultTokenRouters;
    // address[] private resultTokenFactories;

    address[] private resultTokenUsdStables;
    uint64 [] private resultTokenVotes;

    // // default all fees to 0 (KEEPER setter available)
    // // uint16 public PERC_MARKET_MAKER_FEE; // note: no other % fee
    // uint16 public PERC_PROMO_BUY_FEE; // note: yes other % fee (promo.percReward)
    // uint16 public PERC_ARB_EXE_FEE; // note: no other % fee
    // // uint16 public PERC_MARKET_CLOSE_FEE; // note: yes other % fee (PERC_PRIZEPOOL_VOTERS)
    // // uint16 public PERC_PRIZEPOOL_VOTERS = 200; // (2%) of total prize pool allocated to voter payout _ 10000 = %100.00
    // // uint16 public PERC_VOTER_CLAIM_FEE; // note: no other % fee
    // // uint16 public PERC_WINNER_CLAIM_FEE; // note: no other % fee

    // uint16 public PERC_OF_LOSER_SUPPLY_EARN_CALL = 2500; // (25%) _ 10000 = %100.00; 5000 = %50.00; 0001 = %00.01
    // uint32 public RATIO_CALL_MINT_PER_LOSER = 1; // amount of all $CALL minted per loser reward (depends on PERC_OF_LOSER_SUPPLY_EARN_CALL)

    // // market action mint incentives
    // uint32 public RATIO_CALL_MINT_PER_ARB_EXE = 1; // amount of all $CALL minted per arb executer reward // TODO: need KEEPER setter
    // uint32 public RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS = 1; // amount of all $CALL minted per market call close action reward // TODO: need KEEPER setter
    // uint32 public RATIO_CALL_MINT_PER_VOTE = 1; // amount of all $CALL minted per vote reward // TODO: need KEEPER setter
    // uint32 public RATIO_CALL_MINT_PER_MARK_CLOSE = 1; // amount of all $CALL minted per market close action reward // TODO: need KEEPER setter
    // uint64 public RATIO_PROMO_USD_PER_CALL_MINT = 1000000; // (1000000 = %1.000000; 6 decimals) usd amnt buy needed per $CALL earned in promo (note: global for promos to avoid exploitations)
    // uint64 public MIN_USD_PROMO_TARGET = 1000000; // (1000000 = $1.000000) min target for creating promo codes ($ target = $ bets this promo brought in)

    // // lp settings
    // // uint64 public MIN_USD_MARK_LIQ = 1000000; // (1000000 = $1.000000) min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    // uint16 public RATIO_LP_TOK_PER_USD = 10000; // # of ticket tokens per usd, minted for LP deploy
    // uint64 public RATIO_LP_USD_PER_CALL_TOK = 1000000; // (1000000 = %1.000000; 6 decimals) init LP usd amount needed per $CALL earned by market maker
    //     // NOTE: utilized in 'FACTORY.closeMarketForTicket'
    //     // LEFT OFF HERE  ... need more requirement for market maker earning $CALL
    //     //  ex: maker could create $100 LP, not promote, delcare himself winner, get his $100 back and earn free $CALL)    

    /* _ ACCOUNT SUPPORT (legacy) _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    // NOTE: legacy public
    mapping(address => uint64) public ACCT_USD_BALANCES; 
    // // mapping(address => uint8) public USD_STABLE_DECIMALS;
    // address[] public USWAP_V2_ROUTERS;
    // mapping(address => address) public ROUTERS_TO_FACTORY;

    // NOTE: legacy private (was more secure; consider external KEEPER getter instead)
    address[] public ACCOUNTS; 
    // address[] public WHITELIST_USD_STABLES; // NOTE: private is more secure (legacy) consider KEEPER getter
    // // address[] public USD_STABLES_HISTORY; // NOTE: private is more secure (legacy) consider KEEPER getter

    mapping(address => address) private TICK_PAIR_ADDR; // used for lp maintence KEEPER withdrawel
    mapping(address => uint64) public PROMO_USD_OWED; // maps promo code HASH to usd owed for that hash

    // // arb algorithm settings
    // // market settings
    // uint64 public MIN_USD_CALL_TICK_TARGET_PRICE = 10000; // 10000 == $0.010000 -> likely always be min (ie. $0.01 w/ _usd_decimals() = 6 decimals)
    // // bool    public USE_SEC_DEFAULT_VOTE_TIME = true; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    // // uint256 public SEC_DEFAULT_VOTE_TIME = 24 * 60 * 60; // 24 * 60 * 60 == 86,400 sec == 24 hours
    // // uint16  public MAX_RESULTS = 10; // max # of result options a market may have (uint16 max = ~65K -> 65,535)
    // // uint64  public MAX_EOA_MARKETS = type(uint8).max; // uint8 = 255 (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)

    // // function KEEPER_setMarketSettings(uint16 _maxResultOpts, uint64 _maxEoaMarkets, uint64 _minUsdArbTargPrice, uint256 _secDefaultVoteTime, bool _useDefaultVotetime) external {
    // function KEEPER_setMarketSettings(uint64 _minUsdArbTargPrice, bool _useDefaultVotetime) external {
    //     // MAX_RESULTS = _maxResultOpts; // max # of result options a market may have
    //     // MAX_EOA_MARKETS = _maxEoaMarkets;
    //     // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
    //     MIN_USD_CALL_TICK_TARGET_PRICE = _minUsdArbTargPrice;

    //     // SEC_DEFAULT_VOTE_TIME = _secDefaultVoteTime; // 24 * 60 * 60 == 86,400 sec == 24 hours
    //     USE_SEC_DEFAULT_VOTE_TIME = _useDefaultVotetime; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    // }

    // function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) external onlyFactory() {
    //     // NOTE: _usdAmnt must be in _usd_decimals() precision
    //     // require(_acct != address(0) && _usdAmnt > 0, ' invalid _acct | _usdAmnt :p ');
    //     edit_ACCT_USD_BALANCES(_acct, _usdAmnt, _add);
    // }
    // NOTE: not sure why i added this at one point (but it causes the file size error 082624)
    //  perhaps it was for vault backup & restore ?
    // function set_ACCOUNTS(address[] calldata _accts) external onlyFactory() {
    //     ACCOUNTS = _accts;
    // }

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // legacy
    // event KeeperTransfer(address _prev, address _new);
    // event WhitelistStableUpdated(address _usdStable, uint8 _decimals, bool _add);
    // event DexRouterUpdated(address _router, bool _add);
    event DepositReceived(address _account, uint256 _plsDeposit, uint64 _stableConvert);
    // callit
    // event AlertStableSwap(uint256 _tickStableReq, uint256 _contrStableBal, address _swapFromStab, address _swapToTickStab, uint256 _tickStabAmntNeeded, uint256 _swapAmountOut);
    // event AlertZeroReward(address _sender, uint64 _usdReward, address _receiver);
    // event PromoRewardPaid(address _promoCodeHash, uint64 _usdRewardPaid, address _promotor, address _buyer, address _ticket);
    event PromoRewardLogged(address _promoCodeHash, uint64 _usdRewardPaid, address _promotor, address _buyer, address _ticket);

    constructor() {
        // set KEEPER
        // KEEPER = msg.sender;

        // // add default whiteliste stable: weDAI
        // _editWhitelistStables(address(0xefD766cCb38EaF1dfd701853BFCe31359239F305), 18, true); // weDAI, decs, true = add

        // // add default routers: pulsex (x2)
        // // _editDexRouters(address(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02), address(0x1715a3E4A142d8b698131108995174F37aEBA10D), true); // pulseX v1, true = add
        // _editDexRouters(address(0x165C3410fC91EF562C50559f7d2289fEbed552d9), address(0x29eA7545DEf87022BAdc76323F373EA1e707C523), true); // pulseX v2, true = add
        //     // NOTE: bug_fix_082724
        //     //  pulseX v1 was causing a failure when trying to swap 3000 PLS for ~1.04 weDAI
        //     //      the swap function kept returning 0 as amountsOut (or something like that)
        //     //  but pulseX v2 seems to be working fine
        //     //      tried 2 times with 3_000 and 30_000 PLS (both went through fine)
        //     //  *WARNING* should keep an eye on this

        // // init settings for creating new CallitTicket.sol option results
        // //  NOTE: VAULT should already be initialized
        // NEW_TICK_UNISWAP_V2_ROUTER = USWAP_V2_ROUTERS[0];
        // NEW_TICK_UNISWAP_V2_FACTORY = ROUTERS_TO_FACTORY[NEW_TICK_UNISWAP_V2_ROUTER];
        // NEW_TICK_USD_STABLE = WHITELIST_USD_STABLES[0];

        // NOTE: ref pc dex addresses
        // ROUTER_pulsex_router02_v1='0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02' # PulseXRouter02 'v1' ref: https://www.irccloud.com/pastebin/6ftmqWuk
        // FACTORY_pulsex_router_02_v1='0x1715a3E4A142d8b698131108995174F37aEBA10D'
        // ROUTER_pulsex_router02_v2='0x165C3410fC91EF562C50559f7d2289fEbed552d9' # PulseXRouter02 'v2' ref: https://www.irccloud.com/pastebin/6ftmqWuk
        // FACTORY_pulsex_router_02_v2='0x29eA7545DEf87022BAdc76323F373EA1e707C523'
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    // modifier keeperCheck(uint256 _check) {
    //     require(_check == ;, ' !check :6');
    // }
    modifier onlyKeeper() {
        require(msg.sender == CONF.KEEPER(), " !keeper :[ ");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.ADDR_DELEGATE() || 
                msg.sender == CONF.KEEPER() || msg.sender == address(this), 
                " !keeper & !fact :p ");
        _;
    }
    modifier onlyConfig() { 
        // allows 1st onlyConfig attempt to freely pass
        //  NOTE: don't waste this on anything but CONF_setConfig
        if (!FIRST_) 
            require(msg.sender == address(CONF), ' !CONF :p ');
        FIRST_ = false;
        _;
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :< ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(_conf);
        LIB = ICallitLib(CONF.ADDR_LIB());
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
    /* -------------------------------------------------------- */
    // legacy
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(CONF.KEEPER()).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _tokAmnt must be in uint precision to _tokAddr.decimals()
            require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(CONF.KEEPER(), _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }
    // function KEEPER_setKeeper(address _newKeeper, uint16 _keeperCheck) external onlyKeeper {
    //     require(_newKeeper != address(0), 'err: 0 address');
    //     // address prev = address(KEEPER);
    //     KEEPER = _newKeeper;
    //     if (_keeperCheck > 0)
    //         KEEPER_CHECK = _keeperCheck;
    //     // emit KeeperTransfer(prev, KEEPER);
    // }
    // function KEEPER_collectiveStableBalances(bool _history, uint256 _keeperCheck) external view onlyKeeper() returns (uint64, uint64, int64) {
    function KEEPER_collectiveStableBalances(uint256 _keeperCheck) external view returns (uint64, uint64, int64) {
        require(CONF.keeperCheck(_keeperCheck), ' !_keeperCheck :( ');
        // if (_history)
        //     return _collectiveStableBalances(USD_STABLES_HISTORY);
        // return _collectiveStableBalances(WHITELIST_USD_STABLES);

        // (address[] memory stables,,) = CONF.getDexAddies();
        uint64 gross_bal = _grossStableBalance(CONF.get_WHITELIST_USD_STABLES());
        uint64 owed_bal = _owedStableBalance();
        int64 net_bal = int64(gross_bal) - int64(owed_bal);
        return (gross_bal, owed_bal, net_bal);
    }
    // function KEEPER_editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) external onlyKeeper {
    //     _editWhitelistStables(_usdStable, _decimals, _add); // note: require check in local
    //     // emit WhitelistStableUpdated(_usdStable, _decimals, _add);
    // }
    // function KEEPER_editDexRouters(address _router, address factory, bool _add) external onlyKeeper {
    //     _editDexRouters(_router, factory, _add);
    //     // emit DexRouterUpdated(_router, _add);
    // }
    // callit
    function KEEPER_withdrawTicketLP(address _ticket) external onlyKeeper {
        // NOTE: can only withdraw LP from one _ticket at a time
        //  bc no current way to get market for _ticket (from FACTORY)
        IERC20(TICK_PAIR_ADDR[_ticket]).transfer(CONF.KEEPER(), IERC20(TICK_PAIR_ADDR[_ticket]).balanceOf(address(this)));
    }
    // function KEEPER_logTicketPair(address _ticket, address _pair) external onlyFactory() {
    //     require(_ticket != address(0) && _pair != address(0), ' 0 address :[ ');
    //     TICK_PAIR_ADDR[_ticket] = _pair;
    // }
    // function KEEPER_setContracts(address _fact, address _delegate, address _lib) external onlyFactory() {
    //     ADDR_DELEGATE = _delegate;
    //     ADDR_FACT = _fact;

    //     ADDR_LIB = _lib;
    //     LIB = ICallitLib(_lib);
    // }
    // function KEEPER_setMarketActionMints(uint32 _callPerArb, uint32 _callPerMarkCloseCalls, uint32 _callPerVote, uint32 _callPerMarkClose, uint64 _promoUsdPerCall, uint64 _minUsdPromoTarget) external onlyKeeper {
    //     RATIO_CALL_MINT_PER_ARB_EXE = _callPerArb; // amount of all $CALL minted per arb executer reward
    //     RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS = _callPerMarkCloseCalls; // amount of all $CALL minted per market call close action reward
    //     RATIO_CALL_MINT_PER_VOTE = _callPerVote; // amount of all $CALL minted per vote reward
    //     RATIO_CALL_MINT_PER_MARK_CLOSE = _callPerMarkClose; // amount of all $CALL minted per market close action reward
    //     RATIO_PROMO_USD_PER_CALL_MINT = _promoUsdPerCall; // usd amnt buy needed per $CALL earned in promo (note: global for promos to avoid exploitations)
    //     MIN_USD_PROMO_TARGET = _minUsdPromoTarget; // min target for creating promo codes ($ target = $ bets this promo brought in)
    // }

    // function KEEPER_setMarketLoserMints(uint8 _mintAmnt, uint8 _percSupplyReq) external onlyKeeper {
    //     require(_percSupplyReq <= 10000, ' total percs > 100.00% ;) ');
    //     RATIO_CALL_MINT_PER_LOSER = _mintAmnt;
    //     PERC_OF_LOSER_SUPPLY_EARN_CALL = _percSupplyReq;
    // }
    // function KEEPER_setPercFees(uint16 _percMaker, uint16 _percPromo, uint16 _percArbExe, uint16 _percMarkClose, uint16 _percPrizeVoters, uint16 _percVoterClaim, uint16 _perWinnerClaim) external onlyKeeper {
    // function KEEPER_setPercFees(uint16 _percPromo, uint16 _percArbExe) external onlyKeeper {
    //     // no 2 percs taken out of market close
    //     // require(_percPrizeVoters + _percMarkClose < 10000, ' close market perc error ;() ');
    //     // require(_percMaker < 10000 && _percPromo < 10000 && _percArbExe < 10000 && _percMarkClose < 10000 && _percPrizeVoters < 10000 && _percVoterClaim < 10000 && _perWinnerClaim < 10000, ' invalid perc(s) :0 ');
    //     require(_percPromo < 10000 && _percArbExe < 10000, ' invalid perc(s) :0 ');
    //     // PERC_MARKET_MAKER_FEE = _percMaker; 
    //     PERC_PROMO_BUY_FEE = _percPromo; // note: yes other % fee (promo.percReward)
    //     PERC_ARB_EXE_FEE = _percArbExe;
    //     // PERC_MARKET_CLOSE_FEE = _percMarkClose; // note: yes other % fee (PERC_PRIZEPOOL_VOTERS)
    //     // PERC_PRIZEPOOL_VOTERS = _percPrizeVoters;
    //     // PERC_VOTER_CLAIM_FEE = _percVoterClaim;
    //     // PERC_WINNER_CLAIM_FEE = _perWinnerClaim;        
    // }
    // // function KEEPER_setLpSettings(uint64 _usdPerCallEarned, uint16 _tokCntPerUsd, uint64 _usdMinInitLiq) external onlyKeeper {
    // function KEEPER_setLpSettings(uint64 _usdPerCallEarned, uint16 _tokCntPerUsd) external onlyKeeper {
    //     RATIO_LP_USD_PER_CALL_TOK = _usdPerCallEarned; // LP usd amount needed per $CALL earned by market maker
    //     RATIO_LP_TOK_PER_USD = _tokCntPerUsd; // # of ticket tokens per usd, minted for LP deploy
    //     // MIN_USD_MARK_LIQ = _usdMinInitLiq; // min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    // }
    // function KEEPER_setNewTicketEnvironment(address _router, address _usdStable) external onlyKeeper {
    //     // max array size = 255 (uint8 loop)
    //     // NOTE: if _router not mapped to a factory, then _router not in VAULT.USWAP_V2_ROUTERS
    //     require(ROUTERS_TO_FACTORY[_router] != address(0) && LIB._isAddressInArray(_usdStable, WHITELIST_USD_STABLES), ' !whitelist router|factory|stable :() ');
    //     NEW_TICK_UNISWAP_V2_ROUTER = _router;
    //     NEW_TICK_UNISWAP_V2_FACTORY = ROUTERS_TO_FACTORY[_router];
    //     NEW_TICK_USD_STABLE = _usdStable;
    // }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    // NOTE: attempts to refactor this function into a global, 
    //  results in increased compilation file size (despite being invoked 11 or 12)
    function _usd_decimals() public pure returns (uint8) {
        return 6; // (6 decimals) 
            // * min USD = 0.000001 (6 decimals) 
            // uint16 max USD: ~0.06 -> 0.065535 (6 decimals)
            // uint32 max USD: ~4K -> 4,294.967295 USD (6 decimals)
            // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    }
    function getAccounts() external view returns (address[] memory) {
        return ACCOUNTS;
    }
    // // function getDexAddies() external view returns (address[] memory, address[] memory, address[] memory) {
    // function getDexAddies() external view returns (address[] memory, address[] memory) {
    //     // return (WHITELIST_USD_STABLES,USD_STABLES_HISTORY,USWAP_V2_ROUTERS);
    //     return (CONF.WHITELIST_USD_STABLES, CONF.USWAP_V2_ROUTERS);
    // }
    // function getUsdStablesHistory() external view returns (address[] memory) {
    //     return USD_STABLES_HISTORY;
    // }    
    // function getWhitelistStables() external view returns (address[] memory) {
    //     return WHITELIST_USD_STABLES;
    // }
    // function getDexRouters() external view returns (address[] memory) {
    //     return USWAP_V2_ROUTERS;
    // }

    /* -------------------------------------------------------- */
    /* PUBLIC - SUPPORTING (CALLIT market management)
    /* -------------------------------------------------------- */
    // Fallback function to handle Ether and address from msg.data
    //  Encoding the address and sending it along with Ether
    //      (address(myContract).call{value: 1 ether}(abi.encodeWithSignature("functionWithAddress(address)", targetAddress)));

    /* ref: https://docs.soliditylang.org/en/latest/contracts.html#fallback-function
        The fallback function is executed on a call to the contract if none of the other 
        functions match the given function signature, 
        or if no data was supplied at all and there is no receive Ether function. 
        The fallback function always receives data, but in order to also receive Ether it must be marked payable.
    */
    // invoked if ...
    //  function invoked doesn't exist
    //  no receive() implemented & ETH received w/o data
    fallback() external payable {
        deposit(msg.sender);

        // address _depositor = msg.sender;
        // uint256 msgValue = msg.value;

        // // perform swap from PLS to stable & send to vault
        // address[] memory pls_stab_path = new address[](2);
        // pls_stab_path[0] = TOK_WPLS;
        // pls_stab_path[1] = CONF.DEPOSIT_USD_STABLE();
        // // uint64 stableAmntOut = _uint64_from_uint256(_exeSwapTokForTok(msgValue, pls_stab_path, address(this), false)); // false = _fromUsdAcctBal
        // // uint64 stableAmntOut = _uint64_from_uint256(_swap_v2_wrap(pls_stab_path, CONF.DEPOSIT_ROUTER(), msgValue, address(this), false)); // true = fromETH
        // address router = CONF.DEPOSIT_ROUTER();
        // uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(msgValue, pls_stab_path); // quote swap
        // uint256 amntOutQuote = amountsOut[amountsOut.length -1];
        // uint64 stableAmntOut = _uint64_from_uint256(_swap_v2(router, pls_stab_path, msgValue, amntOutQuote, address(this), false)); // approve & execute swap
        //                           function _swap_v2(address router, address[] memory path, uint256 amntIn, uint256 amntOutMin, address outReceiver, bool fromETH) private returns (uint256) {

        // LEFT OFF HERE ... this integration (below) indeed works (ie. does not run out of gas)
        //         tested twice, seems to work fine, just seems to use a higher gas limit
        //              uses ~1/2 of ~500k max units, instead of ~all of ~50k units(+-)
        //  NEXT: should remove/refactor 'deposit' integration below
        //      currently fails when PLS is fwd over from other contract deposits
        //      also this contract compiled file size is almost at max now (24556 of 24576)

        // // perform swap from PLS to stable & send to vault
        // address[] memory pls_stab_path = new address[](2);
        // pls_stab_path[0] = TOK_WPLS; // note: WPLS required for 'swapExactETHForTokens'
        // pls_stab_path[1] = CONF.DEPOSIT_USD_STABLE();
        // IUniswapV2Router02 swapRouter = IUniswapV2Router02(CONF.DEPOSIT_ROUTER());
        // uint256[] memory amountsOut = swapRouter.getAmountsOut(msgValue, pls_stab_path); // quote swap
        // // uint256 amntOutQuote = amountsOut[amountsOut.length -1];
        
        // IERC20(address(pls_stab_path[0])).approve(address(swapRouter), msgValue);
        // uint[] memory amntOut = swapRouter.swapExactETHForTokens{value: msgValue}(
        //                             amountsOut[amountsOut.length -1],
        //                             pls_stab_path, //address[] calldata path,
        //                             address(this), // to
        //                             block.timestamp + 300
        //                         );
        // uint64 stableAmntOut = _uint64_from_uint256(amntOut[amntOut.length - 1]); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.

        // // use VAULT remote
        // // edit_ACCT_USD_BALANCES(_depositor, stableAmntOut, true); // true = add
        // ACCT_USD_BALANCES[_depositor] += stableAmntOut;
        // ACCOUNTS = LIB._addAddressToArraySafe(_depositor, ACCOUNTS, true); // true = no dups

        // emit DepositReceived(_depositor, msgValue, stableAmntOut);

        // // NOTE: at this point, the vault has the deposited stable and the vault has stored account balances

    }
    
    /** ref: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
         The receive function is executed on a call to the contract with empty calldata. 
         This is the function that is executed on plain Ether transfers (e.g. via .send() or .transfer()). 
         If no such function exists, but a payable fallback function exists, 
          the fallback function will be called on a plain Ether transfer. 
         If neither a receive Ether nor a payable fallback function is present, 
          the contract cannot receive Ether through a transaction that does not represent 
          a payable function call and throws an exception.
     */
    // handle contract USD value deposits (convert PLS to USD stable)
    // receive() external payable {
    //     // extract PLS value sent
    //     uint256 amntIn = msg.value;
    // }
    function deposit(address _depositor) public payable {
        // address _depositor = msg.sender;
        uint256 msgValue = msg.value;

        // perform swap from PLS to stable & send to vault
        // address[2] memory pls_stab_path_x = [TOK_WPLS, CONF.DEPOSIT_USD_STABLE()];
        address[] memory pls_stab_path = new address[](2);
        pls_stab_path[0] = TOK_WPLS; // note: WPLS required for 'swapExactETHForTokens'
        pls_stab_path[1] = CONF.DEPOSIT_USD_STABLE();
        IUniswapV2Router02 swapRouter = IUniswapV2Router02(CONF.DEPOSIT_ROUTER());
        uint256[] memory amountsOut = swapRouter.getAmountsOut(msgValue, pls_stab_path); // quote swap
        IERC20(address(pls_stab_path[0])).approve(address(swapRouter), msgValue);
        uint[] memory amntOut = swapRouter.swapExactETHForTokens{value: msgValue}(
                                    amountsOut[amountsOut.length -1],
                                    pls_stab_path, //address[] calldata path,
                                    address(this), // to (receiver)
                                    block.timestamp + 300
                                );
        // uint64 stableAmntOut = _uint64_from_uint256(amntOut[amntOut.length - 1]); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
        uint64 stableAmntOut = _uint64_from_uint256(_normalizeStableAmnt(IERC20x(pls_stab_path[1]).decimals(), amntOut[amntOut.length - 1], _usd_decimals())); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
        
        // update account balance
        ACCT_USD_BALANCES[_depositor] += stableAmntOut;
        ACCOUNTS = LIB._addAddressToArraySafe(_depositor, ACCOUNTS, true); // true = no dups

        emit DepositReceived(_depositor, msgValue, stableAmntOut);

        // NOTE: at this point, the vault has the deposited stable and the vault has stored account balances


        // uint256 msgValue = msg.value;
        // require(msgValue > 0, ' nothing? :& ');
        // // extract PLS value sent
        // // uint256 amntIn = msgValue;

        // // get whitelisted stable with lowest market value (ie. receive most stable for swap)
        // // address usdStable = LIB._getStableTokenLowMarketValue(CONF.WHITELIST_USD_STABLES, CONF.USWAP_V2_ROUTERS);
        // // (address[] memory stables,, address[] memory routers) = CONF.getDexAddies();
        // // address usdStable = LIB._getStableTokenLowMarketValue(stables, routers);
        // // address usdStable = LIB._getStableTokenLowMarketValue(CONF.get_WHITELIST_USD_STABLES(), CONF.get_USWAP_V2_ROUTERS());
        //     // LEFT OFF HERE ... running out of gas ^
        // // address usdStable = CONF.VAULT_getStableTokenLowMarketValue();
        // // address usdStable = CONF.DEPOSIT_USD_STABLE();

        // // perform swap from PLS to stable & send to vault
        // // uint64 stableAmntOut = _uint64_from_uint256(_exeSwapPlsForStable(amntIn, usdStable)); // _normalizeStableAmnt
        // address[] memory pls_stab_path = new address[](2);
        // pls_stab_path[0] = TOK_WPLS;
        // pls_stab_path[1] = CONF.DEPOSIT_USD_STABLE();
        // // uint64 stableAmntOut = _uint64_from_uint256(_exeSwapTokForTok(msgValue, pls_stab_path, address(this), false)); // false = _fromUsdAcctBal
        // uint64 stableAmntOut = _uint64_from_uint256(_swap_v2_wrap(pls_stab_path, CONF.DEPOSIT_ROUTER(), msgValue, address(this), false)); // true = fromETH        

        //     // function _exeSwapTokForTok(uint256 _tokAmntIn, address[] memory _swap_path, address _receiver, bool _fromUsdAcctBal) private returns (uint256) {

        // // use VAULT remote
        // edit_ACCT_USD_BALANCES(_depositor, stableAmntOut, true); // true = add
        // ACCOUNTS = LIB._addAddressToArraySafe(_depositor, ACCOUNTS, true); // true = no dups

        // emit DepositReceived(_depositor, msgValue, stableAmntOut);

        // // NOTE: at this point, the vault has the deposited stable and the vault has stored account balances
    }
    // function exeArbPriceParityForTicket(ICallitLib.MARKET memory mark, uint16 tickIdx, uint64 _minUsdTargPrice, address _sender) external onlyFactory returns(uint64, uint64, uint64, uint64, uint64) { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
    function exeArbPriceParityForTicket(ICallitLib.MARKET memory mark, uint16 tickIdx, address _sender) external onlyFactory returns(uint64, uint64, uint64, uint64, uint64) { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
        // calc target usd price for _ticket (in order to bring this market to price parity)
        //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        // uint64 ticketTargetPriceUSD = _getCallTicketUsdTargetPrice(mark.marketResults.resultOptionTokens, mark.marketResults.resultTokenLPs, mark.marketResults.resultTokenUsdStables, tickIdx, _minUsdTargPrice);
        // uint64 ticketTargetPriceUSD = _getCallTicketUsdTargetPrice(mark.marketResults.resultOptionTokens, mark.marketResults.resultTokenLPs, mark.marketResults.resultTokenUsdStables, tickIdx, MIN_USD_CALL_TICK_TARGET_PRICE);
        uint64 ticketTargetPriceUSD = LIB._getCallTicketUsdTargetPrice(mark, tickIdx, CONF.MIN_USD_CALL_TICK_TARGET_PRICE(), _usd_decimals());
        

        // calc # of _ticket tokens to mint for DEX sell (to bring _ticket to price parity w/ target price)
        //  mint tokensToMint count to this VAULT and sell on DEX on behalf of _arbExecuter
        //  deduct fees and pay _arbExecuter (_sender)
        (uint64 tokensToMint, uint64 total_usd_cost) = _performTicketMint(mark, tickIdx, ticketTargetPriceUSD, _sender);
        (uint64 gross_stab_amnt_out, uint64 net_usd_profits) = _performTicketMintedDexSell(mark, tickIdx, tokensToMint, total_usd_cost, _sender);
        return (ticketTargetPriceUSD, tokensToMint, total_usd_cost, gross_stab_amnt_out, net_usd_profits);
    }
    function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok, address _sender) external onlyFactory returns(uint64, uint256) {
        // NOTE: *WARNING* if this require fails ... 
        //  then this promo code cannot be used until PERC_PROMO_BUY_FEE is lowered accordingly
        require(_percReward + CONF.PERC_PROMO_BUY_FEE() < 10000, ' buy promo fee perc mismatch :o ');

        // calc influencer reward from _usdAmnt to send to promo.promotor
        //  and update amount owed for this _promoCodeHash
        uint64 usdReward = LIB._perc_of_uint64(_percReward, _usdAmnt);
        PROMO_USD_OWED[_promoCodeHash] += usdReward;
        emit PromoRewardLogged(_promoCodeHash, usdReward, _promotor, _sender, _ticket);

        // deduct usdReward & promo buy fee _usdAmnt
        uint64 net_usdAmnt = _usdAmnt - usdReward;
        net_usdAmnt = LIB._deductFeePerc(net_usdAmnt, CONF.PERC_PROMO_BUY_FEE(), _usdAmnt);

        // verifiy this VAULT contract holds enough tick_stable_tok for DEX buy
        //  if not, swap another contract held stable that can indeed cover
        // address tick_stable_tok = mark.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
        // address tick_stable_tok = mark.marketResults.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
        uint256 contr_stab_bal = IERC20(_tick_stable_tok).balanceOf(address(this)); 
        if (contr_stab_bal < net_usdAmnt) { // not enough tick_stable_tok to cover 'net_usdAmnt' buy
            uint64 net_usdAmnt_needed = net_usdAmnt - _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_tick_stable_tok).decimals(), contr_stab_bal, _usd_decimals()));
            // (uint256 stab_amnt_out, address stab_swap_from)  = _swapBestStableForTickStable(net_usdAmnt_needed, _tick_stable_tok);
            _swapBestStableForTickStable(net_usdAmnt_needed, _tick_stable_tok);
            // emit AlertStableSwap(net_usdAmnt, contr_stab_bal, stab_swap_from, _tick_stable_tok, net_usdAmnt_needed, stab_amnt_out);

            // verify
            require(IERC20(_tick_stable_tok).balanceOf(address(this)) >= net_usdAmnt, ' tick-stable swap failed :[] ' );
        }

        // swap remaining net_usdAmnt of tick_stable_tok for _ticket on DEX (_ticket receiver = _sender)
        // address[] memory usd_tick_path = [tick_stable_tok, _ticket]; // ref: https://ethereum.stackexchange.com/a/28048
        address[] memory usd_tick_path = new address[](2);
        usd_tick_path[0] = _tick_stable_tok;
        usd_tick_path[1] = _ticket; // NOTE: not swapping for 'this' contract
        // uint256 tick_amnt_out = _exeSwapStableForTok(net_usdAmnt, usd_tick_path, _sender); // buyer = _receiver
        uint256 tick_amnt_out = _exeSwapTokForTok(net_usdAmnt, usd_tick_path, _sender, true); // buyer = _receiver // true = _fromUsdAcctBal
        

        // deduct full OG input _usdAmnt from account balance
        edit_ACCT_USD_BALANCES(_sender, _usdAmnt, false); // false = sub

        return (net_usdAmnt, tick_amnt_out);
    }
    function payPromoUsdReward(address _sender, address _promoCodeHash, uint64 _usdReward, address _receiver) external onlyFactory returns(uint64) {
        uint64 usdOwed = PROMO_USD_OWED[_promoCodeHash];
        require(_promoCodeHash != address(0) && usdOwed > 0 && _usdReward <= usdOwed, ' not enough owed ;[ ');
        uint64 net_usdReward = LIB._deductFeePerc(usdOwed, CONF.PERC_PROMO_CLAIM_FEE(), usdOwed);
        _payUsdReward(_sender, net_usdReward, _receiver); // pay w/ lowest value whitelist stable held (returns on 0 reward)
        PROMO_USD_OWED[_promoCodeHash] = usdOwed - _usdReward; // deduct entire _usdReward from owed (not just net)
        return net_usdReward; // return what was actually paid (ie. net)
    }
    // note: migrate to CallitBank
    function _payUsdReward(address _sender, uint64 _usdReward, address _receiver) public onlyFactory() {
        if (_usdReward == 0) {
            // emit AlertZeroReward(_sender, _usdReward, _receiver);
            return;
        }
        // Get stable to work with ... (any stable that covers 'usdReward' is fine)
        //  NOTE: if no single stable can cover 'usdReward', lowStableHeld == 0x0, 
        // address lowStableHeld = _getStableHeldLowMarketValue(_usdReward, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        (address[] memory stables, address[] memory routers) = CONF.getDexAddies();
        address lowStableHeld = _getStableHeldHighLowMarketValue(_usdReward, stables, routers, false); // 3 loops embedded // false = low mark val
        
        require(lowStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // pay _receiver their usdReward w/ lowStableHeld (any stable thats covered)
        IERC20(lowStableHeld).transfer(_receiver, _normalizeStableAmnt(_usd_decimals(), _usdReward, IERC20x(lowStableHeld).decimals()));
    }
    // function _getCallTicketUsdTargetPrice(address[] memory _resultTickets, address[] memory _pairAddresses, address[] memory _resultStables, uint16 _tickIdx, uint64 _usdMinTargetPrice) private view returns(uint64) {
    //     // exeArbPriceParityForTicket
    //     require(_resultTickets.length == _pairAddresses.length, ' tick/pair arr length mismatch :o ');
    //     // algorithmic logic ...
    //     //  calc sum of usd value dex prices for all addresses in '_mark.resultOptionTokens' (except _ticket)
    //     //   -> input _ticket target price = 1 - SUM(all prices except _ticket)
    //     //   -> if result target price <= 0, then set/return input _ticket target price = $0.01

    //     // address[] memory tickets = _mark.marketResults.resultOptionTokens;
    //     address[] memory tickets = _resultTickets;
    //     uint64 alt_sum = 0;
    //     for(uint16 i=0; i < tickets.length;) { // MAX_RESULTS is uint16
    //         if (tickets[i] != _resultTickets[_tickIdx]) {
    //             address pairAddress = _pairAddresses[i];
    //             uint256 usdAmountsOut = LIB._estimateLastPriceForTCK(pairAddress); // invokes _normalizeStableAmnt
    //             alt_sum += _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_resultStables[i]], usdAmountsOut, _usd_decimals()));
    //         }
            
    //         unchecked {i++;}
    //     }

    //     // NOTE: returns negative if alt_sum is greater than 1
    //     //  edge case should be handle in caller
    //     int64 target_price = 1 - int64(alt_sum);
    //     return target_price > 0 ? uint64(target_price) : _usdMinTargetPrice; // note: min is likely 10000 (ie. $0.010000 w/ _usd_decimals() = 6)
    // }


    // LEFT OFF HERE …. makeNewMarket integration
    //     trying to migrate for loop in DELEGATE over to VAULT 
    //         so that the loop doesn’t call another contract address over and over again
    //         ie. so all activity in the loop does not require additional contract calls
    //     hoping that this will help solve sudden code lock or halt that is occurring 
    //         in the during makeNewMarket call
    //     problem now: after migration…
    //         VAULT is now compiling with file size error
    //         DELEGATE is indeed compiling just fine still
        
    // function createDexLP(uint256 _resultCnt, uint64 _net_usdAmntLP) external onlyFactory() returns(ICallitLib.MARKET_RESULTS memory){
    // function createDexLP(string[] calldata _resultLabels, uint64 _net_usdAmntLP) external onlyFactory() returns(ICallitLib.MARKET_RESULTS memory){
    function createDexLP(string[] calldata _resultLabels, uint256 _net_usdAmntLP, uint16 _ratioLpTokPerUsd) external onlyFactory() returns(ICallitLib.MARKET_RESULTS memory){

        // // note: makeNewMarket
        // // temp-arrays for 'makeNewMarket' support
        // address[] memory resultOptionTokens = new address[](_resultLabels.length);
        // address[] memory resultTokenLPs = new address[](_resultLabels.length);
        // address[] memory resultTokenRouters = new address[](_resultLabels.length);
        // address[] memory resultTokenFactories = new address[](_resultLabels.length);

        // address[] memory resultTokenUsdStables = new address[](_resultLabels.length);
        // uint64 [] memory resultTokenVotes = new uint64[](_resultLabels.length);

        // note: makeNewMarket
        // temp-arrays for 'makeNewMarket' support
        resultOptionTokens = new address[](_resultLabels.length);
        resultTokenLPs = new address[](_resultLabels.length);
        resultTokenRouters = new address[](_resultLabels.length);
        resultTokenUsdStables = new address[](_resultLabels.length);
        resultTokenVotes = new uint64[](_resultLabels.length);

        // Get/calc amounts for each initial LP (usd and token amounts)
        (uint256 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultLabels.length, _ratioLpTokPerUsd);

        // get router & stable to be used for each initial LP
        address router_addr = CONF.NEW_TICK_UNISWAP_V2_ROUTER();
        address stable_addr = CONF.NEW_TICK_USD_STABLE();
        IERC20x stable = IERC20x(stable_addr);
        uint8 stable_decs = stable.decimals();

        // normalize internal tracking decimals to match stable contract's decimals
        usdAmount = _normalizeStableAmnt(_usd_decimals(), usdAmount, stable_decs);
        _net_usdAmntLP = _normalizeStableAmnt(_usd_decimals(), _net_usdAmntLP, stable_decs);

        // approve router to spend this vault's total 'stable' needed
        //  note: approving '_net_usdAmntLP' for total liquidity needed
        //        not just 'usdAmount' for each individual LP created
        stable.approve(router_addr, _net_usdAmntLP);

        // Loop through _resultLabels and deploy ERC20s for each (and generate LP)
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
        // for (uint16 i = 0; i < _resultCnt;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // // Get/calc amounts for initial LP (usd and token amounts)
            // (uint256 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultLabels.length, _ratioLpTokPerUsd);
            // (uint256 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultLabels.length, RATIO_LP_TOK_PER_USD);
            // (uint64 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultCnt, RATIO_LP_TOK_PER_USD);

            // Deploy a new ERC20 token for each result label (init supply = tokenAmount; transfered to VAULT to create LP)
            // (string memory tok_name, string memory tok_symb) = LIB._genTokenNameSymbol(_sender, _mark_num, i, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
            // address new_tick_tok = address (new CallitTicket(tokenAmount, address(this), tok_name, tok_symb));
            // address new_tick_tok = address (new CallitTicket(tokenAmount, address(VAULT), ADDR_FACT, "tTICKET_0", "tTCK0"));
            // address new_tick_tok = address (new CallitTicket(tokenAmount, address(this), ADDR_FACT, "tTICKET_0", "tTCK0"));
            address new_tick_tok = CONF.VAULT_deployTicket(tokenAmount, "tTICKET_0", "tTCK0");
                // LEFT OFF HERE ... needs to add 'LIB._genTokenNameSymbol' integration
            
            // Create DEX LP for new ticket token (from VAULT, using VAULT's stables, and VAULT's minted new tick init supply)
            // address pairAddr = _createDexLP(NEW_TICK_UNISWAP_V2_ROUTER, NEW_TICK_UNISWAP_V2_FACTORY, new_tick_tok, NEW_TICK_USD_STABLE, tokenAmount, usdAmount);

            /** FROM VAULT */
            // address router_addr = CONF.NEW_TICK_UNISWAP_V2_ROUTER();
            // address stable_addr = CONF.NEW_TICK_USD_STABLE();
            // IERC20x stable = IERC20x(stable_addr);

            // // normalize internal tracking decimals to stable contract decimals
            // usdAmount = _normalizeStableAmnt(_usd_decimals(), usdAmount, stable.decimals());

            // // approve router to spend this vault's tokens needed
            // stable.approve(router_addr, usdAmount);

            // approve router to spend this vault's new ticket tokens needed
            IERC20(new_tick_tok).approve(router_addr, tokenAmount);

            // add liquidity (internally used factory to create pair address)
            IUniswapV2Router02 router = IUniswapV2Router02(router_addr);
            router.addLiquidity(
                new_tick_tok,                // Token address
                stable_addr,           // Assuming ETH as the second asset (or replace with another token address)
                tokenAmount,          // Desired _token amount
                usdAmount,            // Desired ETH amount (converted from USD or directly provided)
                0,                    // Min amount of _token (slippage tolerance)
                0,                    // Min amount of ETH (slippage tolerance)
                address(this),        // Recipient of liquidity tokens
                block.timestamp + 300 // Deadline (5 minutes from now)
            );

            // retreive pair address from router's factory
            address pairAddr = IUniswapV2Factory(router.factory()).getPair(new_tick_tok, stable_addr);
                // address pairAddr = address(0x3700000000000000000000000000000000000037);
            
            // map new ticket created to its pair address created
            TICK_PAIR_ADDR[new_tick_tok] = pairAddr;
            /** _FROM VAULT_ */

            // verify ERC20 & LP was created
            require(new_tick_tok != address(0) && pairAddr != address(0), ' err: gen tick tok | lp :( ');

            // set this ticket option's settings to index 'i' in storage temp results array
            //  temp array will be added to MARKET struct and returned (then deleted on function return)
            resultOptionTokens[i] = new_tick_tok;
            resultTokenLPs[i] = pairAddr;

            resultTokenRouters[i] = router_addr;
            // resultTokenFactories[i] = CONF.NEW_TICK_UNISWAP_V2_FACTORY();
            resultTokenUsdStables[i] = stable_addr;
            resultTokenVotes[i] = 0;

            // NOTE: set ticket to maker mapping, handled from factory

            unchecked {i++;}
        }

        // deduct full OG usd input from account balance
        // edit_ACCT_USD_BALANCES(_sender, _usdAmntLP, false); // false = sub

        // ICallitLib.MARKET_RESULTS memory mark_results = ICallitLib.MARKET_RESULTS(_resultLabels, new string[](_resultLabels.length), resultOptionTokens, resultTokenLPs, resultTokenRouters, resultTokenFactories, resultTokenUsdStables, resultTokenVotes);
        ICallitLib.MARKET_RESULTS memory mark_results = ICallitLib.MARKET_RESULTS(_resultLabels, new string[](_resultLabels.length), resultOptionTokens, resultTokenLPs, resultTokenRouters, resultTokenUsdStables, resultTokenVotes);
        delete resultOptionTokens;
        delete resultTokenLPs;
        delete resultTokenRouters;
        // delete resultTokenFactories;
        delete resultTokenUsdStables;
        delete resultTokenVotes;
        return mark_results;
    }
    // note: migrate to CallitBank at least, and maybe CallitLib as well
    // Assumed helper functions (implementations not shown)
    // function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) external onlyFactory returns (address) {
    // function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) private onlyFactory returns (address) {
    //     // declare factory & router
    //     // IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(_uswapV2Router);
    //     // IUniswapV2Factory uniswapFactory = IUniswapV2Factory(_uswapv2Factory);

    //     // normalize decimals _usdStable token requirements
    //     _usdAmount = _normalizeStableAmnt(_usd_decimals(), _usdAmount, IERC20x(_usdStable]);

    //     // Approve tokens for Uniswap Router
    //     IERC20(_token).approve(_uswapV2Router, _tokenAmount);
    //     IERC20(_usdStable).approve(_uswapV2Router, _usdAmount);
    //     // Assuming you have a way to convert USD to ETH or a stablecoin in the contract
            
    //     // create pair for the pool (note: ROUTER.addLiquidity should invoke FACTORY.createPair if doesn't exist yet)
    //     // address pairAddr = uniswapFactory.createPair(_token, _usdStable);

    //     // Add liquidity to the pool
    //     // (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter.addLiquidity(
    //     // uniswapRouter.addLiquidity(
    //     IUniswapV2Router02(_uswapV2Router).addLiquidity(
    //         _token,                // Token address
    //         _usdStable,           // Assuming ETH as the second asset (or replace with another token address)
    //         _tokenAmount,          // Desired _token amount
    //         _usdAmount,            // Desired ETH amount (converted from USD or directly provided)
    //         0,                    // Min amount of _token (slippage tolerance)
    //         0,                    // Min amount of ETH (slippage tolerance)
    //         address(this),        // Recipient of liquidity tokens
    //         block.timestamp + 300 // Deadline (5 minutes from now)
    //     );

    //     // Return the address of the liquidity pool
    //     // For Uniswap V2, the LP address is not directly returned but you can obtain it by querying the factory.
    //     // This example assumes you store or use the liquidity tokens or LP in your contract directly.

    //     // The actual LP address retrieval would require interaction with Uniswap V2 Factory.
    //     // For simplicity, we're returning a placeholder.
    //     // Retrieve the LP address
    //     // address pairAddr = uniswapFactory.getPair(_token, _usdStable);
    //     address pairAddr = IUniswapV2Factory(_uswapv2Factory).getPair(_token, _usdStable);

    //     // LEFT OFF HERE ... this didn't work ^
    //     //  ALSO tried to set pairAddr to something static (not 0x0), and also not make that .getPair call
    //     //      ... still didn't work (below)
    //     // address paidAddr = address(0x0000000000000000000000000000000000000000); // note: caller can't receive 0x0 return
    //     // address pairAddr = address(0x3700000000000000000000000000000000000037);
        
    //     TICK_PAIR_ADDR[_token] = pairAddr; // log ticket to pair address mapping
    //     return pairAddr;
    // }
    function _exePullLiquidityFromLP(address _tokenRouter, address _pairAddress, address _token, address _usdStable) external onlyFactory returns(uint256) {
        // IUniswapV2Factory uniswapFactory = IUniswapV2Factory(mark.resultTokenFactories[i]);
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(_tokenRouter);
        
        // pull liquidity from pairAddress
        IERC20 pairToken = IERC20(_pairAddress);
        uint256 liquidity = pairToken.balanceOf(address(this));  // Get the contract's balance of the LP tokens
        
        // Approve the router to spend the LP tokens
        pairToken.approve(address(uniswapRouter), liquidity);
        
        // Retrieve the token pair
        address token0 = IUniswapV2Pair(_pairAddress).token0();
        address token1 = IUniswapV2Pair(_pairAddress).token1();

        // check to make sure that token0 is the 'ticket' & token1 is the 'stable'
        require(_token == token0 && _usdStable == token1, ' pair token mismatch w/ MARKET tck:usd :*() ');

        // get OG stable balance, so we can verify later
        uint256 OG_stable_bal = IERC20(_usdStable).balanceOf(address(this));

        // Remove liquidity
        // NOTE: amountToken1 = usd stable amount received (which is all we care about)
        (, uint256 amountToken1) = uniswapRouter.removeLiquidity(
            token0,
            token1,
            liquidity,
            0, // Min amount of token0, to prevent slippage (adjust based on your needs)
            0, // Min amount of token1, to prevent slippage (adjust based on your needs)
            address(this), // Send tokens to the contract itself or a specified recipient
            block.timestamp + 300 // Deadline (5 minutes from now)
        );

        // verify correct ticket token stable was pulled and recieved
        require(IERC20(_usdStable).balanceOf(address(this)) >= OG_stable_bal, ' stab bal mismatch after liq pull :+( ');
        return amountToken1;
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (VAULT)
    /* -------------------------------------------------------- */
    function _performTicketMint(ICallitLib.MARKET memory _mark, uint64 _tickIdx, uint64 _ticketTargetPriceUSD, address _arbExecuter) private returns(uint64,uint64) {
        // calc # of _ticket tokens to mint for DEX sell (to bring _ticket to price parity w/ target price)
        uint256 _usdTickTargPrice_18 = _normalizeStableAmnt(_usd_decimals(), _ticketTargetPriceUSD, 18);
        uint64 tokensToMint = _uint64_from_uint256(_normalizeStableAmnt(18, LIB._calculateTokensToMint(_mark.marketResults.resultTokenLPs[_tickIdx], _usdTickTargPrice_18), _usd_decimals()));

        // calc price to charge _arbExecuter for minting tokensToMint
        //  then deduct that amount from their account balance
        uint64 total_usd_cost = _ticketTargetPriceUSD * tokensToMint;
        if (_arbExecuter != CONF.KEEPER()) { // free for KEEPER
            // verify _arbExecuter usd balance covers contract sale of minted discounted tokens
            //  NOTE: _arbExecuter is buying 'tokensToMint' amount @ price = '_ticketTargetPriceUSD', from this contract
            require(ACCT_USD_BALANCES[_arbExecuter] >= total_usd_cost, ' low balance :( ');

            // deduce that sale amount from their account balance
            // CALLIT_VAULT.ACCT_USD_BALANCES[_arbExecuter] -= total_usd_cost; 
            edit_ACCT_USD_BALANCES(_arbExecuter, total_usd_cost, false); // false = sub
        }
        
        // mint tokensToMint count to this VAULT and sell on DEX on behalf of _arbExecuter
        //  NOTE: receiver == address(this), NOT _arbExecuter (need to deduct fees before paying _arbExecuter)
        //  NOTE: deduct fees and pay _arbExecuter in '_performTicketMintedDexSell'
        // ICallitTicket cTicket = ICallitTicket(_ticket);
        ICallitTicket cTicket = ICallitTicket(_mark.marketResults.resultOptionTokens[_tickIdx]);
        // CallitTicket cTicket = CallitTicket(_mark.marketResults.resultOptionTokens[_tickIdx]);
        cTicket.mintForPriceParity(address(this), tokensToMint);
        require(cTicket.balanceOf(address(this)) >= tokensToMint, ' err: cTicket mint :<> ');
        return (tokensToMint, total_usd_cost);
    }
    function _performTicketMintedDexSell(ICallitLib.MARKET memory _mark, uint64 _tickIdx, uint64 tokensToMint, uint64 total_usd_cost, address _arbExecuter) private returns(uint64,uint64) {
        // mint tokensToMint count to this VAULT and sell on DEX on behalf of _arbExecuter
        //  NOTE: receiver == address(this), NOT _arbExecuter (need to deduct fees before paying _arbExecuter)
        //  NOTE: deduct fees and pay _arbExecuter in '_performTicketMintedDexSell'
        address[] memory tok_stab_path = new address[](2);
        // tok_stab_path[0] = _ticket;
        tok_stab_path[0] = _mark.marketResults.resultOptionTokens[_tickIdx];
        tok_stab_path[1] = _mark.marketResults.resultTokenUsdStables[_tickIdx];
        uint256 usdAmntOut = _exeSwapTokForStable_router(tokensToMint, tok_stab_path, address(this), _mark.marketResults.resultTokenRouters[_tickIdx]); // swap tick: use specific router tck:tick-stable
        uint64 gross_stab_amnt_out = _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_mark.marketResults.resultTokenUsdStables[_tickIdx]).decimals(), usdAmntOut, _usd_decimals()));

        // calc & send net profits to _arbExecuter
        //  NOTE: _arbExecuter gets all of 'gross_stab_amnt_out' (since the contract keeps total_usd_cost)
        //  NOTE: 'net_usd_profits' is _arbExecuter's profit (after additional fees)
        uint64 net_usd_profits = LIB._deductFeePerc(gross_stab_amnt_out, CONF.PERC_ARB_EXE_FEE(), gross_stab_amnt_out);
        require(net_usd_profits > total_usd_cost, ' no profit from arb attempt :( '); // verify _arbExecuter profits would occur
        IERC20(_mark.marketResults.resultTokenUsdStables[_tickIdx]).transfer(_arbExecuter, net_usd_profits);
        return (gross_stab_amnt_out, net_usd_profits);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (legacy)
    /* -------------------------------------------------------- */
    function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) private pure returns (uint256) {
        require(_fromDecimals > 0 && _toDecimals > 0, 'err: invalid _from|toDecimals');
        if (_usdAmnt == 0) return _usdAmnt; // fix to allow 0 _usdAmnt (ie. no need to normalize)
        if (_fromDecimals == _toDecimals) {
            return _usdAmnt;
        } else {
            if (_fromDecimals > _toDecimals) { // _fromDecimals has more 0's
                uint256 scalingFactor = 10 ** (_fromDecimals - _toDecimals); // get the diff
                return _usdAmnt / scalingFactor; // decrease # of 0's in _usdAmnt
            }
            else { // _fromDecimals has less 0's
                uint256 scalingFactor = 10 ** (_toDecimals - _fromDecimals); // get the diff
                return _usdAmnt * scalingFactor; // increase # of 0's in _usdAmnt
            }
        }
    }
    function _uint64_from_uint256(uint256 value) private pure returns (uint64) {
        require(value <= type(uint64).max, "Value exceeds uint64 range");
        uint64 convertedValue = uint64(value);
        return convertedValue;
    }
    // function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) private {
    function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) public onlyFactory() {
        if (_add) {
            require(_usdAmnt > 0, ' !add 0 :/ ' );
            ACCT_USD_BALANCES[_acct] += _usdAmnt;
        } else {
            require(ACCT_USD_BALANCES[_acct] >= _usdAmnt, ' !deduct low balance :{} ');
            ACCT_USD_BALANCES[_acct] -= _usdAmnt;    
        }
    }
    function _grossStableBalance(address[] memory _stables) private view returns (uint64) {
        uint64 gross_bal = 0;
        for (uint8 i = 0; i < _stables.length;) {
            // NOTE: more efficient algorithm taking up less stack space with local vars
            require(IERC20x(_stables[i]).decimals() > 0, ' found stable with invalid decimals :/ ');
            gross_bal += _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_stables[i]).decimals(), IERC20(_stables[i]).balanceOf(address(this)), _usd_decimals()));
            unchecked {i++;}
        }
        return gross_bal;
    }
    function _owedStableBalance() private view returns (uint64) {
        uint64 owed_bal = 0;
        for (uint256 i = 0; i < ACCOUNTS.length;) {
            owed_bal += ACCT_USD_BALANCES[ACCOUNTS[i]];
            unchecked {i++;}
        }
        return owed_bal;
    }
    // function _collectiveStableBalances(address[] memory _stables) private view returns (uint64, uint64, int64) {
    //     uint64 gross_bal = _grossStableBalance(_stables);
    //     uint64 owed_bal = _owedStableBalance();
    //     int64 net_bal = int64(gross_bal) - int64(owed_bal);
    //     // return (gross_bal, owed_bal, net_bal, totalSupply());
    //     // return (gross_bal, owed_bal, net_bal, IERC20(ADDR_FACT).totalSupply());
    //     return (gross_bal, owed_bal, net_bal);
    // }
    // function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) private { // allows duplicates
    //     if (_add) {
    //         WHITELIST_USD_STABLES = LIB._addAddressToArraySafe(_usdStable, WHITELIST_USD_STABLES, true); // true = no dups
    //         // USD_STABLES_HISTORY = LIB._addAddressToArraySafe(_usdStable, USD_STABLES_HISTORY, true); // true = no dups
    //         // USD_STABLE_DECIMALS[_usdStable] = _decimals;
    //     } else {
    //         WHITELIST_USD_STABLES = LIB._remAddressFromArray(_usdStable, WHITELIST_USD_STABLES);
    //     }
    // }
    // function _editDexRouters(address _router, address _factory, bool _add) private {
    //     require(_router != address(0x0), "0 address");
    //     if (_add) {
    //         USWAP_V2_ROUTERS = LIB._addAddressToArraySafe(_router, USWAP_V2_ROUTERS, true); // true = no dups
    //         ROUTERS_TO_FACTORY[_router] = _factory;
    //     } else {
    //         USWAP_V2_ROUTERS = LIB._remAddressFromArray(_router, USWAP_V2_ROUTERS); // removes only one & order NOT maintained
    //         delete ROUTERS_TO_FACTORY[_router];
    //     }
    // }
    function _stableHoldingsCovered(uint64 _usdAmnt, address _usdStable) private view returns (bool) {
        if (_usdStable == address(0x0)) 
            return false;
        uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, IERC20x(_usdStable).decimals());
        return IERC20(_usdStable).balanceOf(address(this)) >= usdAmnt_;
    }
    // function _getTokMarketValueForUsdAmnt(uint256 _usdAmnt, address _usdStable, address[] memory _stab_tok_path) private view returns (uint256) {
    //     uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, IERC20x(_usdStable]);
    //     (, uint256 tok_amnt) = LIB._best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);
    //     return tok_amnt; 
    // }

    /* -------------------------------------------------------- */
    /* PRIVATE - DEX SWAP SUPPORT                                    
    /* -------------------------------------------------------- */
    function _getStableHeldHighLowMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers, bool _getHigh) private view returns (address) {

        address[] memory _stablesHeld;
        for (uint8 i=0; i < _stables.length;) {
            if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
                _stablesHeld = LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

            unchecked {
                i++;
            }
        }
        if (_getHigh) return LIB._getStableTokenHighMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
        else return LIB._getStableTokenLowMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    }
    // function _getStableHeldHighMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {

    //     address[] memory _stablesHeld;
    //     for (uint8 i=0; i < _stables.length;) {
    //         if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
    //             _stablesHeld = LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

    //         unchecked {
    //             i++;
    //         }
    //     }
    //     return LIB._getStableTokenHighMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    // }
    // function _getStableHeldLowMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {
    //     // NOTE: if nothing in _stables can cover _usdAmntReq, then returns address(0x0)
    //     address[] memory _stablesHeld;
    //     for (uint8 i=0; i < _stables.length;) {
    //         if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
    //             _stablesHeld = LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

    //         unchecked {
    //             i++;
    //         }
    //     }
    //     return LIB._getStableTokenLowMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    // }
    // note: migrate to CallitBank
    function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) private returns(uint256, address){
        // Get stable to work with ... (any stable that covers '_usdAmnt' is fine)
        //  NOTE: if no single stable can cover '_usdAmnt', highStableHeld == 0x0, 
        // address highStableHeld = _getStableHeldHighMarketValue(_usdAmnt, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        (address[] memory stables, address[] memory routers) = CONF.getDexAddies();
        address highStableHeld = _getStableHeldHighLowMarketValue(_usdAmnt, stables, routers, true); // 3 loops embedded // true = high mark val
        
        require(highStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // create path and perform stable-to-stable swap
        // address[2] memory stab_stab_path = [highStableHeld, _tickStable];
        address[] memory stab_stab_path = new address[](2);
        stab_stab_path[0] = highStableHeld;
        stab_stab_path[1] = _tickStable;
        uint256 stab_amnt_out = _exeSwapTokForTok(_usdAmnt, stab_stab_path, address(this), true); // no tick: use best from USWAP_V2_ROUTERS
        return (stab_amnt_out,highStableHeld);
    }
    // function _exeSwapPlsForStable(uint256 _plsAmnt, address _usdStable) private returns (uint256) {
    //     address[] memory pls_stab_path = new address[](2);
    //     pls_stab_path[0] = TOK_WPLS;
    //     pls_stab_path[1] = _usdStable;
    //     // (uint8 rtrIdx,) = LIB._best_swap_v2_router_idx_quote(pls_stab_path, _plsAmnt, USWAP_V2_ROUTERS);
    //     // uint256 stab_amnt_out = _swap_v2_wrap(pls_stab_path, USWAP_V2_ROUTERS[rtrIdx], _plsAmnt, address(this), true); // true = fromETH
    //     uint256 stab_amnt_out = _exeSwapTokForTok(_plsAmnt, pls_stab_path, address(this));
    //     stab_amnt_out = _normalizeStableAmnt(IERC20x(_usdStable).decimals(), stab_amnt_out, _usd_decimals());
    //     return stab_amnt_out;
    // }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapTokForTok(uint256 _tokAmntIn, address[] memory _swap_path, address _receiver, bool _fromUsdAcctBal) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_swap_path[1] != address(this), ' !swap for this :p ');
        
        if (_fromUsdAcctBal) { // required: _swap_path[0] must be a stable
            _tokAmntIn = _normalizeStableAmnt(_usd_decimals(), _tokAmntIn, IERC20x(_swap_path[0]).decimals());
        }
        // (,, address[] memory routers) = CONF.getDexAddies();
        (uint8 rtrIdx,) = LIB._best_swap_v2_router_idx_quote(_swap_path, _tokAmntIn, CONF.get_USWAP_V2_ROUTERS());
        uint256 stable_amnt_out = _swap_v2_wrap(_swap_path, CONF.USWAP_V2_ROUTERS(rtrIdx), _tokAmntIn, _receiver, false); // true = fromETH        
        return stable_amnt_out;
    }
    // // generic: gets best from USWAP_V2_ROUTERS to perform trade
    // function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) private returns (uint256) {
    //     address usdStable = _stab_tok_path[0]; // required: _stab_tok_path[0] must be a stable
    //     uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, IERC20x(usdStable).decimals());
    //     (uint8 rtrIdx,) = LIB._best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);

    //     // NOTE: algo to account for contracts unable to be a receiver of its own token in UniswapV2Pool.sol
    //     // if out token in _stab_tok_path is BST, then swap w/ SWAP_DELEGATE as reciever,
    //     //   and then get tok_amnt_out from delegate (USER_maintenance)
    //     // else, swap with BST address(this) as receiver 
    //     // if (_stab_tok_path[_stab_tok_path.length-1] == address(this) && _receiver == address(this))  {
    //     //     uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, SWAP_DELEGATE, false); // true = fromETH
    //     //     SWAPD.USER_maintenance(tok_amnt_out, _stab_tok_path[_stab_tok_path.length-1]);
    //     //     return tok_amnt_out;
    //     // } else {
    //     //     uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
    //     //     return tok_amnt_out;
    //     // }

    //     uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
    //     return tok_amnt_out;
    // }
    // specify router to use
    function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        uint256 tok_amnt_out = _swap_v2_wrap(_tok_stab_path, _router, _tokAmnt, _receiver, false); // true = fromETH
        return tok_amnt_out;
    }
    // // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    // function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) private view returns (address) {
    //     // traverse _stables & select stable w/ the lowest market value
    //     uint256 curr_high_tok_val = 0;
    //     address curr_low_val_stable = address(0x0);
    //     for (uint8 i=0; i < _stables.length;) {
    //         address stable_addr = _stables[i];
    //         if (stable_addr == address(0)) { continue; }

    //         // get quote for this stable (traverses 'uswapV2routers')
    //         //  looking for the stable that returns the most when swapped 'from' WPLS
    //         //  the more USD stable received for 1 WPLS ~= the less overall market value that stable has
    //         address[] memory wpls_stab_path = new address[](2);
    //         wpls_stab_path[0] = TOK_WPLS;
    //         wpls_stab_path[1] = stable_addr;
    //         (, uint256 tok_val) = LIB._best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
    //         if (tok_val >= curr_high_tok_val) {
    //             curr_high_tok_val = tok_val;
    //             curr_low_val_stable = stable_addr;
    //         }

    //         // NOTE: unchecked, never more than 255 (_stables)
    //         unchecked {
    //             i++;
    //         }
    //     }
    //     return curr_low_val_stable;
    // }
    
    // // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    // function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) private view returns (address) {
    //     // traverse _stables & select stable w/ the highest market value
    //     uint256 curr_low_tok_val = 0;
    //     address curr_high_val_stable = address(0x0);
    //     for (uint8 i=0; i < _stables.length;) {
    //         address stable_addr = _stables[i];
    //         if (stable_addr == address(0)) { continue; }

    //         // get quote for this stable (traverses 'uswapV2routers')
    //         //  looking for the stable that returns the least when swapped 'from' WPLS
    //         //  the less USD stable received for 1 WPLS ~= the more overall market value that stable has
    //         address[] memory wpls_stab_path = new address[](2);
    //         wpls_stab_path[0] = TOK_WPLS;
    //         wpls_stab_path[1] = stable_addr;
    //         (, uint256 tok_val) = LIB._best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
    //         if (tok_val >= curr_low_tok_val) {
    //             curr_low_tok_val = tok_val;
    //             curr_high_val_stable = stable_addr;
    //         }

    //         // NOTE: unchecked, never more than 255 (_stables)
    //         unchecked {
    //             i++;
    //         }
    //     }
    //     return curr_high_val_stable;
    // }

    // // uniswap v2 protocol based: get router w/ best quote in 'uswapV2routers'
    // function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) private view returns (uint8, uint256) {
    //     uint8 currHighIdx = 37;
    //     uint256 currHigh = 0;
    //     for (uint8 i = 0; i < _routers.length;) {
    //         uint256[] memory amountsOut = IUniswapV2Router02(_routers[i]).getAmountsOut(amount, path); // quote swap
    //         if (amountsOut[amountsOut.length-1] > currHigh) {
    //             currHigh = amountsOut[amountsOut.length-1];
    //             currHighIdx = i;
    //         }

    //         // NOTE: unchecked, never more than 255 (_routers)
    //         unchecked {
    //             i++;
    //         }
    //     }

    //     return (currHighIdx, currHigh);
    // }
    // uniwswap v2 protocol based: get quote and execute swap
    function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) private returns (uint256) {
        require(path.length >= 2, 'err: path.length :/');
        uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(amntIn, path); // quote swap
        uint256 amntOutQuote = amountsOut[amountsOut.length -1];
        // uint256 amntOutQuote = _swap_v2_quote(path, router, amntIn);
        uint256 amntOut = _swap_v2(router, path, amntIn, amntOutQuote, outReceiver, fromETH); // approve & execute swap
                
        // verifiy new balance of token received
        uint256 new_bal = IERC20(path[path.length -1]).balanceOf(outReceiver);
        require(new_bal >= amntOut, " _swap: receiver bal too low :{ ");
        
        return amntOut;
    }
    // function _swap_v2_quote(address[] memory _path, address _dexRouter, uint256 _amntIn) private view returns (uint256) {
    //     uint256[] memory amountsOut = IUniswapV2Router02(_dexRouter).getAmountsOut(_amntIn, _path); // quote swap
    //     return amountsOut[amountsOut.length -1];
    // }
    // v2: solidlycom, kyberswap, pancakeswap, sushiswap, uniswap v2, pulsex v1|v2, 9inch
    function _swap_v2(address router, address[] memory path, uint256 amntIn, uint256 amntOutMin, address outReceiver, bool fromETH) private returns (uint256) {
        IUniswapV2Router02 swapRouter = IUniswapV2Router02(router);
        
        IERC20(address(path[0])).approve(address(swapRouter), amntIn);
        uint deadline = block.timestamp + 300;
        uint[] memory amntOut;
        if (fromETH) {
            amntOut = swapRouter.swapExactETHForTokens{value: amntIn}(
                            amntOutMin,
                            path, //address[] calldata path,
                            outReceiver, // to
                            deadline
                        );
        } else {
            amntOut = swapRouter.swapExactTokensForTokens(
                            amntIn,
                            amntOutMin,
                            path, //address[] calldata path,
                            outReceiver, //  The address that will receive the output tokens after the swap. 
                            deadline
                        );
        }
        return uint256(amntOut[amntOut.length - 1]); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
    }
}