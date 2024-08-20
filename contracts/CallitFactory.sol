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
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // deploy
// import "@openzeppelin/contracts/access/Ownable.sol"; // deploy
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; // deploy
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// local _ $ npm install @openzeppelin/contracts
// import "./node_modules/@openzeppelin/contracts/utils/Strings.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./CallitTicket.sol";
import "./ICallitLib.sol";
import "./ICallitVault.sol";


// interface ICallitLib {
//     function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
//     function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
//     function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) external view returns (uint8, uint256);
//     function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) external returns (uint256);

//     function _perc_total_supply_owned(address _token, address _account) external view returns (uint64);
//     function _isAddressInArray(address _addr, address[] memory _addrArr) external pure returns(bool);
//     // function _genTokenNameSymbol(address _maker, uint256 _markNum, uint16 _resultNum, string calldata _nameSeed, string calldata _symbSeed) external pure returns(string memory, string memory);
//     function _validNonWhiteSpaceString(string calldata _s) external pure returns(bool);
//     function _generateAddressHash(address host, string memory uid) external pure returns (address);
//     function _perc_of_uint64(uint32 _perc, uint64 _num) external pure returns (uint64);
//     function _uint64_from_uint256(uint256 value) external pure returns (uint64);
//     function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) external pure returns (uint256);
//     function _addAddressToArraySafe(address _addr, address[] memory _arr, bool _safe) external pure returns (address[] memory);
//     function _remAddressFromArray(address _addr, address[] memory _arr) external pure returns (address[] memory);
// }

interface ICallitTicket {
    function mintForPriceParity(address _receiver, uint256 _amount) external;
    function burnForWinLoseClaim(address _account, uint256 _amount) external;
    function balanceOf(address account) external returns(uint256);
}

