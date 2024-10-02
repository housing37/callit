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
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./node_modules/@openzeppelin/contracts/utils/Strings.sol";
// import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./CallitTicket.sol"; // imports ERC20.sol // declares ICallitVault.deposit
import "./ICallitLib.sol";
// import "./CallitToken.sol";
// import "./ICallitConfig.sol";

// interface IERC20x {
//     function decimals() external pure returns (uint8);
// }
interface ICallitConfigMarket {
    function getLiveTicketCnt() external view returns(uint256);
}
interface ISetConfig {
    function CONF_setConfig(address _conf) external;
}
interface ICallitToken {
    function setTokenNameSymbol(string calldata _name, string calldata _symbol) external;
}

contract CallitConfig {
    /* _ ADMIN SUPPORT (legacy) _ */
    address public KEEPER;
    uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    mapping(address => bool) public ADMINS; // enable/disable admins (for promo support, etc)
    string public constant tVERSION = '0.22';  
    address public ADDR_LIB = address(0xB9F716772EF2685F20C1220160103C2f229D2540); // CallitLib v0.31
    address public ADDR_VAULT = address(0x30723b05E846aF6510D912A7AE5b61b676DE25F2); // CallitVault v0.52
    address public ADDR_DELEGATE = address(0xD7468C558B10878FF3CfD60D5Bd0321018E2825f); // CallitDelegate v0.49
    address public ADDR_CALL = address(0x553F55F802D03dF4Ce69370BC4B12eE9668209c6); // CallitToken v0.20
    address public ADDR_FACT = address(0x4487086421413909FEE207260f9ECFb451FE35E6); // CallitFactory v0.67
    address public ADDR_VOTER = address(0x0000000000000000000000000000000000000000); // CallitFactory v0.0
    address public ADDR_CONFM = address(0x6dd8c30D67e39A145e11b3f086dDE48c624EC96c); // CallitConfigMarket v0.5
    // address public ADDR_CONF = address(0x05Af648CD6d5e657CfF1A011EFFc1a76956b020e); // CallitConfig v0.22
    ICallitLib private LIB = ICallitLib(ADDR_LIB);
    ICallitToken private CALL = ICallitToken(ADDR_CALL);
    ICallitConfigMarket private CONFM = ICallitConfigMarket(ADDR_CONFM);

    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    
    // note: receive / deposit
    address public DEPOSIT_USD_STABLE;
    address public DEPOSIT_ROUTER;

    // note: makeNewMarket
    // call ticket token settings (note: init supply -> RATIO_LP_TOK_PER_USD)
    address public NEW_TICK_UNISWAP_V2_ROUTER;
    address public NEW_TICK_USD_STABLE;
    string  public TOK_TICK_NAME_SEED = "TCK#";
    string  public TOK_TICK_SYMB_SEED = "CALL-TICKET";

    uint16 public PERC_REQ_CLAIM_PROMO_REWARD = 1000; // 1000 = 10% // LEFT OFF HERE ... needs keeper setter
    
    // default all fees to 0 (KEEPER setter available)
    uint16 public PERC_PROMO_CLAIM_FEE; // note: no other % fee
    uint16 public PERC_MARKET_MAKER_FEE; // note: no other % fee
    uint16 public PERC_PROMO_BUY_FEE; // note: yes other % fee (promo.percReward)
    uint16 public PERC_ARB_EXE_FEE; // note: no other % fee
    uint16 public PERC_MARKET_CLOSE_FEE; // note: yes other % fee (PERC_PRIZEPOOL_VOTERS)
    uint16 public PERC_PRIZEPOOL_VOTERS = 200; // (2%) of total prize pool allocated to voter payout _ 10000 = %100.00
    uint16 public PERC_VOTER_CLAIM_FEE; // note: no other % fee
    uint16 public PERC_WINNER_CLAIM_FEE; // note: no other % fee

    uint16 public PERC_OF_LOSER_SUPPLY_EARN_CALL = 2500; // (25%) _ 10000 = %100.00; 5000 = %50.00; 0001 = %00.01
    uint32 public RATIO_CALL_MINT_PER_LOSER = 1; // amount of all $CALL minted per loser reward (depends on PERC_OF_LOSER_SUPPLY_EARN_CALL)

    // market action mint incentives
    uint32 public RATIO_CALL_MINT_PER_ARB_EXE = 1; // amount of all $CALL minted per arb executer reward // TODO: need KEEPER setter
    uint32 public RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS = 1; // amount of all $CALL minted per market call close action reward // TODO: need KEEPER setter
    uint32 public RATIO_CALL_MINT_PER_VOTE = 1; // amount of all $CALL minted per vote reward // TODO: need KEEPER setter
    uint32 public RATIO_CALL_TOK_PER_VOTE = 100; // amount of call tokens (non-earned) required per vote count
    uint32 public RATIO_CALL_MINT_PER_MARK_CLOSE = 1; // amount of all $CALL minted per market close action reward // TODO: need KEEPER setter
    uint64 public RATIO_PROMO_USD_PER_CALL_MINT = 1000000; // (1000000 = $1.000000; 6 decimals) usd amnt buy needed per $CALL earned in promo (note: global for promos to avoid exploitations)
    uint64 public MIN_USD_PROMO_TARGET = 500000; // (1000000 = $1.000000) min target for creating promo codes ($ target = $ bets this promo brought in)

    // arb algorithm settings
    // market settings
    uint64 public MIN_USD_CALL_TICK_TARGET_PRICE = 10000; // 10000 == $0.010000 -> likely always be min (ie. $0.01 w/ _usd_decimals() = 6 decimals)
    bool    public USE_SEC_DEFAULT_VOTE_TIME = true; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    uint256 public SEC_DEFAULT_VOTE_TIME = 24 * 60 * 60; // 24 * 60 * 60 == 86,400 sec == 24 hours
    uint16  public MAX_RESULTS = 10; // max # of result options a market may have (uint16 max = ~65K -> 65,535)
    uint64  public MAX_EOA_MARKETS = type(uint8).max; // uint8 = 255 (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)

    // lp settings
    uint64 public MIN_USD_MARK_LIQ = 500000; // (500000 = $0.500000) min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    uint32 public RATIO_LP_TOK_PER_USD = 100; // # of ticket tokens per usd, minted for each individual LP deploy (ie. mint 100 tickets for liquidity, per 1 USD maker provided for liquidty)
    uint64 public RATIO_LP_USD_PER_CALL_TOK = 1000000; // (1000000 = $1.000000; 6 decimals) usd opening LP needed (mark.marketUsdAmnts.usdAmntLP) per $CALL earned by market maker
        // NOTE: utilized in 'FACTORY.closeMarketForTicket'
        // LEFT OFF HERE  ... need more requirement for market maker earning $CALL
        //  ex: maker could create $100 LP, not promote, delcare himself winner, get his $100 back and earn free $CALL)    
        //  - in addition to usd opening LP needed (above), perhaps ...
        //      1) min amount of market ticket holders
        //      2) min amount of closing LP needed (mark.marketUsdAmnts.usdAmntPrizePool)

    /* _ ACCOUNT SUPPORT (legacy) _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    // NOTE: legacy public
    // mapping(address => uint64) public ACCT_USD_BALANCES; 
    // mapping(address => uint8) public USD_STABLE_DECIMALS;
    address[] public USWAP_V2_ROUTERS;
    // mapping(address => address) public ROUTERS_TO_FACTORY;

    // NOTE: legacy private (was more secure; consider external KEEPER getter instead)
    // address[] public ACCOUNTS; 
    address[] public WHITELIST_USD_STABLES; // NOTE: private is more secure (legacy) consider KEEPER getter
    address[] public USD_STABLES_HISTORY; // NOTE: private is more secure (legacy) consider KEEPER getter

    // *WARNING* -> re-deploy means wiping promo & vote data & account handles
    // promo data storage
    mapping(address => uint64) public PROMO_USD_OWED; // maps promo code HASH to usd owed for that hash
    mapping(address => ICallitLib.PROMO) public HASH_PROMO; // store promo code hashes to their PROMO mapping
    mapping(address => address[]) public PROMOTOR_HASHES; // map promo code list to their promotor

    // market makers (etc.) can set their own handles
    mapping(address => string) public ACCT_HANDLES;

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // event KeeperTransfer(address _prev, address _new);
    // event WhitelistStableUpdated(address _usdStable, uint8 _decimals, bool _add);
    // event DexRouterUpdated(address _router, bool _add);

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR
    /* -------------------------------------------------------- */
    constructor() {
        KEEPER = msg.sender; // set KEEPER

        // add default whiteliste stable: weDAI
        _editWhitelistStables(address(0xefD766cCb38EaF1dfd701853BFCe31359239F305), true); // weDAI, true = add

        // add default routers: pulsex (x2)
        // _editDexRouters(address(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02), address(0x1715a3E4A142d8b698131108995174F37aEBA10D), true); // pulseX v1, true = add
        // _editDexRouters(address(0x165C3410fC91EF562C50559f7d2289fEbed552d9), address(0x29eA7545DEf87022BAdc76323F373EA1e707C523), true); // pulseX v2, true = add
        _editDexRouters(address(0x165C3410fC91EF562C50559f7d2289fEbed552d9), true); // pulseX v2, true = add
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

        DEPOSIT_ROUTER = NEW_TICK_UNISWAP_V2_ROUTER;
        DEPOSIT_USD_STABLE = NEW_TICK_USD_STABLE;
        

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
    modifier onlyCALL {
        require(msg.sender == ADDR_CALL, ' not allowed :{=} ');
        _;
    }
    modifier onlyVault() {
        require(msg.sender == ADDR_VAULT, " !vault ;[] ");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == ADDR_FACT, " !fact :+[ ");
        _;
    }
    // modifier onlyConfM() {
    //     require(msg.sender == ADDR_CONFM, " !fact :+[ ");
    //     _;
    // }

    function keeperCheck(uint256 _check) external view returns(bool) { 
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
            //  NOTE: _amount must be in uint precision to _erc20.decimals()
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
    function KEEPER_editAdmin(address _admin, bool _enable) external onlyKeeper {
        require(_admin != address(0), ' !_admin :{+} ');
        ADMINS[_admin] = _enable;
    }
    function KEEPER_setContracts(address _lib, address _vault, address _delegate, address _CALL, address _fact, address _voter, address _confMark, address _conf) external onlyKeeper {
        // EOA may indeed send 0x0 to "opt-in" for changing _conf address in support contracts
        //  if no _conf, update support contracts w/ current CONFIG address

        if (     _lib != address(0)) {ADDR_LIB = _lib; LIB = ICallitLib(ADDR_LIB);}
        if (   _vault != address(0)) ADDR_VAULT = _vault;
        if (_delegate != address(0)) ADDR_DELEGATE = _delegate;
        if (    _CALL != address(0)) ADDR_CALL = _CALL;
        if (    _fact != address(0)) ADDR_FACT = _fact; 
        if (   _voter != address(0)) ADDR_VOTER = _voter;
        if (    _confMark != address(0)) ADDR_CONFM = _confMark; 
        if (    _conf == address(0)) _conf = address(this);

        // NOTE: make sure everything is done and set (above) before updating contract configs
        // ISetConfig(ADDR_LIB).CONF_setConfig(_conf); // not in LIB
        ISetConfig(ADDR_VAULT).CONF_setConfig(_conf);
        ISetConfig(ADDR_DELEGATE).CONF_setConfig(_conf);
        ISetConfig(ADDR_CALL).CONF_setConfig(_conf);
        ISetConfig(ADDR_FACT).CONF_setConfig(_conf);
        ISetConfig(ADDR_VOTER).CONF_setConfig(_conf);
        ISetConfig(ADDR_CONFM).CONF_setConfig(_conf);

        // reset configs used in this contract
        LIB = ICallitLib(ADDR_LIB);
        CALL = ICallitToken(ADDR_CALL);
        CONFM = ICallitConfigMarket(ADDR_CONFM);
    }
    function KEEPER_setPercFees(uint16 _percMaker, uint16 _percPromo, uint16 _percArbExe, uint16 _percMarkClose, uint16 _percPrizeVoters, uint16 _percVoterClaim, uint16 _perWinnerClaim, uint16 _percPromoClaim) external onlyKeeper {
        // no 2 percs taken out of market close
        require(_percPrizeVoters + _percMarkClose < 10000, ' close market perc error ;() ');
        require(_percMaker < 10000 && _percPromo < 10000 && _percArbExe < 10000 && _percMarkClose < 10000 && _percPrizeVoters < 10000 && _percVoterClaim < 10000 && _perWinnerClaim < 10000 && _percPromoClaim < 10000, ' invalid perc(s) :0 ');
        PERC_PROMO_CLAIM_FEE = _percPromoClaim;
        PERC_MARKET_MAKER_FEE = _percMaker; 
        PERC_PROMO_BUY_FEE = _percPromo; // note: yes other % fee (promo.percReward)
        PERC_ARB_EXE_FEE = _percArbExe;
        PERC_MARKET_CLOSE_FEE = _percMarkClose; // note: yes other % fee (PERC_PRIZEPOOL_VOTERS)
        PERC_PRIZEPOOL_VOTERS = _percPrizeVoters;
        PERC_VOTER_CLAIM_FEE = _percVoterClaim;
        PERC_WINNER_CLAIM_FEE = _perWinnerClaim;        
    }    
    function KEEPER_setNewTicketEnv(address _router, address _usdStable) external onlyKeeper {
        // max array size = 255 (uint8 loop)
        require(LIB._isAddressInArray(_router, USWAP_V2_ROUTERS) && LIB._isAddressInArray(_usdStable, WHITELIST_USD_STABLES), ' !whitelist router|factory|stable :() ');
        NEW_TICK_UNISWAP_V2_ROUTER = _router;
        NEW_TICK_USD_STABLE = _usdStable;
    }
    function KEEPER_setDepositUsdStable(address _usdStable, address _depositRtr) external onlyKeeper {
        require(LIB._isAddressInArray(_usdStable, WHITELIST_USD_STABLES) && LIB._isAddressInArray(_depositRtr, USWAP_V2_ROUTERS), ' bad stable | router :( ');
        // address old_0 = DEPOSIT_USD_STABLE;
        // address old_1 = DEPOSIT_ROUTER;
        DEPOSIT_USD_STABLE = _usdStable;
        DEPOSIT_ROUTER = _depositRtr;
        // event DepositStableUpdated(address _old_0, address _old_1, address _new_0, address _new_1);
        // emit DepositStableUpdated(old_0, old_1, DEPOSIT_USD_STABLE, DEPOSIT_ROUTER);
    }
    function KEEPER_setMarketConfig(uint16 _maxResultOpts, uint64 _maxEoaMarkets, uint64 _minUsdArbTargPrice, uint256 _secDefaultVoteTime, bool _useDefaultVotetime) external {
        MAX_RESULTS = _maxResultOpts; // max # of result options a market may have
        MAX_EOA_MARKETS = _maxEoaMarkets;
        // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
        MIN_USD_CALL_TICK_TARGET_PRICE = _minUsdArbTargPrice;

        SEC_DEFAULT_VOTE_TIME = _secDefaultVoteTime; // 24 * 60 * 60 == 86,400 sec == 24 hours
        USE_SEC_DEFAULT_VOTE_TIME = _useDefaultVotetime; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    }
    function KEEPER_editWhitelistStables(address _usdStable, bool _add) external onlyKeeper {
        _editWhitelistStables(_usdStable, _add); // note: require check in local
        // emit WhitelistStableUpdated(_usdStable, _decimals, _add);
    }
    function KEEPER_editDexRouters(address _router, bool _add) external onlyKeeper {
        _editDexRouters(_router, _add);
        // emit DexRouterUpdated(_router, _add);
    }
    function KEEPER_setTicketNameSymbSeeds(string calldata _nameSeed, string calldata _symbSeed) external onlyKeeper {
        TOK_TICK_NAME_SEED = _nameSeed;
        TOK_TICK_SYMB_SEED = _symbSeed;
    }
    function KEEPER_setCallTokNameSymb(string calldata _tok_name, string calldata _tok_symb) external onlyKeeper() {
        require(bytes(_tok_name).length > 0 && bytes(_tok_symb).length > 0, ' invalid input  :<> ');
        CALL.setTokenNameSymbol(_tok_name, _tok_symb); // emits 'TokenNameSymbolUpdated'
    }
    function KEEPER_setLpSettings(uint64 _usdPerCallEarned, uint32 _tokCntPerUsd, uint64 _usdMinInitLiq) external onlyKeeper {
        RATIO_LP_USD_PER_CALL_TOK = _usdPerCallEarned; // LP usd amount needed per $CALL earned by market maker
        RATIO_LP_TOK_PER_USD = _tokCntPerUsd; // # of ticket tokens per usd, minted for LP deploy
        MIN_USD_MARK_LIQ = _usdMinInitLiq; // min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    }
    function KEEPER_setMarketLoserMints(uint8 _mintAmnt, uint8 _percSupplyReq) external onlyKeeper {
        require(_percSupplyReq <= 10000, ' total percs > 100.00% ;) ');
        RATIO_CALL_MINT_PER_LOSER = _mintAmnt;
        PERC_OF_LOSER_SUPPLY_EARN_CALL = _percSupplyReq;
    }
    function KEEPER_setMarketActionMints(uint32 _callPerArb, uint32 _callPerMarkCloseCalls, uint32 _callMintPerVote, uint32 _callTokPerVote, uint32 _callPerMarkClose, uint64 _promoUsdPerCall, uint64 _minUsdPromoTarget) external onlyKeeper {
        RATIO_CALL_MINT_PER_ARB_EXE = _callPerArb; // amount of all $CALL minted per arb executer reward
        RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS = _callPerMarkCloseCalls; // amount of all $CALL minted per market call close action reward
        RATIO_CALL_MINT_PER_VOTE = _callMintPerVote; // amount of all $CALL minted per vote reward
        RATIO_CALL_TOK_PER_VOTE = _callTokPerVote; // amount of call tokens (non-earned) required per vote count
        RATIO_CALL_MINT_PER_MARK_CLOSE = _callPerMarkClose; // amount of all $CALL minted per market close action reward
        RATIO_PROMO_USD_PER_CALL_MINT = _promoUsdPerCall; // usd amnt buy needed per $CALL earned in promo (note: global for promos to avoid exploitations)
        MIN_USD_PROMO_TARGET = _minUsdPromoTarget; // min target for creating promo codes ($ target = $ bets this promo brought in)
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - VAULT
    /* -------------------------------------------------------- */
    function VAULT_deployTicket(address _sender, uint256 _markNum, uint16 _tickIdx, uint256 _initSupplyNoDecs) external onlyVault returns(address) {
        (string memory tok_name, string memory tok_symb) = LIB._genTokenNameSymbol(_sender, _markNum, _tickIdx, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
        return address(new CallitTicket(_initSupplyNoDecs, tok_name, tok_symb)); // _config = address(this)
    }
    function VAULT_getStableTokenLowMarketValue() external view onlyVault returns(address) {
        return LIB._getStableTokenLowMarketValue(WHITELIST_USD_STABLES, USWAP_V2_ROUTERS);
    }
    
    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    function getDexAddies() external view returns (address[] memory, address[] memory) {
        return (WHITELIST_USD_STABLES, USWAP_V2_ROUTERS);
    }
    function get_WHITELIST_USD_STABLES() external view returns(address[] memory) {
        return WHITELIST_USD_STABLES;
    }
    function get_USWAP_V2_ROUTERS() external view returns(address[] memory) {
        return USWAP_V2_ROUTERS;
    }
    function adminStatus(address _admin) external view returns(bool) {
        require(_admin != address(0), ' !_admin :/ ');
        return ADMINS[_admin];
    }
    function getPromoForHash(address _promoHash) external view returns(ICallitLib.PROMO memory) {
        require(_promoHash != address(0), ' no hash :/ ');
        return HASH_PROMO[_promoHash];
    }
    function getPromoHashesForAcct(address _acct) external view returns(address[] memory) {
        require(_acct != address(0) && PROMOTOR_HASHES[_acct].length > 0, ' no _acct :/ ');
        return PROMOTOR_HASHES[_acct];
    }
    function setPromoForHash(address _promoHash, ICallitLib.PROMO memory _promo) external {
        require(_promo.promotor != address(0) && _promoHash != address(0), ' no promo|hash :/ ');
        HASH_PROMO[_promoHash] = _promo;
        PROMOTOR_HASHES[_promo.promotor].push(_promoHash);
    }
    function setUsdOwedForPromoHash(uint64 _usdOwed, address _promoCodeHash) external onlyVault {
        PROMO_USD_OWED[_promoCodeHash] = _usdOwed;
    }
    function setAcctHandle(address _sender, string calldata _handle) external onlyFactory {
        require(_sender != address(0) && bytes(_handle).length >= 2 && bytes(_handle)[0] != 0x20, ' !_handle :[] ');
        if (LIB._validNonWhiteSpaceString(_handle))
            ACCT_HANDLES[_sender] = _handle;
        else
            revert(' !blank space handles :-[=] ');     
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - SUPPORTING (CALLIT market management)
    /* -------------------------------------------------------- */
    // invoked if function invoked doesn't exist OR no receive() implemented & ETH received w/o data
    fallback() external payable {
        // fwd any PLS recieved to VAULT (convert to USD stable & process deposit)
        ICallitVault(ADDR_VAULT).deposit{value: msg.value}(msg.sender);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE SUPPORTING
    /* -------------------------------------------------------- */
    function _editWhitelistStables(address _usdStable, bool _add) private { // allows duplicates
        if (_add) {
            WHITELIST_USD_STABLES = LIB._addAddressToArraySafe(_usdStable, WHITELIST_USD_STABLES, true); // true = no dups
            USD_STABLES_HISTORY = LIB._addAddressToArraySafe(_usdStable, USD_STABLES_HISTORY, true); // true = no dups
            // USD_STABLE_DECIMALS[_usdStable] = _decimals;
        } else {
            WHITELIST_USD_STABLES = LIB._remAddressFromArray(_usdStable, WHITELIST_USD_STABLES);
        }
    }
    function _editDexRouters(address _router, bool _add) private {
        require(_router != address(0x0), "0 address");
        if (_add) {
            USWAP_V2_ROUTERS = LIB._addAddressToArraySafe(_router, USWAP_V2_ROUTERS, true); // true = no dups
        } else {
            USWAP_V2_ROUTERS = LIB._remAddressFromArray(_router, USWAP_V2_ROUTERS); // removes only one & order NOT maintained
        }
    }
}