contract CallitFactory is ERC20, Ownable {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    /* _ ADMIN SUPPORT (legacy) _ */
    address public KEEPER;
    uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    string public tVERSION = '0.1';
    string private TOK_SYMB = string(abi.encodePacked("tCALL", tVERSION));
    string private TOK_NAME = string(abi.encodePacked("tCALL-IT_", tVERSION));
    // string private TOK_SYMB = "CALL";
    // string private TOK_NAME = "CALL-IT";

    // /* _ ACCOUNT SUPPORT (legacy) _ */
    // // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    // address[] private ACCOUNTS;
    // mapping(address => uint64) public ACCT_USD_BALANCES; 
    // address[] public USWAP_V2_ROUTERS;
    // address[] private WHITELIST_USD_STABLES;
    // address[] private USD_STABLES_HISTORY;
    // mapping(address => uint8) public USD_STABLE_DECIMALS;

    /* GLOBALS (CALLIT) */
    address public CALLIT_LIB_ADDR;
    address public CALLIT_VAULT_ADDR;
    ICallitLib   private CALLIT_LIB;
    ICallitVault private CALLIT_VAULT;

    uint16 PERC_MARKET_MAKER_FEE; // TODO: KEEPER setter
    uint16 PERC_PROMO_BUY_FEE; // TODO: KEEPER setter
    uint16 PERC_ARB_EXE_FEE; // TODO: KEEPER setter
    uint16 PERC_MARKET_CLOSE_FEE; // TODO: KEEPER setter
    uint16 PERC_VOTE_CLAIM_FEE; // TODO: KEEPER setter
    uint16 PERC_CLAIM_WIN_FEE; // TODO: KEEPER setter

    // call ticket token settings
    address public NEW_TICK_UNISWAP_V2_ROUTER;
    address public NEW_TICK_UNISWAP_V2_FACTORY;
    address public NEW_TICK_USD_STABLE;
    // uint64 public TOK_TICK_INIT_SUPPLY = 1000000; // init supply used for new call ticket tokens (uint64 = ~18,000Q max)
    string public TOK_TICK_NAME_SEED = "TCK#";
    string public TOK_TICK_SYMB_SEED = "CALL-TICKET";

    // account settings
    uint8  public MIN_HANDLE_SIZE = 1; // min # of chars for account handles
    uint8  public MAX_HANDLE_SIZE = 25; // max # of chars for account handles

    // promo settings
    uint64 public MIN_USD_PROMO_TARGET = 100; // min $ target for creating promo codes

    // arb algorithm settings
    uint64 public MIN_USD_CALL_TICK_TARGET_PRICE = 10000; // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)

    // market settings
    bool    public USE_SEC_DEFAULT_VOTE_TIME = true; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    uint256 public SEC_DEFAULT_VOTE_TIME = 24 * 60 * 60; // 24 * 60 * 60 == 86,400 sec == 24 hours
    uint64  public MIN_USD_MARK_LIQ = 10000000; // (10000000 = $10.000000) min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    uint16  public MAX_RESULTS = 100; // max # of result options a market may have (uint16 max = ~65K -> 65,535)
    uint64  public MAX_EOA_MARKETS = type(uint8).max; // uint8 = 255 (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)
        // NOTE: additional launch security: caps EOA $CALL earned to 255
        //  but also limits the EOA following (KEEPER setter available; should raise after launch)

    // lp settings
    uint16 public RATIO_LP_TOK_PER_USD = 10000; // # of ticket tokens per usd, minted for LP deploy

    // $CALL reward & usd earn settings
    uint16 private PERC_PRIZEPOOL_VOTERS = 200; // (2%) of total prize pool allocated to voter payout _ 10000 = %100.00
    uint16 public PERC_OF_LOSER_SUPPLY_EARN_CALL = 2500; // (25%) _ 10000 = %100.00; 5000 = %50.00; 0001 = %00.01
    uint32 public RATIO_CALL_MINT_PER_LOSER = 1; // amount of all $CALL minted per loser reward (depends on PERC_OF_LOSER_SUPPLY_EARN_CALL)
    uint32 public RATIO_CALL_MINT_PER_ARB_EXE = 1; // amount of all $CALL minted per arb executer reward // TODO: need KEEPER setter
    uint32 public RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS = 1; // amount of all $CALL minted per market call close action reward // TODO: need KEEPER setter
    uint32 public RATIO_CALL_MINT_PER_VOTE = 1; // amount of all $CALL minted per vote reward // TODO: need KEEPER setter
    uint32 public RATIO_CALL_MINT_PER_MARK_CLOSE = 1; // amount of all $CALL minted per market close action reward // TODO: need KEEPER setter
    
    uint64 public RATIO_PROMO_USD_PER_CALL_TOK = 100000000; // (1000000 = %1.000000; 6 decimals) usd amnt buy needed per $CALL earned in promo (note: global for promos to avoid exploitations)
    uint64 public RATIO_LP_USD_PER_CALL_TOK = 100000000; // (1000000 = %1.000000; 6 decimals) init LP usd amount needed per $CALL earned by market maker
        // LEFT OFF HERE  ... need more requirement for market maker earning $CALL
        //  ex: maker could create $100 LP, not promote, delcare himself winner, get his $100 back and earn free $CALL)
    
    /* MAPPINGS (CALLIT) */
    // used externals only
    mapping(address => bool) public ADMINS; // enable/disable admins (for promo support, etc)
    mapping(address => string) public ACCT_HANDLES; // market makers (etc.) can set their own handles
    mapping(address => address) public TICKET_MAKERS; // store ticket to their MARKET.maker mapping
    mapping(address => ICallitLib.PROMO) public PROMO_CODE_HASHES; // store promo code hashes to their PROMO mapping
    mapping(address => ICallitLib.MARKET_REVIEW[]) public ACCT_MARKET_REVIEWS; // store maker to all their MARKET_REVIEWs created by callers
    mapping(address => uint256) public ACCT_CALL_VOTE_LOCK_TIME; // track EOA to their call token lock timestamp; remember to reset to 0 (ie. 'not locked') ***

    // used externals & private
    mapping(address => ICallitLib.MARKET[]) public ACCT_MARKETS; // store maker to all their MARKETs created mapping ***
    mapping(address => ICallitLib.MARKET_VOTE[]) private ACCT_MARKET_VOTES; // store voter to their non-paid MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & private until market close; live = false) ***
    mapping(address => uint64) public EARNED_CALL_VOTES; // track EOAs to result votes allowed for open markets (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)
    
    // used private only
    mapping(address => ICallitLib.MARKET_VOTE[]) public  ACCT_MARKET_VOTES_PAID; // store voter to their 'paid' MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & avail when market close; live = false) *

    // temp-arrays for 'makeNewMarket' support
    address[] private resultOptionTokens;
    address[] private resultTokenLPs;
    address[] private resultTokenRouters;
    address[] private resultTokenFactories;
    address[] private resultTokenUsdStables;
    uint64 [] private resultTokenVotes;
    
    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // legacy
    event KeeperTransfer(address _prev, address _new);
    event TokenNameSymbolUpdated(string TOK_NAME, string TOK_SYMB);
    event DepositReceived(address _account, uint256 _plsDeposit, uint64 _stableConvert);
    // event WhitelistStableUpdated(address _usdStable, uint8 _decimals, bool _add);
    // event DexRouterUpdated(address _router, bool _add);

    // callit
    event MarketCreated(address _maker, uint256 _markNum, string _name, uint64 _usdAmntLP, uint256 _dtCallDeadline, uint256 _dtResultVoteStart, uint256 _dtResultVoteEnd, string[] _resultLabels, address[] _resultOptionTokens, uint256 _blockTime, bool _live);
    event PromoCreated(address _promoHash, address _promotor, string _promoCode, uint64 _usdTarget, uint64 usdUsed, uint8 _percReward, address _creator, uint256 _blockNumber);
    // event PromoRewardPaid(address _promoCodeHash, uint64 _usdRewardPaid, address _promotor, address _buyer, address _ticket);
    event PromoBuyPerformed(address _buyer, address _promoCodeHash, address _usdStable, address _ticket, uint64 _grossUsdAmnt, uint64 _netUsdAmnt, uint256  _tickAmntOut);
    // event AlertStableSwap(uint256 _tickStableReq, uint256 _contrStableBal, address _swapFromStab, address _swapToTickStab, uint256 _tickStabAmntNeeded, uint256 _swapAmountOut);
    // event AlertZeroReward(address _sender, uint64 _usdReward, address _receiver);
    event MarketReviewed(address _caller, bool _resultAgree, address _marketMaker, uint256 _marketNum, uint64 _agreeCnt, uint64 _disagreeCnt);
    event ArbPriceCorrectionExecuted(address _executer, address _ticket, uint64 _tickTargetPrice, uint64 _tokenMintCnt, uint64 _usdGrossReceived, uint64 _usdTotalPaid, uint64 _usdNetProfit, uint64 _callEarnedAmnt);
    event MarketCallsClosed(address _executer, address _ticket, address _marketMaker, uint256 _marketNum, uint64 _usdAmntPrizePool, uint64 _callEarnedAmnt);
    event MarketClosed(address _sender, address _ticket, address _marketMaker, uint256 _marketNum, uint64 _winningResultIdx, uint64 _usdPrizePoolPaid, uint64 _usdVoterRewardPoolPaid, uint64 _usdRewardPervote, uint64 _callEarnedAmnt);
    event TicketClaimed(address _sender, address _ticket, bool _is_winner, bool _resultAgree);
    event VoterRewardsClaimed(address _claimer, uint64 _usdRewardOwed, uint64 _usdRewardOwed_net);
    event CallTokensEarned(address _sedner, address _receiver, uint64 _callAmntEarned, uint64 _callPrevBal, uint64 _callCurrBal);

    // /* -------------------------------------------------------- */
    // /* STRUCTS (CALLIT)
    // /* -------------------------------------------------------- */
    // struct PROMO {
    //     address promotor; // influencer wallet this promo is for
    //     string promoCode;
    //     uint64 usdTarget; // usd amount this promo is good for
    //     uint64 usdUsed; // usd amount this promo has used so far
    //     uint8 percReward; // % of caller buys rewarded
    //     address adminCreator; // admin who created this promo
    //     uint256 blockNumber; // block number this promo was created
    // }
    // struct MARKET {
    //     address maker; // EOA market maker
    //     uint256 marketNum; // used incrementally for MARKET[] in ACCT_MARKETS
    //     string name; // display name for this market (maybe auto-generate w/ )
    //     // MARKET_INFO marketInfo;
    //     string category;
    //     string rules;
    //     string imgUrl;
    //     MARKET_USD_AMNTS marketUsdAmnts;
    //     MARKET_DATETIMES marketDatetimes;
    //     MARKET_RESULTS marketResults;
    //     uint16 winningVoteResultIdx; // calc winning idx from resultTokenVotes 
    //     uint256 blockTimestamp; // sec timestamp this market was created
    //     uint256 blockNumber; // block number this market was created
    //     bool live;
    // }
    // // struct MARKET_INFO {
    // //     string category;
    // //     string rules;
    // //     string imgUrl;
    // // }
    // struct MARKET_USD_AMNTS {
    //     uint64 usdAmntLP; // total usd provided by maker (will be split amount 'resultOptionTokens')
    //     uint64 usdAmntPrizePool; // default 0, until market voting ends
    //     uint64 usdAmntPrizePool_net; // default 0, until market voting ends
    //     uint64 usdVoterRewardPool; // default 0, until close market calc
    //     uint64 usdRewardPerVote; // default 0, until close mark calc
    // }
    // struct MARKET_DATETIMES {
    //     uint256 dtCallDeadline; // unix timestamp 1970, no more bets, pull liquidity from all DEX LPs generated
    //     uint256 dtResultVoteStart; // unix timestamp 1970, earned $CALL token EOAs may start voting
    //     uint256 dtResultVoteEnd; // unix timestamp 1970, earned $CALL token EOAs voting ends
    // }
    // struct MARKET_RESULTS {
    //     string[] resultLabels; // required: length == _resultDescrs
    //     string[] resultDescrs; // required: length == _resultLabels
    //     address[] resultOptionTokens; // required: length == _resultLabels == _resultDescrs
    //     address[] resultTokenLPs; // // required: length == _resultLabels == _resultDescrs == resultOptionTokens
    //     address[] resultTokenRouters;
    //     address[] resultTokenFactories;
    //     address[] resultTokenUsdStables;
    //     uint64[] resultTokenVotes;
    // }
    // struct MARKET_VOTE {
    //     address voter;
    //     address voteResultToken;
    //     uint16 voteResultIdx;
    //     uint64 voteResultCnt;
    //     address marketMaker;
    //     uint256 marketNum;
    //     bool paid;
    // }
    // struct MARKET_REVIEW { 
    //     address caller;
    //     bool resultAgree;
    //     address marketMaker;
    //     uint256 marketNum;
    //     uint64 agreeCnt;
    //     uint64 disagreeCnt;
    // }

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR (legacy)
    /* -------------------------------------------------------- */
    // NOTE: sets msg.sender to '_owner' ('Ownable' maintained)
    constructor(uint256 _initSupply, address _callit_lib, address _callit_vault) ERC20(TOK_NAME, TOK_SYMB) Ownable(msg.sender) {     
    // constructor(uint256 _initSupply) ERC20(TOK_NAME, TOK_SYMB) Ownable(msg.sender) {     
        CALLIT_LIB_ADDR = _callit_lib;
        CALLIT_VAULT_ADDR = _callit_vault;
        CALLIT_LIB = ICallitLib(_callit_lib);
        CALLIT_VAULT = ICallitVault(_callit_vault);

        // set default globals
        KEEPER = msg.sender;
        KEEPER_CHECK = 0;
        _mint(msg.sender, _initSupply * 10**uint8(decimals())); // 'emit Transfer'

        // add a whitelist stable
        CALLIT_VAULT._editWhitelistStables(address(0xefD766cCb38EaF1dfd701853BFCe31359239F305), 18, true); // weDAI, decs, true = add

        // add default routers: pulsex (x2)
        CALLIT_VAULT._editDexRouters(address(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02), true); // pulseX v1, true = add
        // _editDexRouters(address(0x165C3410fC91EF562C50559f7d2289fEbed552d9), true); // pulseX v2, true = add
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == KEEPER, "!keeper :p");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == KEEPER || ADMINS[msg.sender] == true, " !admin :p");
        _;
    }
    
    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER setters
    /* -------------------------------------------------------- */
    // legacy
    function KEEPER_maintenance(address _tokAddr, uint256 _tokAmnt) external onlyKeeper() {
        //  NOTE: _tokAmnt must be in uint precision to _tokAddr.decimals()
        require(IERC20(_tokAddr).balanceOf(address(this)) >= _tokAmnt, ' not enough amount for token :O ');
        IERC20(_tokAddr).transfer(KEEPER, _tokAmnt);
        // emit KeeperMaintenance(_tokAddr, _tokAmnt);
    }
    function KEEPER_withdraw(uint256 _natAmnt) external onlyKeeper {
        require(address(this).balance >= _natAmnt, " Insufficient native PLS balance :[ ");
        payable(KEEPER).transfer(_natAmnt); // cast to a 'payable' address to receive ETH
        // emit KeeperWithdrawel(_natAmnt);
    }
    function KEEPER_setKeeper(address _newKeeper) external onlyKeeper {
        require(_newKeeper != address(0), 'err: 0 address');
        address prev = address(KEEPER);
        KEEPER = _newKeeper;
        emit KeeperTransfer(prev, KEEPER);
    }
    function KEEPER_setKeeperCheck(uint256 _keeperCheck) external onlyKeeper {
        KEEPER_CHECK = _keeperCheck;
    }
    function KEEPER_setTokNameSymb(string memory _tok_name, string memory _tok_symb) external onlyKeeper() {
        require(bytes(_tok_name).length > 0 && bytes(_tok_symb).length > 0, ' invalid input  :<> ');
        TOK_NAME = _tok_name;
        TOK_SYMB = _tok_symb;
        emit TokenNameSymbolUpdated(TOK_NAME, TOK_SYMB);
    }
    function KEEPER_editAdmin(address _admin, bool _enable) external onlyKeeper {
        require(_admin != address(0), ' !_admin :{+} ');
        ADMINS[_admin] = _enable;
    }
    function KEEPER_setMaxMarketResultOptions(uint16 _optionCnt) external onlyKeeper {
        MAX_RESULTS = _optionCnt; // max # of result options a market may have
    }
    function KEEPER_setMinMaxAcctHandleSize(uint8 _min, uint8 _max) external onlyKeeper {
        MIN_HANDLE_SIZE = _min; // min # of chars for account handles
        MAX_HANDLE_SIZE = _max; // max # of chars for account handles
    }
    function KEEPER_setPromoSettings(uint64 _usdTargetMin, uint64 _usdBuyRequired) external onlyKeeper {
        MIN_USD_PROMO_TARGET = _usdTargetMin;
        RATIO_PROMO_USD_PER_CALL_TOK = _usdBuyRequired;
    }
    // function KEEPER_setMinUsdPromoTarget(uint64 _usdTarget) external onlyKeeper {
    //     MIN_USD_PROMO_TARGET = _usdTarget;
    // }
    // function KEEPER_setRatioPromoBuyUsdPerCall(uint64 _usdBuyRequired) external onlyKeeper {
    //     RATIO_PROMO_USD_PER_CALL_TOK = _usdBuyRequired;
    // }
    function KEEPER_setLpSettings(uint64 _usdPerCallEarned, uint16 _tokCntPerUsd, uint64 _usdMinInitLiq) external onlyKeeper {
        RATIO_LP_USD_PER_CALL_TOK = _usdPerCallEarned; // LP usd amount needed per $CALL earned by market maker
        RATIO_LP_TOK_PER_USD = _tokCntPerUsd; // # of ticket tokens per usd, minted for LP deploy
        MIN_USD_MARK_LIQ = _usdMinInitLiq; // min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    }
    function KEEPER_setMaxEoaMarkets(uint64 _max) external onlyKeeper { // uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
        MAX_EOA_MARKETS = _max;
    }
    function KEEPER_setNewTicketEnvironment(address _router, address _factory, address _usdStable, string calldata _nameSeed, string calldata _symbSeed) external onlyKeeper {
        // max array size = 255 (uint8 loop)
        require(CALLIT_LIB._isAddressInArray(_router, CALLIT_VAULT.USWAP_V2_ROUTERS()) && CALLIT_LIB._isAddressInArray(_usdStable, CALLIT_VAULT.WHITELIST_USD_STABLES()), ' !whitelist router|stable :() ');
        NEW_TICK_UNISWAP_V2_ROUTER = _router;
        NEW_TICK_UNISWAP_V2_FACTORY = _factory;
        NEW_TICK_USD_STABLE = _usdStable;
        TOK_TICK_NAME_SEED = _nameSeed;
        TOK_TICK_SYMB_SEED = _symbSeed;
    }
    function KEEPER_setEnableDefaultVoteTime(uint256 _sec, bool _enable) external onlyKeeper {
        SEC_DEFAULT_VOTE_TIME = _sec; // 24 * 60 * 60 == 86,400 sec == 24 hours
        USE_SEC_DEFAULT_VOTE_TIME = _enable; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    }
    function KEEPER_setPercPrizePoolVoters(uint8 _perc) external onlyKeeper {
        // require(_servFee + _bstBurn + _auxBurn <= 10000, ' total percs > 100.00% ;) ');
        require(_perc <= 10000, ' invalid _perc :() ');
        PERC_PRIZEPOOL_VOTERS = _perc;
    }
    function KEEPER_setReqCallMintPerLoser(uint8 _mintAmnt, uint8 _percSupplyReq) external onlyKeeper {
        require(_percSupplyReq <= 10000, ' total percs > 100.00% ;) ');
        RATIO_CALL_MINT_PER_LOSER = _mintAmnt;
        PERC_OF_LOSER_SUPPLY_EARN_CALL = _percSupplyReq;
    }
    function KEEPER_setMinCallTickTargPrice(uint64 _usdMin) external onlyKeeper {
        // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
        MIN_USD_CALL_TICK_TARGET_PRICE = _usdMin;
    }
    // CALLIT admin
    function ADMIN_initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward) external onlyAdmin {
        require(_promotor != address(0) && CALLIT_LIB._validNonWhiteSpaceString(_promoCode) && _usdTarget >= MIN_USD_PROMO_TARGET, ' !param(s) :={ ');
        address promoCodeHash = CALLIT_LIB._generateAddressHash(_promotor, _promoCode);
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[promoCodeHash];
        require(promo.promotor == address(0), ' promo already exists :-O ');
        // PROMO_CODE_HASHES[promoCodeHash].push(PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number));
        PROMO_CODE_HASHES[promoCodeHash] = ICallitLib.PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
        emit PromoCreated(promoCodeHash, _promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
    }

    // /* -------------------------------------------------------- */
    // /* PUBLIC - ACCESSORS
    // /* -------------------------------------------------------- */
    // CALLIT
    function getAccountMarkets(address _account) external view returns (ICallitLib.MARKET[] memory) {
        require(_account != address(0), ' 0 address? ;[+] ');
        return ACCT_MARKETS[_account];
    }
    function checkPromoBalance(address _promoCodeHash) external view returns(uint64) {
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        return promo.usdTarget - promo.usdUsed;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - UI (CALLIT)
    /* -------------------------------------------------------- */
    // handle contract USD value deposits (convert PLS to USD stable)
    receive() external payable {
        // extract PLS value sent
        uint256 amntIn = msg.value; 

        // send PLS to vault
        payable(address(CALLIT_VAULT)).transfer(amntIn);
            // NOTE: VAULT's receive() function should handle swap for usd stable

        emit DepositReceived(msg.sender, amntIn, 0);

        // NOTE: at this point, the vault has the deposited stable and the vault has stored accont balances
    }
    function setMyAcctHandle(string calldata _handle) external {
        require(bytes(_handle).length >= MIN_HANDLE_SIZE && bytes(_handle).length <= MAX_HANDLE_SIZE, ' !_handle.length :[] ');
        require(bytes(_handle)[0] != 0x20, ' !_handle space start :+[ '); // 0x20 -> ASCII for ' ' (single space)
        if (CALLIT_LIB._validNonWhiteSpaceString(_handle))
            ACCT_HANDLES[msg.sender] = _handle;
        else
            revert(' !blank space handles :-[=] ');        
    }
    function setCallTokenVoteLock(bool _lock) external {
        ACCT_CALL_VOTE_LOCK_TIME[msg.sender] = _lock ? block.timestamp : 0;
    }
    function setMarketInfo(address _anyTicket, string calldata _category, string calldata _descr, string calldata _imgUrl) external {
        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark,) = _getMarketForTicket(TICKET_MAKERS[_anyTicket], _anyTicket); // reverts if market not found | address(0)
        require(mark.maker == msg.sender, ' only market maker :( ');
        mark.category = _category;
        mark.rules = _descr;
        mark.imgUrl = _imgUrl;
    }
    function makeNewMarket(string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                            // string calldata _category, 
                            // string calldata _rules, 
                            // string calldata _imgUrl, 
                            uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, 
                            string[] calldata _resultDescrs
                            ) external { 
        require(_usdAmntLP >= MIN_USD_MARK_LIQ, ' need more liquidity! :{=} ');
        require(CALLIT_VAULT.ACCT_USD_BALANCES(msg.sender) >= _usdAmntLP, ' low balance ;{ ');
        require(2 <= _resultLabels.length && _resultLabels.length <= MAX_RESULTS && _resultLabels.length == _resultDescrs.length, ' bad results count :( ');
        require(block.timestamp < _dtCallDeadline && _dtCallDeadline < _dtResultVoteStart && _dtResultVoteStart < _dtResultVoteEnd, ' invalid dt settings :[] ');

        // initilize/validate market number for struct MARKET tracking
        uint256 mark_num = ACCT_MARKETS[msg.sender].length;
        require(mark_num <= MAX_EOA_MARKETS, ' > MAX_EOA_MARKETS :O ');
        // require(ACCT_MARKETS[msg.sender].length <= MAX_EOA_MARKETS, ' > MAX_EOA_MARKETS :O ');

        // deduct 'market maker fees' from _usdAmntLP
        uint64 net_usdAmntLP = CALLIT_LIB._deductFeePerc(_usdAmntLP, PERC_MARKET_MAKER_FEE, _usdAmntLP);

        // check for admin defualt vote time, update _dtResultVoteEnd accordingly
        if (USE_SEC_DEFAULT_VOTE_TIME) _dtResultVoteEnd = _dtResultVoteStart + SEC_DEFAULT_VOTE_TIME;

        // Loop through _resultLabels and deploy ERC20s for each (and generate LP)
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // Get/calc amounts for initial LP (usd and token amounts)
            (uint64 usdAmount, uint256 tokenAmount) = CALLIT_LIB._getAmountsForInitLP(net_usdAmntLP, _resultLabels.length, RATIO_LP_TOK_PER_USD);            

            // Deploy a new ERC20 token for each result label (init supply = tokenAmount; transfered to VAULT to create LP)
            (string memory tok_name, string memory tok_symb) = CALLIT_LIB._genTokenNameSymbol(msg.sender, mark_num, i, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
            address new_tick_tok = address (new CallitTicket(tokenAmount, address(CALLIT_VAULT), tok_name, tok_symb));
            
            // Create DEX LP for new ticket token (from VAULT, using VAULT's stables, and VAULT's minted new tick init supply)
            address pairAddr = CALLIT_VAULT._createDexLP(NEW_TICK_UNISWAP_V2_ROUTER, NEW_TICK_UNISWAP_V2_FACTORY, new_tick_tok, NEW_TICK_USD_STABLE, tokenAmount, usdAmount);

            // verify ERC20 & LP was created
            require(new_tick_tok != address(0) && pairAddr != address(0), ' err: gen tick tok | lp :( ');

            // push this ticket option's settings to storage temp results array
            //  temp array will be added to MARKET struct (then deleted on function return)
            resultOptionTokens.push(new_tick_tok);
            resultTokenLPs.push(pairAddr);

            resultTokenRouters.push(NEW_TICK_UNISWAP_V2_ROUTER);
            resultTokenFactories.push(NEW_TICK_UNISWAP_V2_FACTORY);
            resultTokenUsdStables.push(NEW_TICK_USD_STABLE);
            resultTokenVotes.push(0);

            // set ticket to maker mapping (additional access support)
            TICKET_MAKERS[new_tick_tok] = msg.sender;
            unchecked {i++;}
        }

        // deduct full OG usd input from account balance
        // CALLIT_VAULT.ACCT_USD_BALANCES[msg.sender] -= _usdAmntLP;
        CALLIT_VAULT.edit_ACCT_USD_BALANCES(msg.sender, _usdAmntLP, false); // false = sub

        // save this market and emit log
        ACCT_MARKETS[msg.sender].push(ICallitLib.MARKET({maker:msg.sender, 
                                                marketNum:mark_num, 
                                                name:_name,

                                                // marketInfo:MARKET_INFO("", "", ""),
                                                category:"",
                                                rules:"", 
                                                imgUrl:"", 

                                                marketUsdAmnts:ICallitLib.MARKET_USD_AMNTS(_usdAmntLP, 0, 0, 0, 0), 
                                                marketDatetimes:ICallitLib.MARKET_DATETIMES(_dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd), 
                                                marketResults:ICallitLib.MARKET_RESULTS(_resultLabels, _resultDescrs, resultOptionTokens, resultTokenLPs, resultTokenRouters, resultTokenFactories, resultTokenUsdStables, resultTokenVotes), 
                                                winningVoteResultIdx:0, 
                                                blockTimestamp:block.timestamp, 
                                                blockNumber:block.number, 
                                                live:true})); // true = live
        emit MarketCreated(msg.sender, mark_num, _name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, resultOptionTokens, block.timestamp, true); // true = live
        
        // Step 4: Clear tempArray (optional)
        // delete tempArray; // This will NOT effect whats stored in ACCT_MARKETS
        delete resultOptionTokens;
        delete resultTokenLPs;
        delete resultTokenRouters;
        delete resultTokenFactories;
        delete resultTokenUsdStables;
        delete resultTokenVotes;

        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    }
    function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt) external { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        require(promo.usdTarget - promo.usdUsed >= _usdAmnt, ' promo expired :( ' );
        require(CALLIT_VAULT.ACCT_USD_BALANCES(msg.sender) >= _usdAmnt, ' low balance ;{ ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint64 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');

        // potential exploitation preventions
        //  promotor can't earn both $CALL & USD reward w/ their own promo
        //  maker can't earn $CALL twice on same market (from both "promo buy" & "making market")
        require(promo.promotor != msg.sender, ' !use your own promo :0 ');
        require(mark.maker != msg.sender,' !promo buy for maker ;( ');

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        
        // check if msg.sender earned $CALL tokens
        if (_usdAmnt >= RATIO_PROMO_USD_PER_CALL_TOK) {
            // mint $CALL to msg.sender & log $CALL votes earned
            _mintCallToksEarned(msg.sender, _usdAmnt / RATIO_PROMO_USD_PER_CALL_TOK); // emit CallTokensEarned
        }

        // verify perc calc/taking <= 100% of _usdAmnt
        require(promo.percReward + PERC_PROMO_BUY_FEE <= 10000, ' buy promo fee perc mismatch :o ');

        // pay promotor usd reward & purchase msg.sender's tickets from DEX
        (uint64 net_usdAmnt, uint256 tick_amnt_out) = CALLIT_VAULT._payPromotorDeductFeesBuyTicket(promo.percReward, _usdAmnt, promo.promotor, _promoCodeHash, _ticket, mark.marketResults.resultTokenUsdStables[tickIdx], PERC_PROMO_BUY_FEE, msg.sender);
        
        // emit log
        emit PromoBuyPerformed(msg.sender, _promoCodeHash, mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out);

        // update promo.usdUsed (add full OG input _usdAmnt)
        promo.usdUsed += _usdAmnt;
    }
    function exeArbPriceParityForTicket(address _ticket) external { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint64 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');

        // calc target usd price for _ticket (in order to bring this market to price parity)
        //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        // uint64 ticketTargetPriceUSD = _getCallTicketUsdTargetPrice(mark, _ticket, MIN_USD_CALL_TICK_TARGET_PRICE);
        uint64 ticketTargetPriceUSD = CALLIT_VAULT._getCallTicketUsdTargetPrice(mark.marketResults.resultOptionTokens, mark.marketResults.resultTokenLPs, mark.marketResults.resultTokenUsdStables, _ticket, MIN_USD_CALL_TICK_TARGET_PRICE);

        // (uint64 tokensToMint, uint64 gross_stab_amnt_out, uint64 total_usd_cost, uint64 net_usd_profits) = _performTicketMintaAndDexSell(_ticket, ticketTargetPriceUSD, mark.marketResults.resultTokenUsdStables[tickIdx], mark.marketResults.resultTokenLPs[tickIdx], mark.marketResults.resultTokenRouters[tickIdx], PERC_ARB_EXE_FEE);
        (uint64 tokensToMint, uint64 total_usd_cost) = CALLIT_VAULT._performTicketMint(mark, tickIdx, ticketTargetPriceUSD, _ticket, msg.sender);
        (uint64 gross_stab_amnt_out, uint64 net_usd_profits) = CALLIT_VAULT._performTicketMintedDexSell(mark, tickIdx, _ticket, PERC_ARB_EXE_FEE, tokensToMint, total_usd_cost, msg.sender);

        // // calc # of _ticket tokens to mint for DEX sell (to bring _ticket to price parity w/ target price)
        // uint256 _usdTickTargPrice = CALLIT_LIB._normalizeStableAmnt(CALLIT_VAULT._usd_decimals(), ticketTargetPriceUSD, CALLIT_VAULT.USD_STABLE_DECIMALS(mark.marketResults.resultTokenUsdStables[tickIdx]));
        // uint64 /* ~18,000Q */ tokensToMint = CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._calculateTokensToMint(mark.marketResults.resultTokenLPs[tickIdx], _usdTickTargPrice));

        // // calc price to charge msg.sender for minting tokensToMint
        // //  then deduct that amount from their account balance
        // uint64 total_usd_cost = ticketTargetPriceUSD * tokensToMint;
        // if (msg.sender != KEEPER) { // free for KEEPER
        //     // verify msg.sender usd balance covers contract sale of minted discounted tokens
        //     //  NOTE: msg.sender is buying 'tokensToMint' amount @ price = 'ticketTargetPriceUSD', from this contract
        //     require(CALLIT_VAULT.ACCT_USD_BALANCES(msg.sender) >= total_usd_cost, ' low balance :( ');

        //     // deduce that sale amount from their account balance
        //     // CALLIT_VAULT.ACCT_USD_BALANCES[msg.sender] -= total_usd_cost; 
        //     CALLIT_VAULT.edit_ACCT_USD_BALANCES(msg.sender, total_usd_cost, false); // false = sub
        // }

        // // mint tokensToMint count to this factory and sell on DEX on behalf of msg.sender
        // //  NOTE: receiver == address(this), NOT msg.sender (need to deduct fees before paying msg.sender)
        // ICallitTicket cTicket = ICallitTicket(_ticket);
        // cTicket.mintForPriceParity(address(this), tokensToMint);
        // require(cTicket.balanceOf(address(this)) >= tokensToMint, ' err: cTicket mint :<> ');

        // // address[2] memory tok_stab_path = [_ticket, mark.resultTokenUsdStables[tickIdx]];
        // address[] memory tok_stab_path = new address[](2);
        // tok_stab_path[0] = _ticket;
        // tok_stab_path[1] = mark.marketResults.resultTokenUsdStables[tickIdx];
        // uint256 usdAmntOut = CALLIT_VAULT._exeSwapTokForStable_router(tokensToMint, tok_stab_path, address(this), mark.marketResults.resultTokenRouters[tickIdx]); // swap tick: use specific router tck:tick-stable
        // uint64 gross_stab_amnt_out = CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(CALLIT_VAULT.USD_STABLE_DECIMALS(mark.marketResults.resultTokenUsdStables[tickIdx]), usdAmntOut, CALLIT_VAULT._usd_decimals()));

        // // calc & send net profits to msg.sender
        // //  NOTE: msg.sender gets all of 'gross_stab_amnt_out' (since the contract keeps total_usd_cost)
        // //  NOTE: 'net_usd_profits' is msg.sender's profit (after additional fees)
        // uint64 net_usd_profits = CALLIT_LIB._deductFeePerc(gross_stab_amnt_out, PERC_ARB_EXE_FEE, gross_stab_amnt_out);
        // require(net_usd_profits > total_usd_cost, ' no profit from arb attempt :( '); // verify msg.sender profit
        // IERC20(mark.marketResults.resultTokenUsdStables[tickIdx]).transfer(msg.sender, net_usd_profits);

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = _mintCallToksEarned(msg.sender, RATIO_CALL_MINT_PER_ARB_EXE); // emit CallTokensEarned

        // // emit log of this arb price correction
        emit ArbPriceCorrectionExecuted(msg.sender, _ticket, ticketTargetPriceUSD, tokensToMint, gross_stab_amnt_out, total_usd_cost, net_usd_profits, callEarnedAmnt);
    }
    function closeMarketCallsForTicket(address _ticket) external { // NOTE: !_deductFeePerc; reward mint
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');

        // algorithmic logic...
        //  get market for _ticket
        //  verify mark.marketDatetimes.dtCallDeadline has indeed passed
        //  loop through _ticket LP addresses and pull all liquidity

        // get MARKET & idx for _ticket & validate call time indeed ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark,) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline <= block.timestamp, ' _ticket call deadline not passed yet :(( ');
        require(mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls closed already :p '); // usdAmntPrizePool: defaults to 0, unless closed and liq pulled to fill it

        // loop through pair addresses and pull liquidity 
        address[] memory _ticketLPs = mark.marketResults.resultTokenLPs;
        for (uint16 i = 0; i < _ticketLPs.length;) { // MAX_RESULTS is uint16
            uint256 amountToken1 = CALLIT_VAULT._exePullLiquidityFromLP(mark.marketResults.resultTokenRouters[i], _ticketLPs[i], mark.marketResults.resultOptionTokens[i], mark.marketResults.resultTokenUsdStables[i]);

            // update market prize pool usd received from LP (usdAmntPrizePool: defualts to 0)
            mark.marketUsdAmnts.usdAmntPrizePool += CALLIT_LIB._uint64_from_uint256(amountToken1); // NOTE: write to market

            unchecked {
                i++;
            }
        }

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = _mintCallToksEarned(msg.sender, RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS); // emit CallTokensEarned

        // emit log for this closed market calls event
        emit MarketCallsClosed(msg.sender, _ticket, mark.maker, mark.marketNum, mark.marketUsdAmnts.usdAmntPrizePool, callEarnedAmnt);
    }
    function castVoteForMarketTicket(address _ticket) external { // NOTE: !_deductFeePerc; reward mint
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{=} ');
        require(IERC20(_ticket).balanceOf(msg.sender) == 0, ' no self voting ;( ');

        // algorithmic logic...
        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        //  - store vote in struct MARKET_VOTE and push to ACCT_MARKET_VOTES
        //  - 

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint16 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteStart <= block.timestamp, ' market voting not started yet :p ');
        require(mark.marketDatetimes.dtResultVoteEnd > block.timestamp, ' market voting ended :p ');

        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        // (bool is_maker, bool is_caller) = _addressIsMarketMakerOrCaller(msg.sender, mark);
        (bool is_maker, bool is_caller) = CALLIT_LIB._addressIsMarketMakerOrCaller(msg.sender, mark.maker, mark.marketResults.resultOptionTokens);
        require(!is_maker && !is_caller, ' no self-voting :o ');

        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        // uint64 vote_cnt = _validVoteCount(msg.sender, mark);
        uint64 vote_cnt = CALLIT_LIB._validVoteCount(balanceOf(msg.sender), EARNED_CALL_VOTES[msg.sender], ACCT_CALL_VOTE_LOCK_TIME[msg.sender], mark.blockTimestamp);
        require(vote_cnt > 0, ' invalid voter :{=} ');

        //  - store vote in struct MARKET
        mark.marketResults.resultTokenVotes[tickIdx] += vote_cnt; // NOTE: write to market

        // log market vote per EOA, so EOA can claim voter fees earned (where votes = "majority of votes / winning result option")
        ACCT_MARKET_VOTES[msg.sender].push(ICallitLib.MARKET_VOTE(msg.sender, _ticket, tickIdx, vote_cnt, mark.maker, mark.marketNum, false)); // false = not paid
            // NOTE: *WARNING* if ACCT_MARKET_VOTES was public, then anyone can see the votes before voting has ended

        // NOTE: do not want to emit event log for casting votes 
        //  this will allow people to see majority votes before voting

        // mint $CALL token reward to msg.sender
        _mintCallToksEarned(msg.sender, RATIO_CALL_MINT_PER_VOTE); // emit CallTokensEarned
    }
    function closeMarketForTicket(address _ticket) external { // _deductFeePerc PERC_MARKET_CLOSE_FEE from mark.marketUsdAmnts.usdAmntPrizePool
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{-} ');
        // algorithmic logic...
        //  - count votes in mark.resultTokenVotes 
        //  - set mark.winningVoteResultIdx accordingly
        //  - calc market usdVoterRewardPool (using global KEEPER set percent)
        //  - calc market usdRewardPerVote (for voter reward claiming)
        //  - calc & mint $CALL to market maker (if earned)
        //  - set market 'live' status = false;

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark,) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market voting not done yet ;=) ');

        // getting winning result index to set mark.winningVoteResultIdx
        //  for voter fee claim algorithm (ie. only pay majority voters)
        // mark.winningVoteResultIdx = _getWinningVoteIdxForMarket(mark); // NOTE: write to market
        mark.winningVoteResultIdx = CALLIT_LIB._getWinningVoteIdxForMarket(mark.marketResults.resultTokenVotes); // NOTE: write to market

        // validate total % pulling from 'usdVoterRewardPool' is not > 100% (10000 = 100.00%)
        require(PERC_PRIZEPOOL_VOTERS + PERC_MARKET_CLOSE_FEE <= 10000, ' perc error ;( ');

        // calc & save total voter usd reward pool (ie. a % of prize pool in mark)
        mark.marketUsdAmnts.usdVoterRewardPool = CALLIT_LIB._perc_of_uint64(PERC_PRIZEPOOL_VOTERS, mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market

        // calc & set net prize pool after taking out voter reward pool (+ other market close fees)
        mark.marketUsdAmnts.usdAmntPrizePool_net = mark.marketUsdAmnts.usdAmntPrizePool - mark.marketUsdAmnts.usdVoterRewardPool; // NOTE: write to market
        mark.marketUsdAmnts.usdAmntPrizePool_net = CALLIT_LIB._deductFeePerc(mark.marketUsdAmnts.usdAmntPrizePool_net, PERC_MARKET_CLOSE_FEE, mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market
        
        // calc & save usd payout per vote ("usd per vote" = usd reward pool / total winning votes)
        mark.marketUsdAmnts.usdRewardPerVote = mark.marketUsdAmnts.usdVoterRewardPool / mark.marketResults.resultTokenVotes[mark.winningVoteResultIdx]; // NOTE: write to market

        // check if mark.maker earned $CALL tokens
        if (mark.marketUsdAmnts.usdAmntLP >= RATIO_LP_USD_PER_CALL_TOK) {
            // mint $CALL to mark.maker & log $CALL votes earned
            _mintCallToksEarned(mark.maker, mark.marketUsdAmnts.usdAmntLP / RATIO_LP_USD_PER_CALL_TOK); // emit CallTokensEarned
        }

        // close market
        mark.live = false; // NOTE: write to market

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = _mintCallToksEarned(msg.sender, RATIO_CALL_MINT_PER_MARK_CLOSE); // emit CallTokensEarned

        // emit log for closed market
        emit MarketClosed(msg.sender, _ticket, mark.maker, mark.marketNum, mark.winningVoteResultIdx, mark.marketUsdAmnts.usdAmntPrizePool_net, mark.marketUsdAmnts.usdVoterRewardPool, mark.marketUsdAmnts.usdRewardPerVote, callEarnedAmnt);

        // $CALL token earnings design...
        //  DONE - buyer earns $CALL in 'buyCallTicketWithPromoCode'
        //  DONE - market maker should earn call when market is closed (init LP requirement needed)
        //  DONE - invoking 'closeMarketCallsForTicket' earns $CALL
        //  DONE - invoking 'closeMarketForTicket' earns $CALL
        //  DONE - market losers can trade-in their tickets for minted $CALL
        // log $CALL votes earned w/ ...
        // EARNED_CALL_VOTES[msg.sender] += (_usdAmnt / RATIO_PROMO_USD_PER_CALL_TOK);
    }
    function claimTicketRewards(address _ticket, bool _resultAgree) external { // _deductFeePerc PERC_CLAIM_WIN_FEE from usdPrizePoolShare
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{+} ');
        require(IERC20(_ticket).balanceOf(msg.sender) > 0, ' ticket !owned ;( ');
        // algorithmic logic...
        //  - check if market voting ended & makr not live
        //  - check if _ticket is a winner
        //  - calc payout based on: _ticket.balanceOf(msg.sender) & mark.marketUsdAmnts.usdAmntPrizePool_net & _ticket.totalSupply();
        //  - send payout to msg.sender
        //  - burn IERC20(_ticket).balanceOf(msg.sender)
        //  - log _resultAgree in MARKET_REVIEW

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint64 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market voting not done yet ;=) ');
        require(!mark.live, ' market still live :o ' );
        require(mark.winningVoteResultIdx == tickIdx, ' not a winner :( ');

        bool is_winner = mark.winningVoteResultIdx == tickIdx;
        if (is_winner) {
            // calc payout based on: _ticket.balanceOf(msg.sender) & mark.marketUsdAmnts.usdAmntPrizePool_net & _ticket.totalSupply();
            uint64 usdPerTicket = CALLIT_LIB._uint64_from_uint256(uint256(mark.marketUsdAmnts.usdAmntPrizePool_net) / IERC20(_ticket).totalSupply());
            uint64 usdPrizePoolShare = CALLIT_LIB._uint64_from_uint256(uint256(usdPerTicket) * IERC20(_ticket).balanceOf(msg.sender));

            // send payout to msg.sender
            usdPrizePoolShare = CALLIT_LIB._deductFeePerc(usdPrizePoolShare, PERC_CLAIM_WIN_FEE, usdPrizePoolShare);
            CALLIT_VAULT._payUsdReward(usdPrizePoolShare, msg.sender);
        } else {
            // NOTE: perc requirement limits ability for exploitation and excessive $CALL minting
            uint64 perc_supply_owned = CALLIT_LIB._perc_total_supply_owned(_ticket, msg.sender);
            if (perc_supply_owned >= PERC_OF_LOSER_SUPPLY_EARN_CALL) {
                // mint $CALL to loser msg.sender & log $CALL votes earned
                _mintCallToksEarned(msg.sender, RATIO_CALL_MINT_PER_LOSER); // emit CallTokensEarned

                // NOTE: this action could open up a secondary OTC market for collecting loser tickets
                //  ie. collecting losers = minting $CALL
            }
        }

        // burn IERC20(_ticket).balanceOf(msg.sender)
        ICallitTicket cTicket = ICallitTicket(_ticket);
        cTicket.burnForWinLoseClaim(msg.sender, cTicket.balanceOf(msg.sender));

        // log caller's review of market results
        // _logMarketResultReview(mark, _resultAgree); // emits MarketReviewed
        (ICallitLib.MARKET_REVIEW memory marketReview, uint64 agreeCnt, uint64 disagreeCnt) = CALLIT_LIB._logMarketResultReview(mark.maker, mark.marketNum, ACCT_MARKET_REVIEWS[mark.maker], _resultAgree);
        ACCT_MARKET_REVIEWS[mark.maker].push(marketReview);
        emit MarketReviewed(msg.sender, _resultAgree, mark.maker, mark.marketNum, agreeCnt, disagreeCnt);
          
        // emit log event for claimed ticket
        emit TicketClaimed(msg.sender, _ticket, is_winner, _resultAgree);

        // NOTE: no $CALL tokens minted for this action   
    }
    function claimVoterRewards() external { // _deductFeePerc PERC_VOTE_CLAIM_FEE from usdRewardOwed
        // NOTE: loops through all non-piad msg.sender votes (including 'live' markets)
        require(ACCT_MARKET_VOTES[msg.sender].length > 0, ' no un-paid market votes :) ');
        uint64 usdRewardOwed = 0;
        for (uint64 i = 0; i < ACCT_MARKET_VOTES[msg.sender].length;) { // uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
            ICallitLib.MARKET_VOTE storage m_vote = ACCT_MARKET_VOTES[msg.sender][i];
            (ICallitLib.MARKET storage mark,) = _getMarketForTicket(m_vote.marketMaker, m_vote.voteResultToken); // reverts if market not found | address(0)

            // skip live MARKETs
            if (mark.live) {
                unchecked {i++;}
                continue;
            }

            // verify voter should indeed be paid & add usd reward to usdRewardOwed
            //  ie. msg.sender's vote == winning result option (majority of votes)
            //       AND ... this MARKET_VOTE has not been paid yet
            if (m_vote.voteResultIdx == mark.winningVoteResultIdx && !m_vote.paid) {
                usdRewardOwed += mark.marketUsdAmnts.usdRewardPerVote * m_vote.voteResultCnt;
                m_vote.paid = true; // set paid // NOTE: write to market
            }

            // check for 'paid' MARKET_VOTE found in ACCT_MARKET_VOTES (& move to ACCT_MARKET_VOTES_PAID)
            //  NOTE: integration moves MARKET_VOTE that was just set as 'paid' above, to ACCT_MARKET_VOTES_PAID
            //   AND ... catches any 'prev-paid' MARKET_VOTEs lingering in non-paid ACCT_MARKET_VOTES array
            if (m_vote.paid) { 
                _moveMarketVoteIdxToPaid(m_vote, i);
                continue; // Skip 'i++'; continue w/ current idx, to check new item at position 'i'
            }
            unchecked {i++;}
        }

        // usdRewardOwed = _deductVoterClaimFees(usdRewardOwed, usdRewardOwed);
        // usdRewardOwed = CALLIT_LIB._deductFeePerc(usdRewardOwed, PERC_VOTE_CLAIM_FEE, usdRewardOwed);
        // _payUsdReward(usdRewardOwed, msg.sender); // pay w/ lowest value whitelist stable held (returns on 0 reward)

        uint64 usdRewardOwed_net = CALLIT_LIB._deductFeePerc(usdRewardOwed, PERC_VOTE_CLAIM_FEE, usdRewardOwed);
        CALLIT_VAULT._payUsdReward(usdRewardOwed_net, msg.sender); // pay w/ lowest value whitelist stable held (returns on 0 reward)

        // emit log for rewards claimed
        emit VoterRewardsClaimed(msg.sender, usdRewardOwed, usdRewardOwed_net);

        // NOTE: no $CALL tokens minted for this action   
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (CALLIT MANAGER) // NOTE: migrate to CallitVault (ALL)
    /* -------------------------------------------------------- */
    function _getMarketForTicket(address _maker, address _ticket) private view returns(ICallitLib.MARKET storage, uint16) {
        require(_maker != address (0) && _ticket != address(0), ' no address for market ;:[=] ');

        // NOTE: MAX_EOA_MARKETS is uint64
        ICallitLib.MARKET[] storage markets = ACCT_MARKETS[_maker];
        for (uint64 i = 0; i < markets.length;) {
            ICallitLib.MARKET storage mark = markets[i];
            for (uint16 x = 0; x < mark.marketResults.resultOptionTokens.length;) {
                if (mark.marketResults.resultOptionTokens[x] == _ticket)
                    return (mark, x);
                unchecked {x++;}
            }   
            unchecked {
                i++;
            }
        }
        
        revert(' market not found :( ');
    }
    function _moveMarketVoteIdxToPaid(ICallitLib.MARKET_VOTE storage _m_vote, uint64 _idxMove) private {
        // add this MARKET_VOTE to ACCT_MARKET_VOTES_PAID[msg.sender]
        ACCT_MARKET_VOTES_PAID[msg.sender].push(_m_vote);

        // remove _idxMove MARKET_VOTE from ACCT_MARKET_VOTES[msg.sender]
        //  by replacing it with the last element (then popping last element)
        uint64 lastIdx = uint64(ACCT_MARKET_VOTES[msg.sender].length) - 1;
        if (_idxMove != lastIdx) {
            ACCT_MARKET_VOTES[msg.sender][_idxMove] = ACCT_MARKET_VOTES[msg.sender][lastIdx];
        }
        ACCT_MARKET_VOTES[msg.sender].pop(); // Remove the last element (now a duplicate)
    }
    function _mintCallToksEarned(address _receiver, uint64 _callAmnt) private returns(uint64) {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        _mint(_receiver, _callAmnt);
        uint64 prevEarned = EARNED_CALL_VOTES[_receiver];
        EARNED_CALL_VOTES[_receiver] += _callAmnt;

        // emit log for call tokens earned
        emit CallTokensEarned(msg.sender, _receiver, _callAmnt, prevEarned, EARNED_CALL_VOTES[_receiver]);
        return EARNED_CALL_VOTES[_receiver];
        // NOTE: call tokens earned on ...
        //  buyCallTicketWithPromoCode
        //  closeMarketForTicket
        //  claimTicketRewards
    }
    /* -------------------------------------------------------- */
    /* ERC20 - OVERRIDES                                        */
    /* -------------------------------------------------------- */
    function symbol() public view override returns (string memory) {
        return TOK_SYMB;
    }
    function name() public view override returns (string memory) {
        return TOK_NAME;
    }
    function burn(uint64 _burnAmnt) external {
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
    
    // /* -------------------------------------------------------- */
    // /* PRIVATTE - SUPPORTING (CALLIT market management) _ // note: migrate to CallitVault (ALL)
    // /* -------------------------------------------------------- */
    // function _performTicketMintaAndDexSell(address _targetTicket, uint64 _targetTickPriceUSD, address _targetTickStable, address _targetTickPairAddr, address _targetTickRouter) private returns(uint64,uint64,uint64,uint64) {
    //     // calc # of _ticket tokens to mint for DEX sell (to bring _ticket to price parity w/ target price)
    //     uint256 _usdTickTargPrice = CALLIT_LIB._normalizeStableAmnt(CALLIT_VAULT._usd_decimals(), _targetTickPriceUSD, CALLIT_VAULT.USD_STABLE_DECIMALS(_targetTickStable));
    //     uint64 /* ~18,000Q */ tokensToMint = CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._calculateTokensToMint(_targetTickPairAddr, _usdTickTargPrice));

    //     // calc price to charge msg.sender for minting tokensToMint
    //     //  then deduct that amount from their account balance
    //     uint64 total_usd_cost = _targetTickPriceUSD * tokensToMint;
    //     if (msg.sender != KEEPER) { // free for KEEPER
    //         // verify msg.sender usd balance covers contract sale of minted discounted tokens
    //         //  NOTE: msg.sender is buying 'tokensToMint' amount @ price = 'ticketTargetPriceUSD', from this contract
    //         require(CALLIT_VAULT.ACCT_USD_BALANCES(msg.sender) >= total_usd_cost, ' low balance :( ');

    //         // deduce that sale amount from their account balance
    //         // CALLIT_VAULT.ACCT_USD_BALANCES[msg.sender] -= total_usd_cost; 
    //         CALLIT_VAULT.edit_ACCT_USD_BALANCES(msg.sender, total_usd_cost, false); // false = sub
    //     }

    //     // mint tokensToMint count to this factory and sell on DEX on behalf of msg.sender
    //     //  NOTE: receiver == address(this), NOT msg.sender (need to deduct fees before paying msg.sender)
    //     ICallitTicket cTicket = ICallitTicket(_targetTicket);
    //     cTicket.mintForPriceParity(address(this), tokensToMint);
    //     require(cTicket.balanceOf(address(this)) >= tokensToMint, ' err: cTicket mint :<> ');
    //     // address[2] memory tok_stab_path = [_ticket, mark.resultTokenUsdStables[tickIdx]];
    //     address[] memory tok_stab_path = new address[](2);
    //     tok_stab_path[0] = _targetTicket;
    //     tok_stab_path[1] = _targetTickStable;
    //     uint256 usdAmntOut = CALLIT_VAULT._exeSwapTokForStable_router(tokensToMint, tok_stab_path, address(this), _targetTickRouter); // swap tick: use specific router tck:tick-stable
    //     uint64 gross_stab_amnt_out = CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(CALLIT_VAULT.USD_STABLE_DECIMALS(_targetTickStable), usdAmntOut, CALLIT_VAULT._usd_decimals()));

    //     // calc & send net profits to msg.sender
    //     //  NOTE: msg.sender gets all of 'gross_stab_amnt_out' (since the contract keeps total_usd_cost)
    //     //  NOTE: 'net_usd_profits' is msg.sender's profit (after additional fees)
    //     uint64 net_usd_profits = CALLIT_LIB._deductFeePerc(gross_stab_amnt_out, PERC_ARB_EXE_FEE, gross_stab_amnt_out);
    //     require(net_usd_profits > total_usd_cost, ' no profit from arb attempt :( '); // verify msg.sender profit
    //     IERC20(_targetTickStable).transfer(msg.sender, net_usd_profits);

    //     return (tokensToMint, gross_stab_amnt_out, total_usd_cost, net_usd_profits);
    // }
    // function _exePullLiquidityFromLP(address _tokenRouter, address _pairAddress, address _token, address _usdStable) private returns(uint256) {
    //     // IUniswapV2Factory uniswapFactory = IUniswapV2Factory(mark.resultTokenFactories[i]);
    //     IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(_tokenRouter);
        
    //     // pull liquidity from pairAddress
    //     IERC20 pairToken = IERC20(_pairAddress);
    //     uint256 liquidity = pairToken.balanceOf(address(this));  // Get the contract's balance of the LP tokens
        
    //     // Approve the router to spend the LP tokens
    //     pairToken.approve(address(uniswapRouter), liquidity);
        
    //     // Retrieve the token pair
    //     address token0 = IUniswapV2Pair(_pairAddress).token0();
    //     address token1 = IUniswapV2Pair(_pairAddress).token1();

    //     // check to make sure that token0 is the 'ticket' & token1 is the 'stable'
    //     require(_token == token0 && _usdStable == token1, ' pair token mismatch w/ MARKET tck:usd :*() ');

    //     // get OG stable balance, so we can verify later
    //     uint256 OG_stable_bal = IERC20(_usdStable).balanceOf(address(this));

    //     // Remove liquidity
    //     (, uint256 amountToken1) = uniswapRouter.removeLiquidity(
    //         token0,
    //         token1,
    //         liquidity,
    //         0, // Min amount of token0, to prevent slippage (adjust based on your needs)
    //         0, // Min amount of token1, to prevent slippage (adjust based on your needs)
    //         address(this), // Send tokens to the contract itself or a specified recipient
    //         block.timestamp + 300 // Deadline (5 minutes from now)
    //     );

    //     // verify correct ticket token stable was pulled and recieved
    //     require(IERC20(_usdStable).balanceOf(address(this)) >= OG_stable_bal, ' stab bal mismatch after liq pull :+( ');
    //     return amountToken1;
    // }
    // function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok) private {
    //     // calc influencer reward from _usdAmnt to send to promo.promotor
    //     uint64 usdReward = CALLIT_LIB._perc_of_uint64(_percReward, _usdAmnt);
    //     CALLIT_VAULT._payUsdReward(usdReward, _promo`tor); // pay w/ lowest value whitelist stable held (returns on 0 reward)
    //     emit PromoRewardPaid(_promoCodeHash, usdReward, _promotor, msg.sender, _ticket);

    //     // deduct usdReward & promo buy fee _usdAmnt
    //     uint64 net_usdAmnt = _usdAmnt - usdReward;
    //     net_usdAmnt = CALLIT_LIB._deductFeePerc(net_usdAmnt, PERC_PROMO_BUY_FEE, _usdAmnt);

    //     // verifiy contract holds enough tick_stable_tok for DEX buy
    //     //  if not, swap another contract held stable that can indeed cover
    //     // address tick_stable_tok = mark.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
    //     // address tick_stable_tok = mark.marketResults.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
    //     uint256 contr_stab_bal = IERC20(_tick_stable_tok).balanceOf(address(this)); 
    //     if (contr_stab_bal < net_usdAmnt) { // not enough tick_stable_tok to cover 'net_usdAmnt' buy
    //         uint64 net_usdAmnt_needed = net_usdAmnt - CALLIT_LIB._uint64_from_uint256(contr_stab_bal);
    //         (uint256 stab_amnt_out, address stab_swap_from)  = CALLIT_VAULT._swapBestStableForTickStable(net_usdAmnt_needed, _tick_stable_tok);
    //         emit AlertStableSwap(net_usdAmnt, contr_stab_bal, stab_swap_from, _tick_stable_tok, net_usdAmnt_needed, stab_amnt_out);

    //         // verify
    //         require(IERC20(_tick_stable_tok).balanceOf(address(this)) >= net_usdAmnt, ' tick-stable swap failed :[] ' );
    //     }

    //     // swap remaining net_usdAmnt of tick_stable_tok for _ticket on DEX (_ticket receiver = msg.sender)
    //     // address[] memory usd_tick_path = [tick_stable_tok, _ticket]; // ref: https://ethereum.stackexchange.com/a/28048
    //     address[] memory usd_tick_path = new address[](2);
    //     usd_tick_path[0] = _tick_stable_tok;
    //     usd_tick_path[1] = _ticket; // NOTE: not swapping for 'this' contract
    //     uint256 tick_amnt_out = CALLIT_VAULT._exeSwapStableForTok(net_usdAmnt, usd_tick_path, msg.sender); // msg.sender = _receiver

    //     // deduct full OG input _usdAmnt from account balance
    //     // CALLIT_VAULT.ACCT_USD_BALANCES[msg.sender] -= _usdAmnt;
    //     CALLIT_VAULT.edit_ACCT_USD_BALANCES(msg.sender, _usdAmnt, false); // false = sub

    //     // emit log
    //     emit PromoBuyPerformed(msg.sender, _promoCodeHash, _tick_stable_tok, _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out);
    // }
    // // function _logMarketResultReview(ICallitLib.MARKET storage _mark, bool _resultAgree) private {
    // function _logMarketResultReview(address _maker, uint256 _markNum, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) private view returns(ICallitLib.MARKET_REVIEW memory, uint64, uint64) {
    //     uint64 agreeCnt = 0;
    //     uint64 disagreeCnt = 0;
    //     // uint64 reviewCnt = CALLIT_LIB._uint64_from_uint256(ACCT_MARKET_REVIEWS[_mark.maker].length);
    //     // if (reviewCnt > 0) {
    //     //     agreeCnt = ACCT_MARKET_REVIEWS[_mark.maker][reviewCnt-1].agreeCnt;
    //     //     disagreeCnt = ACCT_MARKET_REVIEWS[_mark.maker][reviewCnt-1].disagreeCnt;
    //     // }
    //     uint64 reviewCnt = CALLIT_LIB._uint64_from_uint256(_makerReviews.length);
    //     if (reviewCnt > 0) {
    //         agreeCnt = _makerReviews[reviewCnt-1].agreeCnt;
    //         disagreeCnt = _makerReviews[reviewCnt-1].disagreeCnt;
    //     }

    //     agreeCnt = _resultAgree ? agreeCnt+1 : agreeCnt;
    //     disagreeCnt = !_resultAgree ? disagreeCnt+1 : disagreeCnt;
    //     // ACCT_MARKET_REVIEWS[_mark.maker].push(ICallitLib.MARKET_REVIEW(msg.sender, _resultAgree, _mark.maker, _mark.marketNum, agreeCnt, disagreeCnt));
    //     // emit MarketReviewed(msg.sender, _resultAgree, _mark.maker, _mark.marketNum, agreeCnt, disagreeCnt);

    //     return (ICallitLib.MARKET_REVIEW(msg.sender, _resultAgree, _maker, _markNum, agreeCnt, disagreeCnt), agreeCnt, disagreeCnt);
    // }
    // function _validVoteCount(address _voter, ICallitLib.MARKET storage _mark) private view returns(uint64) {
    // function _validVoteCount(uint64 _votesEarned, uint256 _voterLockTime, uint256 _markCreateTime) private view returns(uint64) {
    //     // if indeed locked && locked before _mark start time, calc & return active vote count
    //     // if (ACCT_CALL_VOTE_LOCK_TIME[_voter] > 0 && ACCT_CALL_VOTE_LOCK_TIME[_voter] <= _mark.blockTimestamp) {
    //     //     uint64 votes_earned = EARNED_CALL_VOTES[_voter]; // note: EARNED_CALL_VOTES stores uint64 type
    //     //     uint64 votes_held = CALLIT_LIB._uint64_from_uint256(balanceOf(msg.sender));
    //     //     uint64 votes_active = votes_held >= votes_earned ? votes_earned : votes_held;
    //     //     return votes_active;
    //     // }

    //     // if indeed locked && locked before _mark start time, calc & return active vote count
    //     if (_voterLockTime > 0 && _voterLockTime <= _markCreateTime) {
    //         uint64 votes_earned = _votesEarned; // note: EARNED_CALL_VOTES stores uint64 type
    //         uint64 votes_held = CALLIT_LIB._uint64_from_uint256(balanceOf(address(this)));
    //         uint64 votes_active = votes_held >= votes_earned ? votes_earned : votes_held;
    //         return votes_active;
    //     }
    //     else
    //         return 0; // return no valid votes
    // }
    // // function _getWinningVoteIdxForMarket(ICallitLib.MARKET storage _mark) private view returns(uint16) { // should be 'view' not 'pure'?
    // function _getWinningVoteIdxForMarket(uint64[] memory _resultTokenVotes) private pure returns(uint16) { // should be 'view' not 'pure'?
    //     // travers mark.resultTokenVotes for winning idx
    //     //  NOTE: default winning index is 0 & ties will settle on lower index
    //     uint16 idxCurrHigh = 0;
    //     // for (uint16 i = 0; i < _mark.marketResults.resultTokenVotes.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
    //     //     if (_mark.marketResults.resultTokenVotes[i] > _mark.marketResults.resultTokenVotes[idxCurrHigh])
    //     //         idxCurrHigh = i;
    //     //     unchecked {i++;}
    //     // }
    //     for (uint16 i = 0; i < _resultTokenVotes.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
    //         if (_resultTokenVotes[i] > _resultTokenVotes[idxCurrHigh])
    //             idxCurrHigh = i;
    //         unchecked {i++;}
    //     }
    //     return idxCurrHigh;
    // }
    // // function _addressIsMarketMakerOrCaller(address _addr, ICallitLib.MARKET storage _mark) private view returns(bool, bool) {
    // function _addressIsMarketMakerOrCaller(address _addr, address _markMaker, address[] memory _resultOptionTokens) private view returns(bool, bool) {
    //     // bool is_maker = _mark.maker == msg.sender; // true = found maker
    //     // bool is_caller = false;
    //     // for (uint16 i = 0; i < _mark.marketResults.resultOptionTokens.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
    //     //     is_caller = IERC20(_mark.marketResults.resultOptionTokens[i]).balanceOf(_addr) > 0; // true = found caller
    //     //     unchecked {i++;}
    //     // }

    //     bool is_maker = _markMaker == msg.sender; // true = found maker
    //     bool is_caller = false;
    //     for (uint16 i = 0; i < _resultOptionTokens.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
    //         is_caller = IERC20(_resultOptionTokens[i]).balanceOf(_addr) > 0; // true = found caller
    //         unchecked {i++;}
    //     }

    //     return (is_maker, is_caller);
    // }
    // // function _getCallTicketUsdTargetPrice(ICallitLib.MARKET storage _mark, address _ticket, uint64 _usdMinTargetPrice) private view returns(uint64) {
    // function _getCallTicketUsdTargetPrice(address[] memory _resultTickets, address[] memory _pairAddresses, address[] memory _resultStables, address _ticket, uint64 _usdMinTargetPrice) private view returns(uint64) {
    //     require(_resultTickets.length == _pairAddresses.length, ' tick/pair arr length mismatch :o ');
    //     // algorithmic logic ...
    //     //  calc sum of usd value dex prices for all addresses in '_mark.resultOptionTokens' (except _ticket)
    //     //   -> input _ticket target price = 1 - SUM(all prices except _ticket)
    //     //   -> if result target price <= 0, then set/return input _ticket target price = $0.01

    //     // address[] memory tickets = _mark.marketResults.resultOptionTokens;
    //     address[] memory tickets = _resultTickets;
    //     uint64 alt_sum = 0;
    //     for(uint16 i=0; i < tickets.length;) { // MAX_RESULTS is uint16
    //         if (tickets[i] != _ticket) {
    //             // address pairAddress = _mark.marketResults.resultTokenLPs[i];
    //             address pairAddress = _pairAddresses[i];
                
    //             // uint256 usdAmountsOut = _estimateLastPriceForTCK(pairAddress, _mark.marketResults.resultTokenUsdStables[i]); // invokes _normalizeStableAmnt
    //             // alt_sum += usdAmountsOut;

    //             uint256 usdAmountsOut = CALLIT_LIB._estimateLastPriceForTCK(pairAddress); // invokes _normalizeStableAmnt
    //             alt_sum += CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(CALLIT_VAULT.USD_STABLE_DECIMALS(_resultStables[i]), usdAmountsOut, CALLIT_VAULT._usd_decimals()));
    //         }
            
    //         unchecked {i++;}
    //     }

    //     // NOTE: returns negative if alt_sum is greater than 1
    //     //  edge case should be handle in caller
    //     int64 target_price = 1 - int64(alt_sum);
    //     return target_price > 0 ? uint64(target_price) : _usdMinTargetPrice; // note: min is likely 10000 (ie. $0.010000 w/ _usd_decimals() = 6)
    // }

    // /* -------------------------------------------------------- */
    // /* PRIVATE - SUPPORTING (legacy VAULT) _ // note: migrate to CallitVault (ALL)
    // /* -------------------------------------------------------- */
    // function _grossStableBalance(address[] memory _stables) private view returns (uint64) {
    //     uint64 gross_bal = 0;
    //     for (uint8 i = 0; i < _stables.length;) {
    //         // NOTE: more efficient algorithm taking up less stack space with local vars
    //         require(USD_STABLE_DECIMALS[_stables[i]] > 0, ' found stable with invalid decimals :/ ');
    //         gross_bal += CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_stables[i]], IERC20(_stables[i]).balanceOf(address(this)), _usd_decimals()));
    //         unchecked {i++;}
    //     }
    //     return gross_bal;
    // }
    // function _owedStableBalance() private view returns (uint64) {
    //     uint64 owed_bal = 0;
    //     for (uint256 i = 0; i < ACCOUNTS.length;) {
    //         owed_bal += ACCT_USD_BALANCES[ACCOUNTS[i]];
    //         unchecked {i++;}
    //     }
    //     return owed_bal;
    // }
    // function _collectiveStableBalances(address[] memory _stables) private view returns (uint64, uint64, int64, uint256) {
    //     uint64 gross_bal = _grossStableBalance(_stables);
    //     uint64 owed_bal = _owedStableBalance();
    //     int64 net_bal = int64(gross_bal) - int64(owed_bal);
    //     return (gross_bal, owed_bal, net_bal, totalSupply());
    // }
    // function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) private { // allows duplicates
    //     if (_add) {
    //         WHITELIST_USD_STABLES = CALLIT_LIB._addAddressToArraySafe(_usdStable, WHITELIST_USD_STABLES, true); // true = no dups
    //         USD_STABLES_HISTORY = CALLIT_LIB._addAddressToArraySafe(_usdStable, USD_STABLES_HISTORY, true); // true = no dups
    //         USD_STABLE_DECIMALS[_usdStable] = _decimals;
    //     } else {
    //         WHITELIST_USD_STABLES = CALLIT_LIB._remAddressFromArray(_usdStable, WHITELIST_USD_STABLES);
    //     }
    // }
    // function _editDexRouters(address _router, bool _add) private {
    //     require(_router != address(0x0), "0 address");
    //     if (_add) {
    //         USWAP_V2_ROUTERS = CALLIT_LIB._addAddressToArraySafe(_router, USWAP_V2_ROUTERS, true); // true = no dups
    //     } else {
    //         USWAP_V2_ROUTERS = CALLIT_LIB._remAddressFromArray(_router, USWAP_V2_ROUTERS); // removes only one & order NOT maintained
    //     }
    // }
    // function _getStableHeldHighMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {

    //     address[] memory _stablesHeld;
    //     for (uint8 i=0; i < _stables.length;) {
    //         if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
    //             _stablesHeld = CALLIT_LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

    //         unchecked {
    //             i++;
    //         }
    //     }
    //     return CALLIT_LIB._getStableTokenHighMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    // }
    // function _getStableHeldLowMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {
    //     // NOTE: if nothing in _stables can cover _usdAmntReq, then returns address(0x0)
    //     address[] memory _stablesHeld;
    //     for (uint8 i=0; i < _stables.length;) {
    //         if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
    //             _stablesHeld = CALLIT_LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

    //         unchecked {
    //             i++;
    //         }
    //     }
    //     return CALLIT_LIB._getStableTokenLowMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    // }
    // function _stableHoldingsCovered(uint64 _usdAmnt, address _usdStable) private view returns (bool) {
    //     if (_usdStable == address(0x0)) 
    //         return false;
    //     uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
    //     return IERC20(_usdStable).balanceOf(address(this)) >= usdAmnt_;
    // }
    // function _getTokMarketValueForUsdAmnt(uint256 _usdAmnt, address _usdStable, address[] memory _stab_tok_path) private view returns (uint256) {
    //     uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
    //     (, uint256 tok_amnt) = CALLIT_LIB._best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);
    //     return tok_amnt; 
    // }
    // function _exeSwapPlsForStable(uint256 _plsAmnt, address _usdStable) private returns (uint256) {
    //     address[] memory pls_stab_path = new address[](2);
    //     pls_stab_path[0] = TOK_WPLS;
    //     pls_stab_path[1] = _usdStable;
    //     (uint8 rtrIdx,) = CALLIT_LIB._best_swap_v2_router_idx_quote(pls_stab_path, _plsAmnt, USWAP_V2_ROUTERS);
    //     uint256 stab_amnt_out = CALLIT_LIB._swap_v2_wrap(pls_stab_path, USWAP_V2_ROUTERS[rtrIdx], _plsAmnt, address(this), true); // true = fromETH
    //     stab_amnt_out = CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_usdStable], stab_amnt_out, _usd_decimals());
    //     return stab_amnt_out;
    // }
    // // generic: gets best from USWAP_V2_ROUTERS to perform trade
    // function _exeSwapTokForStable(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver) private returns (uint256) {
    //     // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
    //     require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        
    //     (uint8 rtrIdx,) = CALLIT_LIB._best_swap_v2_router_idx_quote(_tok_stab_path, _tokAmnt, USWAP_V2_ROUTERS);
    //     uint256 stable_amnt_out = CALLIT_LIB._swap_v2_wrap(_tok_stab_path, USWAP_V2_ROUTERS[rtrIdx], _tokAmnt, _receiver, false); // true = fromETH        
    //     return stable_amnt_out;
    // }
    // // generic: gets best from USWAP_V2_ROUTERS to perform trade
    // function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) private returns (uint256) {
    //     address usdStable = _stab_tok_path[0]; // required: _stab_tok_path[0] must be a stable
    //     uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[usdStable]);
    //     (uint8 rtrIdx,) = CALLIT_LIB._best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);

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

    //     uint256 tok_amnt_out = CALLIT_LIB._swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
    //     return tok_amnt_out;
    // }
    // function _usd_decimals() private pure returns (uint8) {
    //     return 6; // (6 decimals) 
    //         // * min USD = 0.000001 (6 decimals) 
    //         // uint16 max USD: ~0.06 -> 0.065535 (6 decimals)
    //         // uint32 max USD: ~4K -> 4,294.967295 USD (6 decimals)
    //         // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // }
    // // note: migrate to CallitBank
    // function _payUsdReward(uint64 _usdReward, address _receiver) private {
    //     if (_usdReward == 0) {
    //         emit AlertZeroReward(msg.sender, _usdReward, _receiver);
    //         return;
    //     }
    //     // Get stable to work with ... (any stable that covers 'usdReward' is fine)
    //     //  NOTE: if no single stable can cover 'usdReward', lowStableHeld == 0x0, 
    //     address lowStableHeld = _getStableHeldLowMarketValue(_usdReward, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
    //     require(lowStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

    //     // pay _receiver their usdReward w/ lowStableHeld (any stable thats covered)
    //     IERC20(lowStableHeld).transfer(_receiver, CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdReward, USD_STABLE_DECIMALS[lowStableHeld]));
    // }
    // // note: migrate to CallitBank
    // function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) private returns(uint256, address){
    //     // Get stable to work with ... (any stable that covers '_usdAmnt' is fine)
    //     //  NOTE: if no single stable can cover '_usdAmnt', highStableHeld == 0x0, 
    //     address highStableHeld = _getStableHeldHighMarketValue(_usdAmnt, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
    //     require(highStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

    //     // create path and perform stable-to-stable swap
    //     // address[2] memory stab_stab_path = [highStableHeld, _tickStable];
    //     address[] memory stab_stab_path = new address[](3);
    //     stab_stab_path[0] = highStableHeld;
    //     stab_stab_path[1] = _tickStable;
    //     uint256 stab_amnt_out = _exeSwapTokForStable(_usdAmnt, stab_stab_path, address(this)); // no tick: use best from USWAP_V2_ROUTERS
    //     return (stab_amnt_out,highStableHeld);
    // }
    // // note: migrate to CallitBank at least, and maybe CallitLib as well
    // // Assumed helper functions (implementations not shown)
    // function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) private returns (address) {
    //     // declare factory & router
    //     IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(_uswapV2Router);
    //     IUniswapV2Factory uniswapFactory = IUniswapV2Factory(_uswapv2Factory);

    //     // normalize decimals _usdStable token requirements
    //     _usdAmount = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmount, USD_STABLE_DECIMALS[_usdStable]);

    //     // Approve tokens for Uniswap Router
    //     IERC20(_token).approve(_uswapV2Router, _tokenAmount);
    //     // Assuming you have a way to convert USD to ETH or a stablecoin in the contract
            
    //     // Add liquidity to the pool
    //     // (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter.addLiquidity(
    //     uniswapRouter.addLiquidity(
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
    //     address lpAddress = uniswapFactory.getPair(_token, _usdStable);
    //     return lpAddress;

    //     // NOTE: LEFT OFF HERE ... may need external support functions for LP & LP token maintence, etc.
    //     //      similar to accessors that retrieve native and ERC20 tokens held by contract
    //     //      maybe a function to trasnfer LP to an EOA
    //     //      maybe a function to manually pull all LP into this contract (or a specific receiver)
    // }

    // /* -------------------------------------------------------- */
    // /* PRIVATE - SUPPORT (ICallitLib)
    // /* -------------------------------------------------------- */
    // function _perc_total_supply_owned(address _token, address _account) private view returns (uint64) {
    //     uint256 accountBalance = IERC20(_token).balanceOf(_account);
    //     uint256 totalSupply = IERC20(_token).totalSupply();

    //     // Prevent division by zero by checking if totalSupply is greater than zero
    //     require(totalSupply > 0, "Total supply must be greater than zero");

    //     // Calculate the percentage (in basis points, e.g., 1% = 100 basis points)
    //     uint256 percentage = (accountBalance * 10000) / totalSupply;

    //     return CALLIT_LIB._uint64_from_uint256(percentage); // Returns the percentage in basis points (e.g., 500 = 5%)
    // }
    // // note: migrate to CallitLib
    // function _deductFeePerc(uint64 _net_usdAmnt, uint16 _feePerc, uint64 _usdAmnt) private view returns(uint64) {
    //     require(_feePerc <= 10000, ' invalid fee perc :p '); // 10000 = 100.00%
    //     return _net_usdAmnt - CALLIT_LIB._perc_of_uint64(_feePerc, _usdAmnt);
    // }
    // function _isAddressInArray(address _addr, address[] memory _addrArr) private pure returns(bool) {
    //     for (uint8 i = 0; i < _addrArr.length;){ // max array size = 255 (uin8 loop)
    //         if (_addrArr[i] == _addr)
    //             return true;
    //         unchecked {i++;}
    //     }
    //     return false;
    // }
    // function _genTokenNameSymbol(address _maker, uint256 _markNum, uint16 _resultNum, string storage _nameSeed, string storage _symbSeed) private pure returns(string memory, string memory) { 
    //     // Concatenate to form symbol & name
    //     // string memory last4 = _getLast4Chars(_maker);
    //     // Convert the last 2 bytes (4 characters) of the address to a string
    //     bytes memory addrBytes = abi.encodePacked(_maker);
    //     bytes memory last4 = new bytes(4);

    //     last4[0] = addrBytes[18];
    //     last4[1] = addrBytes[19];
    //     last4[2] = addrBytes[20];
    //     last4[3] = addrBytes[21];

    //     // return string(last4);
    //     // string memory tokenSymbol = string(abi.encodePacked(_nameSeed, last4, _markNum, string(abi.encodePacked(_resultNum))));
    //     // string memory tokenName = string(abi.encodePacked(_symbSeed, " ", last4, "-", _markNum, "-", string(abi.encodePacked(_resultNum))));
    //     // return (tokenName, tokenSymbol);

    //     return (string(abi.encodePacked(_nameSeed, last4, _markNum, string(abi.encodePacked(_resultNum)))), string(abi.encodePacked(_symbSeed, " ", last4, "-", _markNum, "-", string(abi.encodePacked(_resultNum)))));
    // }
    // function _validNonWhiteSpaceString(string calldata _s) private pure returns(bool) {
    //     for (uint8 i=0; i < bytes(_s).length;) {
    //         if (bytes(_s)[i] != 0x20) {
    //             // Found a non-space character, return true
    //             return true; 
    //         }
    //         unchecked {
    //             i++;
    //         }
    //     }

    //     // found string with all whitespaces as chars
    //     return false;
    // }
    // function _generateAddressHash(address host, string memory uid) private pure returns (address) {
    //     // Concatenate the address and the string, and then hash the result
    //     bytes32 hash = keccak256(abi.encodePacked(host, uid));

    //     // LEFT OFF HERE ... is this a bug? 'uint160' ? shoudl be uint16? 
    //     address generatedAddress = address(uint160(uint256(hash)));
    //     return generatedAddress;
    // }
    // function _perc_of_uint64(uint32 _perc, uint64 _num) private pure returns (uint64) {
    //     require(_perc <= 10000, 'err: invalid percent');
    //     // return _perc_of_uint64_unchecked(_perc, _num);
    //     return (_num * uint64(uint32(_perc) * 100)) / 1000000; // chatGPT equation
    // }
    // function _perc_of_uint64_unchecked(uint32 _perc, uint64 _num) private pure returns (uint64) {
    //     // require(_perc <= 10000, 'err: invalid percent');
    //     // uint32 aux_perc = _perc * 100; // Multiply by 100 to accommodate decimals
    //     // uint64 result = (_num * uint64(aux_perc)) / 1000000; // chatGPT equation
    //     // return result; // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)

    //     // NOTE: more efficient with no local vars allocated
    //     return (_num * uint64(uint32(_perc) * 100)) / 1000000; // chatGPT equation
    // }
    // function _uint64_from_uint256(uint256 value) private pure returns (uint64) {
    //     require(value <= type(uint64).max, "Value exceeds uint64 range");
    //     uint64 convertedValue = uint64(value);
    //     return convertedValue;
    // }
    // function _addAddressToArraySafe(address _addr, address[] memory _arr, bool _safe) private pure returns (address[] memory) {
    //     if (_addr == address(0)) { return _arr; }

    //     // safe = remove first (no duplicates)
    //     if (_safe) { _arr = _remAddressFromArray(_addr, _arr); }

    //     // perform add to memory array type w/ static size
    //     address[] memory _ret = new address[](_arr.length+1);
    //     for (uint i=0; i < _arr.length;) { _ret[i] = _arr[i]; unchecked {i++;}}
    //     _ret[_ret.length-1] = _addr;
    //     return _ret;
    // }
    // function _remAddressFromArray(address _addr, address[] memory _arr) private pure returns (address[] memory) {
    //     if (_addr == address(0) || _arr.length == 0) { return _arr; }
        
    //     // NOTE: remove algorithm does NOT maintain order & only removes first occurance
    //     for (uint i = 0; i < _arr.length;) {
    //         if (_addr == _arr[i]) {
    //             _arr[i] = _arr[_arr.length - 1];
    //             assembly { // reduce memory _arr length by 1 (simulate pop)
    //                 mstore(_arr, sub(mload(_arr), 1))
    //             }
    //             return _arr;
    //         }

    //         unchecked {i++;}
    //     }
    //     return _arr;
    // }
    // function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) private pure returns (uint256) {
    //     require(_fromDecimals > 0 && _toDecimals > 0, 'err: invalid _from|toDecimals');
    //     if (_usdAmnt == 0) return _usdAmnt; // fix to allow 0 _usdAmnt (ie. no need to normalize)
    //     if (_fromDecimals == _toDecimals) {
    //         return _usdAmnt;
    //     } else {
    //         if (_fromDecimals > _toDecimals) { // _fromDecimals has more 0's
    //             uint256 scalingFactor = 10 ** (_fromDecimals - _toDecimals); // get the diff
    //             return _usdAmnt / scalingFactor; // decrease # of 0's in _usdAmnt
    //         }
    //         else { // _fromDecimals has less 0's
    //             uint256 scalingFactor = 10 ** (_toDecimals - _fromDecimals); // get the diff
    //             return _usdAmnt * scalingFactor; // increase # of 0's in _usdAmnt
    //         }
    //     }
    // }

    // /* -------------------------------------------------------- */
    // /* PUBLIC - DEX QUOTE SUPPORT (ICallitLib)
    // /* -------------------------------------------------------- */
    // function _getAmountsForInitLP(uint256 _usdAmntLP, uint256 _resultOptionCnt, uint32 _tokPerUsd) private view returns(uint64, uint256) {
    //     require (_usdAmntLP > 0 && _resultOptionCnt > 0 && _tokPerUsd > 0, ' uint == 0 :{} ');
    //     return (CALLIT_LIB._uint64_from_uint256(_usdAmntLP / _resultOptionCnt), uint256((_usdAmntLP / _resultOptionCnt) * _tokPerUsd));
    // }
    // function _calculateTokensToMint(address _pairAddr, uint256 _usdTargetPrice) private view returns (uint256) {
    //     // NOTE: _usdTargetPrice should already be normalized/matched to decimals of reserve1 in _pairAddress

    //     // Assuming reserve0 is token and reserve1 is USD
    //     (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();

    //     uint256 usdCurrentPrice = uint256(reserve1) * 1e18 / uint256(reserve0);
    //     require(_usdTargetPrice < usdCurrentPrice, "Target price must be less than current price.");

    //     // Calculate the amount of tokens to mint
    //     uint256 tokensToMint = (uint256(reserve1) * 1e18 / _usdTargetPrice) - uint256(reserve0);

    //     return tokensToMint;
    // }
    // // Option 1: Estimate the price using reserves
    // // function _estimateLastPriceForTCK(address _pairAddress, address _pairStable) private view returns (uint256) {
    // function _estimateLastPriceForTCK(address _pairAddress) private view returns (uint256) {
    //     (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(_pairAddress).getReserves();
        
    //     // Assuming token0 is the ERC20 token and token1 is the paired asset (e.g., ETH or a stablecoin)
    //     uint256 price = reserve1 * 1e18 / reserve0; // 1e18 for consistent decimals if token1 is ETH or a stablecoin
        
    //     // convert to contract '_usd_decimals()'
    //     // uint64 price_ret = CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_pairStable], price, _usd_decimals()));
    //     // return price_ret;
    //     return price;
    // }
    // // specify router to use
    // function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) private returns (uint256) {
    //     // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
    //     require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
    //     uint256 tok_amnt_out = CALLIT_LIB._swap_v2_wrap(_tok_stab_path, _router, _tokAmnt, _receiver, false); // true = fromETH
    //     return tok_amnt_out;
    // }
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
    //         (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
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
    //         (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
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
    // function _swap_v2_quote(address[] memory _path, address _dexRouter, uint256 _amntIn) private view returns (uint256) {
    //     uint256[] memory amountsOut = IUniswapV2Router02(_dexRouter).getAmountsOut(_amntIn, _path); // quote swap
    //     return amountsOut[amountsOut.length -1];
    // }
    // // uniwswap v2 protocol based: get quote and execute swap
    // function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) private returns (uint256) {
    //     require(path.length >= 2, 'err: path.length :/');
    //     uint256 amntOutQuote = _swap_v2_quote(path, router, amntIn);
    //     uint256 amntOut = _swap_v2(router, path, amntIn, amntOutQuote, outReceiver, fromETH); // approve & execute swap
                
    //     // verifiy new balance of token received
    //     uint256 new_bal = IERC20(path[path.length -1]).balanceOf(outReceiver);
    //     require(new_bal >= amntOut, " _swap: receiver bal too low :{ ");
        
    //     return amntOut;
    // }
    // // v2: solidlycom, kyberswap, pancakeswap, sushiswap, uniswap v2, pulsex v1|v2, 9inch
    // function _swap_v2(address router, address[] memory path, uint256 amntIn, uint256 amntOutMin, address outReceiver, bool fromETH) private returns (uint256) {
    //     IUniswapV2Router02 swapRouter = IUniswapV2Router02(router);
        
    //     IERC20(address(path[0])).approve(address(swapRouter), amntIn);
    //     uint deadline = block.timestamp + 300;
    //     uint[] memory amntOut;
    //     if (fromETH) {
    //         amntOut = swapRouter.swapExactETHForTokens{value: amntIn}(
    //                         amntOutMin,
    //                         path, //address[] calldata path,
    //                         outReceiver, // to
    //                         deadline
    //                     );
    //     } else {
    //         amntOut = swapRouter.swapExactTokensForTokens(
    //                         amntIn,
    //                         amntOutMin,
    //                         path, //address[] calldata path,
    //                         outReceiver, //  The address that will receive the output tokens after the swap. 
    //                         deadline
    //                     );
    //     }
    //     return uint256(amntOut[amntOut.length - 1]); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
    // }
}
