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

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/utils/Strings.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

// import "./SwapDelegate.sol";
import "./CallitTicket.sol";

interface ISwapDelegate { // (legacy)
    function VERSION() external view returns (uint8);
    function USER_INIT() external view returns (bool);
    function USER() external view returns (address);
    function USER_maintenance(uint256 _tokAmnt, address _token) external;
    function USER_setUser(address _newUser) external;
    function USER_burnToken(address _token, uint256 _tokAmnt) external;
}

// contract LUSDShareToken is ERC20, Ownable { // (legacy)
contract CallitFactory is ERC20, Ownable {
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    // NOTE: SWAPD will only work with 1 contract at a time (ie. it checks for a 'USER')
    //  SWAPD needed for LUSDst integration, in '_exeBstPayout', if 'ENABLE_MARKET_BUY'
    //  SWAPD also needed for delegate burning in '_exeTokBuyBurn', if '!_selAuxPay'
    //    (to leave opp available for native pLUSDT contract burning w/ totalSupply())
    ISwapDelegate private SWAPD;
    address private constant SWAP_DELEGATE_INIT = address(0xA8d96d0c328dEc068Db7A7Ba6BFCdd30DCe7C254); // v5 (052924)
    address private SWAP_DELEGATE = SWAP_DELEGATE_INIT;

    /* -------------------------------------------------------- */
    /* LUSDst additions (legacy)
    /* -------------------------------------------------------- */
    bool public ENABLE_TOK_BURN_LOCK;
    bool public ENABLE_BURN_DELEGATE;
    bool public ENABLE_AUX_PAY;
    address public TOK_BURN_LOCK;
    address public TOK_pLUSD = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);

    /* -------------------------------------------------------- */
    /* GLOBALS (legacy)
    /* -------------------------------------------------------- */
    /* _ TOKEN INIT SUPPORT _ */
    string public tVERSION = '1.1';
    string private TOK_SYMB = string(abi.encodePacked("tLUSDst", tVERSION));
    string private TOK_NAME = string(abi.encodePacked("tLUSDst_", tVERSION));

    // TG @Nicoleoracle: "LUSDST for LUSD share token. We can start the token at  seven zero five. We can discuss this more"
    // string private TOK_SYMB = "LUSDST";
    // string private TOK_NAME = "LUSDShareToken";

    /* _ ADMIN SUPPORT _ */
    address public KEEPER;
    uint256 private KEEPER_CHECK;
    // bool private ENABLE_MARKET_QUOTE; // set BST pay & burn val w/ market quote (else 1:1)
    bool private ENABLE_MARKET_BUY; // cover BST pay & burn val w/ market buy (else use holdings & mint)
    // bool private ENABLE_AUX_BURN;
    uint32 private PERC_SERVICE_FEE; // 0 = 0.00%, 505 = 5.05%, 2505 = 25.05%, 10000 = 100.00%
    // uint32 private PERC_BST_BURN;
    uint32 private PERC_AUX_BURN;
    // uint32 private PERC_BUY_BACK_FEE;

    // SUMMARY: controlling how much USD to payout (usdBuyBackVal), effecting profits & demand to trade-in
    // SUMMARY: controlling how much BST to payout (bstPayout), effecting profits & demand on the open market
    uint32 private RATIO_BST_PAYOUT = 10000; // default 10000 _ ie. 100.00% (bstPayout:usdPayout -> 1:1 USD)
    uint32 private RATIO_USD_PAYOUT = 10000; // default 10000 _ ie. 100.00% (usdBuyBackVal:_bstAmnt -> 1:1 BST)
    
    /* _ ACCOUNT SUPPORT _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    address[] private ACCOUNTS;
    mapping(address => uint64) public ACCT_USD_BALANCES; 
    mapping(address => ACCT_PAYOUT[]) public ACCT_USD_PAYOUTS;

    address[] public USWAP_V2_ROUTERS;
    address[] private WHITELIST_USD_STABLES;
    address[] private USD_STABLES_HISTORY;
    mapping(address => uint8) public USD_STABLE_DECIMALS;
    mapping(address => address[]) private USD_BST_PATHS;

    /* -------------------------------------------------------- */
    /* STRUCTS (legacy)
    /* -------------------------------------------------------- */
    struct ACCT_PAYOUT {
        address receiver;
        uint64 usdAmntDebit; // USD total ACCT deduction
        uint64 usdPayout; // USD payout value
        // uint64 bstPayout; // BST payout amount
        uint256 bstPayout; // BST payout amount
        uint64 usdFeeVal; // USD service fee amount
        uint64 usdBurnValTot; // to USD value burned (BST + aux token)
        uint64 usdBurnVal; // BST burned in USD value
        uint256 auxUsdBurnVal; // aux token burned in USD val during payout
        address auxTok; // aux token burned during payout
        uint32 ratioBstPay; // rate at which BST was paid (1<:1 USD)
        uint256 blockNumber; // current block number of this payout
    }

    /* -------------------------------------------------------- */
    /* EVENTS - LUSDST (legacy)
    /* -------------------------------------------------------- */
    event EnableLegacyUpdated(bool _prev, bool _new);
    event SetTokenBurnLock(address _prev_tok, bool _prev_lock_stat, address _new_tok, bool _new_lock_stat);
    event SetEnableBurnDelegate(bool _prev, bool _new);
    event SetEnableAuxPay(bool _prev, bool _new);

    /* -------------------------------------------------------- */
    /* EVENTS (legacy)
    /* -------------------------------------------------------- */
    event KeeperTransfer(address _prev, address _new);
    event TokenNameSymbolUpdated(string TOK_NAME, string TOK_SYMB);
    event SwapDelegateUpdated(address _prev, address _new);
    event SwapDelegateUserUpdated(address _prev, address _new);
    event TradeInFeePercUpdated(uint32 _prev, uint32 _new);
    event PayoutPercsUpdated(uint32 _prev_0, uint32 _prev_1, uint32 _prev_2, uint32 _new_0, uint32 _new_1, uint32 _new_2);
    event DexExecutionsUpdated(bool _prev_0, bool _prev_1, bool _prev_2, bool _new_0, bool _new_1, bool _new_2);
    event DepositReceived(address _account, uint256 _plsDeposit, uint64 _stableConvert);
    // event PayOutProcessed(address _from, address _to, uint64 _usdAmnt, uint64 _usdAmntPaid, uint64 _bstPayout, uint64 _usdFee, uint64 _usdBurnValTot, uint64 _usdBurnVal, uint64 _usdAuxBurnVal, address _auxToken, uint32 _ratioBstPay, uint256 _blockNumber);
    event PayOutProcessed(address _from, address _to, uint64 _usdAmnt, uint64 _usdAmntPaid, uint256 _bstPayout, uint64 _usdFee, uint64 _usdBurnValTot, uint64 _usdBurnVal, uint64 _usdAuxBurnVal, address _auxToken, uint32 _ratioBstPay, uint256 _blockNumber);
    event TradeInFailed(address _trader, uint64 _bstAmnt, uint64 _usdTradeVal);
    event TradeInDenied(address _trader, uint64 _bstAmnt, uint64 _usdTradeVal);
    event TradeInProcessed(address _trader, uint64 _bstAmnt, uint64 _usdTradeVal, uint64 _usdBuyBackVal, uint32 _ratioUsdPay, uint256 _blockNumber);
    event WhitelistStableUpdated(address _usdStable, uint8 _decimals, bool _add);
    event DexRouterUpdated(address _router, bool _add);
    event DexUsdBstPathUpdated(address _usdStable, address[] _path);
    event BuyAndBurnExecuted(address _burnTok, uint256 _burnAmnt);

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR (legacy)
    /* -------------------------------------------------------- */
    // NOTE: sets msg.sender to '_owner' ('Ownable' maintained)
    constructor(uint256 _initSupply) ERC20(TOK_NAME, TOK_SYMB) Ownable(msg.sender) {
        // set default globals (LUSDst additions)
        TOK_BURN_LOCK = address(TOK_pLUSD);
        ENABLE_TOK_BURN_LOCK = true; // deploy w/ ENABLED burn lock to pLUSD
        ENABLE_BURN_DELEGATE = true; // deploy w/ ENABLED using SWAPD to burn
        ENABLE_AUX_PAY = false; // deploy w/ DISABLED option to payout instead of burn
        
        // set default globals
        ENABLE_MARKET_BUY = false;
        PERC_SERVICE_FEE = 1000;  // 10.00% of _usdValue (in payOutBST) for service fee
        PERC_AUX_BURN = 9000; // 90.00% of _usdValue (in payOutBST) for pLUSD buy&burn
        KEEPER = msg.sender;
        KEEPER_CHECK = 0;
        _mint(msg.sender, _initSupply * 10**uint8(decimals())); // 'emit Transfer'

        // init 'ISwapDelegate' & set 'SWAP_DELEGATE' & set SWAPD init USER
        //  to fascilitate contract buying its own contract token
        _setSwapDelegate(SWAP_DELEGATE_INIT);

        // add default routers: pulsex (x2)
        _editDexRouters(address(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02), true); // pulseX v1, true = add
        // _editDexRouters(address(0x165C3410fC91EF562C50559f7d2289fEbed552d9), true); // pulseX v2, true = add

        // add default stables & default USD_BST_PATHS (routing through WPLS required)
        address[] memory path = new address[](3);
        // address usdStable_0 = address(0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f); // weUSDT
        // path[0] = usdStable_0;
        // path[1] = TOK_WPLS;
        // path[2] = address(this);
        // _editWhitelistStables(usdStable_0, 6, true); // weDAI, decs, true = add
        // _setUsdBstPath(usdStable_0, path);

        address usdStable_1 = address(0xefD766cCb38EaF1dfd701853BFCe31359239F305); // weDAI
        path[0] = usdStable_1;
        path[1] = TOK_WPLS;
        path[2] = address(this);
        _setUsdBstPath(usdStable_1, path);
        _editWhitelistStables(usdStable_1, 18, true); // weDAI, decs, true = add
        
            // KEEPER_setUsdBstPath(address _usdStable, address[] memory _path)
            // > 0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f [0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f,0xA1077a294dDE1B09bB078844df40758a5D0f9a27,address(this)]
            // > 0xefD766cCb38EaF1dfd701853BFCe31359239F305 [0xefD766cCb38EaF1dfd701853BFCe31359239F305,0xA1077a294dDE1B09bB078844df40758a5D0f9a27,address(this)]
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS (legacy)
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == KEEPER, "!keeper :p");
        _;
    }
    
    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER SUPPORT (legacy)
    /* -------------------------------------------------------- */
    function KEEPER_setEnableAuxPay(bool _enable) external onlyKeeper() {
        bool prev = ENABLE_AUX_PAY;
        ENABLE_AUX_PAY = _enable;
        emit SetEnableAuxPay(prev, ENABLE_AUX_PAY);
    }
    function KEEPER_setEnableBurnDelegate(bool _enable) external onlyKeeper() {
        bool prev = ENABLE_BURN_DELEGATE;
        ENABLE_BURN_DELEGATE = _enable;
        emit SetEnableBurnDelegate(prev, ENABLE_BURN_DELEGATE);
    }
    
    // NOTE: if _lock = false, this means that ENABLE_TOK_BURN_LOCK
    //  will ultimately be turned off and always use '_auxToken' in 'payOutBST'
    function KEEPER_setTokenBurnLock(address _token, bool _lock) external onlyKeeper() {
        require(_token != address(0), ' 0 address ');
        address prev_tok = TOK_BURN_LOCK;
        bool prev_lock = ENABLE_TOK_BURN_LOCK;
        TOK_BURN_LOCK = _token;
        ENABLE_TOK_BURN_LOCK = _lock;
        emit SetTokenBurnLock(prev_tok, prev_lock, TOK_BURN_LOCK, ENABLE_TOK_BURN_LOCK);
    }
    //  NOTE: _tokAmnt must be in uint precision to _tokAddr.decimals()
    function KEEPER_maintenance(address _tokAddr, uint256 _tokAmnt) external onlyKeeper() {
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
    function KEEPER_setSwapDelegate(address _swapd) external onlyKeeper() {
        require(_swapd != address(0), ' 0 address ;0 ');
        _setSwapDelegate(_swapd); // emits 'SwapDelegateUpdated'
    }
    function KEEPER_setSwapDelegateUser(address _newUser) external onlyKeeper() {
        address prev = SWAPD.USER();
        SWAPD.USER_setUser(_newUser);
        emit SwapDelegateUserUpdated(prev, SWAPD.USER());
    }
    function KEEPER_setPayoutPercs(uint32 _servFee, uint32 _bstBurn, uint32 _auxBurn) external onlyKeeper() {
        require(_servFee + _bstBurn + _auxBurn <= 10000, ' total percs > 100.00% ;) ');
        uint32 prev_0 = PERC_SERVICE_FEE;
        // uint32 prev_1 = PERC_BST_BURN;
        uint32 prev_2 = PERC_AUX_BURN;
        PERC_SERVICE_FEE = _servFee;
        // PERC_BST_BURN = _bstBurn;
        PERC_AUX_BURN = _auxBurn;
        // emit PayoutPercsUpdated(prev_0, prev_1, prev_2, PERC_SERVICE_FEE, PERC_BST_BURN, PERC_AUX_BURN);
        emit PayoutPercsUpdated(prev_0, 0, prev_2, PERC_SERVICE_FEE, 0, PERC_AUX_BURN);
    }
    function KEEPER_setDexOptions(bool _marketQuote, bool _marketBuy, bool _auxTokenBurn) external onlyKeeper() {
        // NOTE: some functions still indeed get quotes from dexes without this being enabled
        // require(_marketQuote || (!_marketBuy), ' invalid input combo :{=} ');
        // bool prev_0 = ENABLE_MARKET_QUOTE;
        bool prev_1 = ENABLE_MARKET_BUY;
        // bool prev_2 = ENABLE_AUX_BURN;

        // ENABLE_MARKET_QUOTE = _marketQuote;    
        ENABLE_MARKET_BUY = _marketBuy;
        // ENABLE_AUX_BURN = _auxTokenBurn;
        
        emit DexExecutionsUpdated(false, prev_1, false, false, ENABLE_MARKET_BUY, false);
    }
    function KEEPER_editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) external onlyKeeper {
        require(_usdStable != address(0), 'err: 0 address');
        _editWhitelistStables(_usdStable, _decimals, _add);
        emit WhitelistStableUpdated(_usdStable, _decimals, _add);
    }
    function KEEPER_editDexRouters(address _router, bool _add) external onlyKeeper {
        require(_router != address(0x0), "0 address");
        _editDexRouters(_router, _add);
        emit DexRouterUpdated(_router, _add);
    }
    function KEEPER_setUsdBstPath(address _usdStable, address[] memory _path) external onlyKeeper() {
        require(_usdStable != address(0) && _path.length > 1, ' invalid inputs :{=} ');
        require(_usdStable == _path[0], ' stable / entry path mismatch =)');
        _setUsdBstPath(_usdStable, _path);
        // NOTE: '_path' must be valid within all 'USWAP_V2_ROUTERS' addresses
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER - ACCESSORS (legacy)
    /* -------------------------------------------------------- */
    function KEEPER_collectiveStableBalances(bool _history, uint256 _keeperCheck) external view onlyKeeper() returns (uint64, uint64, int64, uint256) {
        require(_keeperCheck == KEEPER_CHECK, ' KEEPER_CHECK failed :( ');
        if (_history)
            return _collectiveStableBalances(USD_STABLES_HISTORY);
        return _collectiveStableBalances(WHITELIST_USD_STABLES);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS (legacy)
    /* -------------------------------------------------------- */
    function getAccounts() external view returns (address[] memory) {
        return ACCOUNTS;
    }
    function getAccountPayouts(address _account) external view returns (ACCT_PAYOUT[] memory) {
        require(_account != address(0), ' 0 address? ;[+] ');
        return ACCT_USD_PAYOUTS[_account];
    }
    function getDexOptions() external view returns (bool, bool, bool) {
        return (false, ENABLE_MARKET_BUY, false);
    }
    function getPayoutPercs() external view returns (uint32, uint32, uint32, uint32) {
        // return (PERC_SERVICE_FEE, PERC_BST_BURN, PERC_AUX_BURN, PERC_BUY_BACK_FEE);
        return (PERC_SERVICE_FEE, 0, PERC_AUX_BURN, 0);
    }
    function getUsdBstPath(address _usdStable) external view returns (address[] memory) {
        return USD_BST_PATHS[_usdStable];
    }    
    function getUsdStablesHistory() external view returns (address[] memory) {
        return USD_STABLES_HISTORY;
    }    
    function getWhitelistStables() external view returns (address[] memory) {
        return WHITELIST_USD_STABLES;
    }
    function getDexRouters() external view returns (address[] memory) {
        return USWAP_V2_ROUTERS;
    }
    function getSwapDelegateInfo() external view returns (address, uint8, address) {
        return (SWAP_DELEGATE, SWAPD.VERSION(), SWAPD.USER());
    }

    /* -------------------------------------------------------- */
    /* GLOBALS (CALLIT)
    /* -------------------------------------------------------- */
    uint64 public TOK_TICK_INIT_SUPPLY = 1000000; // init supply used for new call ticket tokens (uint64 = ~18,000Q max)
    string public TOK_TICK_NAME_SEED = "TCK#";
    string public TOK_TICK_SYMB_SEED = "CALL-TICKET";
    uint16 MAX_RESULTS = 100; // ADMIN: max # of result options a market may have
    uint8 MIN_HANDLE_SIZE = 1; // ADMIN: min # of chars for account handles
    uint8 MAX_HANDLE_SIZE = 25; // ADMIN: max # of chars for account handles
    uint64 MIN_USD_PROMO_TARGET = 100; // ADMIN: min $ target for creating promo codes
    uint64 USD_BUY_PROMO_PER_CALL = 100; // usd amount buy needed per $CALL earned in promo (note: global across all promos to avoid exploitations)
    
    mapping(address => bool) public ADMINS; // enable/disable admins (for promo support, etc)
    mapping(address => string) public ACCT_HANDLES; // market creators (etc.) can set their own handles
    mapping(address => MARKET[]) public ACCT_MARKETS; // store all markets people create
    mapping(address => ACCT_PROMO[]) public PROMO_CODE_HASHES; // store promo code hashes for EOA accounts

    /* -------------------------------------------------------- */
    /* EVENTS (CALLIT)
    /* -------------------------------------------------------- */
    event MarketCreated(address _creator, uint32 _markNum, string _name, string _category, string _rules, string _imgUrl, uint64 _usdAmntLP, uint256 _dtEnd, string[] _resultLabels, string[] _resultDescrs, address[] _resultOptionTokens, address[] _resultTokenLPs, uint256 _blockNumber, bool _live);
    event PromoCreated(address _promoHash, address _promotor, string _promoCode, uint64 _usdTarget, uint64 usdUsed, uint8 _percReward, address _creator, uint256 _blockNumber);
    event PromoRewardPaid(address _promoCodeHash, uint64 _usdRewardPaid, address _promotor, address _buyer, address _ticket);
    event PromoBuyPerformed(address _buyer, address _ticket, address _promoCodeHash, uint64 _grossUsdAmnt, uint64 _netUsdAmnt);

    /* -------------------------------------------------------- */
    /* STRUCTS (CALLIT)
    /* -------------------------------------------------------- */
    struct ACCT_PROMO {
        address promotor; // influencer wallet this promo is for
        string promoCode;
        uint64 usdTarget; // usd amount this promo is good for
        uint64 usdUsed; // usd amount this promo has used so far
        uint8 percReward; // % of caller buys rewarded
        address adminCreator; // admin who created this promo
        uint256 blockNumber; // block number this promo was created
    }

    struct MARKET {
        address creator; // EOA creator
        uint32 marketNum; // used incrementally for MARKET[] in ACCT_MARKETS
        string name; // display name for this market (maybe auto-generate w/ )
        string category;
        string rules;
        string imgUrl;
        uint64 usdAmntLP;
        uint256 dtEndCalls; // unix timestamp 1970, no more bets, LP removed from generated DEXs
        string[] resultLabels; // required: length == _resultDescrs
        string[] resultDescrs; // required: length == _resultLabels
        address[] resultOptionTokens; // required: length == _resultLabels == _resultDescrs
        address[] resultTokenLPs; // // required: length == _resultLabels == _resultDescrs == resultOptionTokens
        uint256 blockNumber; // block number this market was created
        bool live;
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS (CALLIT)
    /* -------------------------------------------------------- */
    modifier onlyAdmin() {
        require(msg.sender == KEEPER || ADMINS[msg.sender] == true, " !admin :p");
        _;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER MUTATORS (CALLIT)
    /* -------------------------------------------------------- */
    function KEEPER_editAdmin(address _admin, bool _enable) external onlyKeeper {
        require(_admin != address(0), ' !_admin :{+} ');
        ADMINS[_admin] = _enable;
    }
    function KEEPER_setMaxMarketResultOptions(uint16 _optionCnt) external onlyKeeper {
        MAX_RESULTS = _optionCnt; // max # of result options a market may have
    }
    function KEEPER_setMinMaxAcctHandleSize(uint8 _min, uint _max) external onlyKeeper {
        MIN_HANDLE_SIZE = _min; // min # of chars for account handles
        MAX_HANDLE_SIZE = _max; // max # of chars for account handles
    }
    function KEEPER_setMinUsdPromoTarget(uint64 _usdTarget) external onlyKeeper {
        MIN_USD_PROMO_TARGET = _usdTarget;
    }
    function KEEPER_setUsdPromoBuyReqPerCall(uint64 _usdBuyRequired) external onlyKeepr {
        USD_BUY_PROMO_PER_CALL = _usdBuyRequired;
    }
    function KEEPER_setTokTicketNameSymbSeeds(string calldata _nameSeed, string calldata _symbSeed) external onlyKeeper {
        TOK_TICK_NAME_SEED = _nameSeed;
        TOK_TICK_SYMB_SEED = _symbSeed;
    }
    function KEEPER_setTokTickInitSupply(uint64 _initSupply) external onlyKeeper {
        TOK_TICK_INIT_SUPPLY = _initSupply; // NOTE: uint64 max = ~18,000Q
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - ADMIN MUTATORS (CALLIT)
    /* -------------------------------------------------------- */
    function ADMIN_initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward) external onlyAdmin {
        require(_promotor != address(0) && _validNonWhiteSpaceString(_promoCode) && _usdTarget >= MIN_USD_PROMO_TARGET, ' !param(s) :={ ');
        address promoCodeHash = _generateAddressHash(_promotor, _promoCode);
        ACCT_PROMO storage promo = PROMO_CODE_HASHES[promoCodeHash];
        require(promo.promotor == address(0), ' promo already exists :-O ');
        PROMO_CODE_HASHES[promoCodeHash].push(ACCT_PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number));
        emit PromoCreated(promoCodeHash, _promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS (CALLIT)
    /* -------------------------------------------------------- */

    /* -------------------------------------------------------- */
    /* PUBLIC - MUTATORS (CALLIT)
    /* -------------------------------------------------------- */
    function setMyAcctHandle(string _handle) external {
        require(_hanlde.length >= MIN_HANDLE_SIZE && _hanlde.length <= MAX_HANDLE_SIZE, ' !_handle.length :[] ');
        require(bytes(_handle)[0] != 0x20, ' !_handle space start :+[ '); // 0x20 -> ASCII for ' ' (single space)
        if (_validNonWhiteSpaceString(_handle))
            ACCT_HANDLES[msg.sender] = _handle;
        else
            revert(' !blank space handles :-[=] ');        
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - USER INTERFACE (CALLIT)
    /* -------------------------------------------------------- */
    function createMarket(string calldata _name, string calldata _category, string calldata _rules, string calldata _imgUrl, uint64 _usdAmntLP, uint256 _dtEndCalls, string[] calldata _resultLabels, string[] calldata _resultDescrs) external { 
        require(ACCT_USD_BALANCES[msg.sender] >= _usdAmntLP, ' low balance ;{ ');
        require(2 <= _resultLabels.length && _resultLabels.length <= MAX_RESULTS && _resultLabels.length == _resultDescrs.length, ' bad result count :( ');

        // initilize arrays and market number for struct MARKET tracking
        address[] memory resultOptionTokens = new address[](_resultLabels.length);
        address[] memory resultTokenLPs = new address[](_resultLabels.length);
        uint32 mark_num = ACCT_MARKETS[msg.sender].length;

        // Loop through _resultLabels and deploy ERC20s for each (and generate LP)
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS = uint64 type
            // Deploy a new ERC20 token for each result label
            (string memory tok_name, string memory tok_symb) = _genTokenNameSymbol(_creator, mark_num, _resultNum);
            address new_tick_tok = address (new CallitTicket(TOK_TICK_INIT_SUPPLY, tok_name, tok_symb));
            resultOptionTokens[i] = new_tick_tok;

            // Get amounts for initial LP & Create DEX LP for the token
            (uint64 usdAmount, uint256 tokenAmount) = _getAmountsForInitLP(_usdAmntLP, _resultLabels.length);
            address lpAddress = _createDexLP(new_tick_tok, usdAmount, tokenAmount);
            resultTokenLPs[i] = lpAddress;
            require(new_tick_tok != address(0) && lpAddress != address(0), ' err: gen tick tok | lp :( ');
            unchecked {i++;}
        }

        // save this market and emit log
        ACCT_MARKETS[msg.sender].push(MARKET(msg.sender, mark_num, _name, _category, _rules, _imgUrl, _usdAmntLP, _dtEndCalls, _resultLabels, _resultDescrs, resultOptionTokens, resultTokenLPs, block.number, true)); // true = live
        emit MarketCreated(msg.sender, mark_num, _name, _category, _rules, _imgUrl, _usdAmntLP, _dtEndCalls, _resultLabels, _resultDescrs, resultOptionTokens, resultTokenLPs, block.number, true); // true = live
    }

    function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt) external {
        ACCT_PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        require(promo.usdTarget - promo.usdUsed >= _usdAmnt, ' promo expired :( ' );
        require(ACCT_USD_BALANCES[msg.sender] >= _usdAmnt, ' low balance ;{ ');

        // Get stable to work with ...
        //  NOTE: if no single stable can cover '_usdAmnt', lowStableHeld == 0x0, 
        address lowStableHeld = _getStableHeldLowMarketValue(_usdAmnt, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        require(lowStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in ACCT_PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        
        // check if msg.sender earned $CALL tokens
        if (_usdAmnt >= USD_BUY_PROMO_PER_CALL) {
            // mint $CALL to msg.sender
            _mint(msg.sender, _usdAmnt / USD_BUY_PROMO_PER_CALL);
        }

        // calc influencer reward from _usdAmnt & send to promo.promotor
        uint64 usdReward = promo.percReward * _usdAmnt;
        IERC20(lowStableHeld).transfer(promo.promotor, usdReward);
        emit PromoRewardPaid(_promoCodeHash, usdReward, promo.promotor, msg.sender, _ticket);
            // LEFT OFF HERE ... need to validate decimals for lowStableHeld and usdReward

        // deduct usdReward & additional fees from _usdAmnt
        uint64 net_usdAmnt = _usdAmnt - usdReward;
        net_usdAmnt = _deductPromoBuyFees(net_usdAmnt, _usdAmnt);
            // LEF OFF HERE ... finish _deductPromoBuyFees integration

        // use remaining net_usdAmnt to buy _ticket from DEX (_ticket receiver = msg.sender)
        // NOTE: accounts for contracts unable to be a receiver of its own token in UniswapV2Pool.sol
        //  auto-sets receiver to SWAP_DELEGATE & transfers tokens from SWAP_DELEGATE
        address[2] memory usd_tick_path = [lowStableHeld, _ticket]; // ref: https://ethereum.stackexchange.com/a/28048
        uint256 tick_amnt_out = _exeSwapStableForTok(net_usdAmnt, usd_tick_path, msg.sender); // msg.sender = _receiver

        // deduct _usdAmnt from account balance
        ACCT_USD_BALANCES[msg.sender] -= _usdAmnt;

        // update promo.usdUsed (add _usdAmnt)
        promo.usdUsed += _usdAmnt;

        // emit log
        emit PromoBuyPerformed(msg.sender, _ticket, _promoCodeHash, _usdAmnt, net_usdAmnt);
    }
    function checkPromoBalance(address _promoCodeHash) external returns(uint64) {
        ACCT_PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        return promo.usdTarget - promo.usdUsed;
    }

    // function buyMintedCallTicket(address _creator, address _ticket, uint32 _ticketCount) external returns(uint64) {
    function exeArbPriceParityForTicket(address _creator, address _ticket) external {
        // TODO: loop through markets in ACCT_MARKETS[_creator]
        //  find market with _ticket in 'resultOptionTokens'
        //  check if current dt < market._dtEndCalls
        //   if yes, 
        //      use '_getCallTicketUsdTargetPrice' to get target price for _ticket price parity 
        //      use '_getMarketForTicket' to get LP pair addresss for _ticket
        //      use '_calculateTokensToMint(target price, pair address)' to get _ticket mint count for DEX sell to bring _ticket to price parity
        //      verify: ACCT_USD_BALANCES[msg.sender] >= target price * _ticket mint count
        //      deduct balance: ACCT_USD_BALANCES[msg.sender] -= target price * _ticket mint count;
        //      mint _ticket mint count to this factory and sell on DEX on behalf of msg.sender
        //      calc & send profits to msg.sender: gross usd received from sell - (target price * _ticket mint count)
    }

    function endMarketCalls(address _creator, address _anyTicket) external {
        // TODO: loop through markets in ACCT_MARKETS[_creator]
        //  find market with _ticket in 'resultOptionTokens'
        //  check if current dt >= market._dtEndCalls
        //   if yes, pull all LP from this market
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (CALLIT)
    /* -------------------------------------------------------- */
    function _deductPromoBuyFees(uint64 _usdAmnt, uint64 _net_usdAmnt) private returns(uint64){
        uint8 feePerc0; // = global
        uint8 feePerc1; // = global
        uint8 feePerc2; // = global
        uint64 net_usdAmnt = _net_usdAmnt - (feePerc0 * _usdAmnt);
        net_usdAmnt = net_usdAmnt - (feePerc1 * _usdAmnt);
        net_usdAmnt = net_usdAmnt - (feePerc2 * _usdAmnt);
        return net_usdAmnt;
        // LEFT OFF HERE ... need globals for above and need decimal conversion consideration (maybe)
    }
    function _genTokenNameSymbol(address _creator, uint32 _markNum, uint16 _resultNum) private pure returns(string, string) {
        // Convert the address to a string
        string memory addrStr = toAsciiString(_creator);

        // Extract the first 4 characters (excluding the "0x" prefix)
        // string memory first4 = substring(addrStr, 2, 6);
        
        // Extract the last 4 characters using length
        // string memory last4 = substring(addrStr, 38, 42);
        uint len = bytes(addrStr).length;
        string memory last4 = substring(addrStr, len - 4, len);

        // Concatenate to form symbol & name
        // string memory tokenSymbol = string(abi.encodePacked(TOK_TICK_NAME_SEED, last4, _markNum, Strings.toString(_resultNum)));
        // string memory tokenName = string(abi.encodePacked(TOK_TICK_SYMB_SEED, last4, "-", _markNum, "-", Strings.toString(_resultNum)));
        string memory tokenSymbol = string(abi.encodePacked(TOK_TICK_NAME_SEED, last4, _markNum, string(abi.encode(_resultNum))));
        string memory tokenName = string(abi.encodePacked(TOK_TICK_SYMB_SEED, " ", last4, "-", _markNum, "-", string(abi.encode(_resultNum))));

        return (tokenName, tokenSymbol);
    }
    // Assumed helper functions (implementations not shown)
    function _createDexLP(address _token, address _usdStable, uint256 _tokenAmount, uint64 _usdAmount) private returns (address) {
        // LEFT OFF HERE ... _usdStable & _usdAmount must check and convert to use correct decimals
        //          need to properly set & use: uniswapRouter & uniswapFactory

        // Approve tokens for Uniswap Router
        IERC20(_token).safeApprove(address(uniswapRouter), _tokenAmount);
        // Assuming you have a way to convert USD to ETH or a stablecoin in the contract

        // Add liquidity to the pool
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter.addLiquidity(
            _token,                // Token address
            _usdStable,           // Assuming ETH as the second asset (or replace with another token address)
            _tokenAmount,          // Desired _token amount
            _usdAmount,            // Desired ETH amount (converted from USD or directly provided)
            0,                    // Min amount of _token (slippage tolerance)
            0,                    // Min amount of ETH (slippage tolerance)
            address(this),        // Recipient of liquidity tokens
            block.timestamp + 300 // Deadline (5 minutes from now)
        );

        // Return the address of the liquidity pool
        // For Uniswap V2, the LP address is not directly returned but you can obtain it by querying the factory.
        // This example assumes you store or use the liquidity tokens or LP in your contract directly.

        // The actual LP address retrieval would require interaction with Uniswap V2 Factory.
        // For simplicity, we're returning a placeholder.
        // Retrieve the LP address
        address lpAddress = uniswapFactory.getPair(_token, _usdStable);
        return lpAddress;

        // NOTE: LEFT OFF HERE ... may need external support functions for LP & LP token maintence, etc.
        //      similar to accessors that retrieve native and ERC20 tokens held by contract
    }

    function _getAmountsForInitLP(uint64 _usdAmntLP, uint16 _resultOptionCnt) private returns(uint64, uint256) {
        require (_usdAmntLP > 0 && _resultOptionCnt > 0, ' uint == 0 :{} ');
        return (_usdAmntLP / _resultOptionCnt, _getInitDexSupplyForUsdAmnt(_usdAmntLP));
    }
    function _getInitDexSupplyForUsdAmnt(uint64 _usdAmntLP) private returns(uint256) {
        // TODO: need algorithm to specify dex token supply for _usdAmntLP side
        return 0;
    }
    function _validNonWhiteSpaceString(string calldata _s) private pure returns(bool) {
        for (uint8 i=0; i < _s.length;) {
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
    function _generateAddressHash(address host, string memory uid) external pure returns (address) {
        // Concatenate the address and the string, and then hash the result
        bytes32 hash = keccak256(abi.encodePacked(host, uid));

        // LEFT OFF HERE ... is this a bug? 'uint160' ? shoudl be uint16? 
        address generatedAddress = address(uint160(uint256(hash)));
        return generatedAddress;
    }

    function _getMarketForTicket(address _creator, addres_ ticket) private view returns(MARKET) {
        // TODO: loop through markets in ACCT_MARKETS[_creator]
        //  return market with _ticket in 'resultOptionTokens'
    }
    function _getCallTicketUsdTargetPrice(address _creator, address _ticket, uint32 _ticketCount) private view returns(uint64) {
        // NOTE: uint32 max = ~4B -> 4,294,967,295
        // TODO: loop through markets in ACCT_MARKETS[_creator]
        //  find market with _ticket in 'resultOptionTokens'
        //  get current usd value dex prices for all addresses in 'resultOptionTokens'
        //  _ticket price = 1 - SUM(all prices except _ticket)

        return 0;
    }
    function _calculateTokensToMint(address pairAddress, uint targetPrice) external view returns (uint256) {
        // Assuming reserve0 is token and reserve1 is USD
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pairAddress).getReserves();

        uint256 currentPrice = uint256(reserve1) * 1e18 / uint256(reserve0);
        require(targetPrice < currentPrice, "Target price must be less than current price.");

        // Calculate the amount of tokens to mint
        uint256 tokensToMint = (uint256(reserve1) * 1e18 / targetPrice) - uint256(reserve0);

        return tokensToMint;
    }

    // function _calculateTokensToMint( // utilize 'getAmountsIn'
    //     address pairAddress,
    //     address token,
    //     address usdToken,
    //     uint targetPrice
    // ) external view returns (uint256) {
    //     // Assuming reserve0 is token and reserve1 is USD
    //     (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pairAddress).getReserves();

    //     uint256 currentPrice = uint256(reserve1) * 1e18 / uint256(reserve0);
    //     require(targetPrice < currentPrice, "Target price must be less than current price.");

    //     // Calculate the amount of USD in the pool if targetPrice is achieved
    //     uint256 newReserve1 = targetPrice * reserve0 / 1e18;

    //     // Use getAmountsOut to determine how much of the token needs to be sold
    //     uint256 amountOut = reserve1 - newReserve1;

    //     address;
    //     path[0] = token;
    //     path[1] = usdToken;

    //     // This will give us how many tokens need to be swapped to get `amountOut` of USD
    //     uint256[] memory amountsIn = uniswapRouter.getAmountsIn(amountOut, path);

    //     return amountsIn[0];
    // }

    /* -------------------------------------------------------- */
    /* PUBLIC - USER INTERFACE (LUSDST legacy)
    /* -------------------------------------------------------- */
    // handle contract USD value deposits (convert PLS to USD stable)
    receive() external payable {
        // extract PLS value sent
        uint256 amntIn = msg.value; 

        // get whitelisted stable with lowest market value (ie. receive most stable for swap)
        address usdStable = _getStableTokenLowMarketValue(WHITELIST_USD_STABLES, USWAP_V2_ROUTERS);

        // perform swap from PLS to stable
        uint256 stableAmntOut = _exeSwapPlsForStable(amntIn, usdStable); // _normalizeStableAmnt

        // convert and set/update balance for this sender, ACCT_USD_BALANCES stores uint precision to 6 decimals
        uint64 amntConvert = _uint64_from_uint256(stableAmntOut);
        ACCT_USD_BALANCES[msg.sender] += amntConvert;
        ACCOUNTS = _addAddressToArraySafe(msg.sender, ACCOUNTS, true); // true = no dups

        emit DepositReceived(msg.sender, amntIn, amntConvert);
    }
    
    // handle account payouts
    //  NOTE: _usdValue must be in uint precision to address(this) '_usd_decimals()'
    function payOutBST(uint64 _usdValue, address _payTo, address _auxToken, bool _selAuxPay) external {
        // NOTE: payOutBST runs multiple loops embedded (not analyzed yet, but less than BST legacy)        
        //  invokes _getStableHeldLowMarketValue -> _getStableTokenLowMarketValue -> _best_swap_v2_router_idx_quote
        //  invokes _exeTokBuyBurn -> _exeSwapStableForTok -> _best_swap_v2_router_idx_quote
        //  invokes _exeBstPayout -> _exeSwapStableForTok -> _best_swap_v2_router_idx_quote

        // ACCT_USD_BALANCES stores uint precision to 6 decimals
        require(_usdValue > 0, ' 0 _usdValue :[] ');
        require(ACCT_USD_BALANCES[msg.sender] >= _usdValue, ' low acct balance :{} ');
        require(_payTo != address(0), ' _payTo 0 address :( ');

        // calc & remove usd service fee value & pLUSD burn value (in usd)
        uint64 usdFee = _perc_of_uint64(PERC_SERVICE_FEE, _usdValue);
        uint64 usdAuxBurnVal = _perc_of_uint64(PERC_AUX_BURN, _usdValue);
        uint64 usdPayout = _usdValue - usdFee - usdAuxBurnVal; 
            // NOTE: usdPayout not used (ie. if usdPayout != 0, then that amount is simply left in the contract)
        
        // NOTE: integration runs 3 embedded loops 
        //  get whitelist stables with holdings that can cover usdPayout
        //  then choose stable with lowest market value (ie. contract holds high market val stables)
        // NOTE: lowStableHeld could possibly equal address(0x0)
        //  this is indeed ok as '_exeBstPayout' & '_exeTokBuyBurn' checks for this (falls back to mint | reverts)
        address lowStableHeld = _getStableHeldLowMarketValue(usdPayout, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        // address highStableHeld = _getStableHeldHighMarketValue(usdPayout, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded

        // exe buy & burn w/ burnToken
        //  set burnToken to pLUSD or _auxToken (depends on ENABLE_TOK_BURN_LOCK)
        //  generate swap path: USD->burnToken (go through WPLS required)
        //  NOTE: _exeTokBuyBurn reverts if burnToken == address(0) in usd_tok_burn_path
        address burnToken = ENABLE_TOK_BURN_LOCK ? TOK_BURN_LOCK : _auxToken;
        address[] memory usd_tok_burn_path = new address[](3);
        usd_tok_burn_path[0] = lowStableHeld;
        usd_tok_burn_path[1] = TOK_WPLS;
        usd_tok_burn_path[2] = burnToken;
        (uint64 usdBurnValAux, uint256 LUSDstPayoutAmnt) = _exeTokBuyBurn(usdAuxBurnVal, usd_tok_burn_path, _selAuxPay, _payTo);
            
        // mint exactly the 'burnAmnt' (for payout)
        // if ENABLE_MARKET_BUY, pay from market buy
        _exeBstPayout(_payTo, LUSDstPayoutAmnt, usdBurnValAux, lowStableHeld);

        // update account balance, ACCT_USD_BALANCES stores uint precision to 6 decimals
        ACCT_USD_BALANCES[msg.sender] -= _usdValue; // _usdValue 'require' check above

        // log this payout, ACCT_USD_PAYOUTS stores uint precision to 6 decimals
        ACCT_USD_PAYOUTS[msg.sender].push(ACCT_PAYOUT(_payTo, _usdValue, usdPayout, LUSDstPayoutAmnt, usdFee, usdBurnValAux, 0, usdAuxBurnVal, burnToken, RATIO_BST_PAYOUT, block.number));
        emit PayOutProcessed(msg.sender, _payTo, _usdValue, usdPayout, LUSDstPayoutAmnt, usdFee, usdBurnValAux, 0, usdAuxBurnVal, burnToken, RATIO_BST_PAYOUT, block.number);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (legacy)
    /* -------------------------------------------------------- */
    function _setUsdBstPath(address _usdStable, address[] memory _path) private {
        require(_usdStable != address(0) && _path.length > 1, ' invalid inputs ;{=} ');
        require(_usdStable == _path[0], ' stable / entry path mismatch ;) ');
        USD_BST_PATHS[_usdStable] = _path;
        emit DexUsdBstPathUpdated(_usdStable, _path);
        // NOTE: '_path' must be valid within all 'USWAP_V2_ROUTERS' addresses
    }
    function _setSwapDelegate(address _swapd) private {
        require(_swapd != address(0), ' 0 address ;-( ');
        address prev = address(SWAP_DELEGATE);
        SWAP_DELEGATE = _swapd;
        SWAPD = ISwapDelegate(SWAP_DELEGATE);
        if (SWAPD.USER_INIT()) {
            SWAPD.USER_setUser(address(this)); // first call to _setUser can set user w/o keeper
        }
        emit SwapDelegateUpdated(prev, SWAP_DELEGATE);
    }

    function _exeBstPayout(address _payTo, uint256 _bstPayout, uint64 _usdPayout, address _usdStable) private {
        /** ALGORITHMIC LOGIC ...
             if ENABLE_MARKET_BUY, pay BST from market buy
             else, pay with newly minted BST
            *WARNING*:
                if '_exeSwapStableForTok' keeps failing w/ tx reverting
                 then need to edit 'USWAP_V2_ROUTERS' &| 'USD_BST_PATHS' to debug
                 and hopefully not need to disable ENABLE_MARKET_BUY
         */
        bool stableHoldings_OK = _usdPayout > 0 && _stableHoldingsCovered(_usdPayout, _usdStable);
        bool usdBstPath_OK = USD_BST_PATHS[_usdStable].length > 0;
        if (ENABLE_MARKET_BUY && stableHoldings_OK && usdBstPath_OK) {
            // NOTE: accounts for contracts unable to be a receiver of its own token in UniswapV2Pool.sol
            //  and sets receiver to SWAP_DELEGATE, then transfers tokens from SWAP_DELEGATE
            uint256 bst_amnt_out = _exeSwapStableForTok(_usdPayout, USD_BST_PATHS[_usdStable]);
            _transfer(address(this), _payTo, bst_amnt_out); // send bst payout
        } else {
            _mint(_payTo, _bstPayout); // mint bst payout
        }
    }
    function _exeTokBuyBurn(uint64 _usdBurnVal, address[] memory _usdSwapPath, bool _selAuxPay, address _auxPayTo) private returns (uint64, uint256) {
        // validate swap path and not burning 0 (uswap throws execption on 0 amount)
        require(_usdBurnVal != 0 && _usdSwapPath.length > 1 && _usdSwapPath[0] != address(0), ' 0 burn | invalid swap path :{} '); 
        // address usdStable = _usdSwapPath[0];
        address burnToken = _usdSwapPath[_usdSwapPath.length-1];
        require(burnToken != address(0), ' invalid swap path burnToken :[] ');
        // bool stableHoldings_OK = _stableHoldingsCovered(_usdBurnVal, usdStable);
        // bool usdSwapPath_OK = usdStable != address(0) && burnToken != address(0);
        // require(stableHoldings_OK && usdSwapPath_OK, ' !stableHoldings_OK | !usdSwapPath_OK ');
        
        // NOTE: accounts for contracts unable to be a receiver of its own token in UniswapV2Pool.sol
        //  and sets receiver to SWAP_DELEGATE, then transfers tokens from SWAP_DELEGATE
        uint256 burn_tok_amnt_out = _exeSwapStableForTok(_usdBurnVal, _usdSwapPath);
        if (_selAuxPay && ENABLE_AUX_PAY) // check for aux pay (instead of burn)
            IERC20(burnToken).transfer(_auxPayTo, burn_tok_amnt_out);
        else if (ENABLE_BURN_DELEGATE) { // check for using burn delegate (instead of 0x0...369)
            // NOTE: use SWAP_DELEGATE to burn (send to & burn from SWAPD)
            //  allows for potential upgrade for native pLUSD burn solution
            IERC20(burnToken).transfer(SWAP_DELEGATE, burn_tok_amnt_out);
            SWAPD.USER_burnToken(burnToken, burn_tok_amnt_out);
        }
        else {
            // simply send to burn address (0x0...369)
            IERC20(burnToken).transfer(BURN_ADDR, burn_tok_amnt_out);
        }
        emit BuyAndBurnExecuted(burnToken, burn_tok_amnt_out);
        return (_usdBurnVal, burn_tok_amnt_out); // (uint64 usdBurnValAux, uint256 tokBurnAmnt)

            /** ALGORITHMIC LOGIC ... (LEGACY)
                if ENABLE_MARKET_BUY | ENABLE_AUX_BURN, burn token from market buy
                else, nothing burned
                *WARNING*: 
                    if '_exeSwapStableForTok' keeps failing w/ tx reverting
                    then need to edit 'USWAP_V2_ROUTERS' to debug
                    or invoke payOutBST w/ _auxToken=0x0 (if isolated to a specific aux token)
                    and hopefully not need to disable ENABLE_MARKET_BUY &| ENABLE_AUX_BURN 
            */
    }
    function _grossStableBalance(address[] memory _stables) private view returns (uint64) {
        uint64 gross_bal = 0;
        for (uint8 i = 0; i < _stables.length;) {
            // NOTE: more efficient algorithm taking up less stack space with local vars
            require(USD_STABLE_DECIMALS[_stables[i]] > 0, ' found stable with invalid decimals :/ ');
            gross_bal += _uint64_from_uint256(_normalizeStableAmnt(USD_STABLE_DECIMALS[_stables[i]], IERC20(_stables[i]).balanceOf(address(this)), _usd_decimals()));
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
    function _collectiveStableBalances(address[] memory _stables) private view returns (uint64, uint64, int64, uint256) {
        uint64 gross_bal = _grossStableBalance(_stables);
        uint64 owed_bal = _owedStableBalance();
        int64 net_bal = int64(gross_bal) - int64(owed_bal);
        return (gross_bal, owed_bal, net_bal, totalSupply());
    }
    function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) private { // allows duplicates
        if (_add) {
            WHITELIST_USD_STABLES = _addAddressToArraySafe(_usdStable, WHITELIST_USD_STABLES, true); // true = no dups
            USD_STABLES_HISTORY = _addAddressToArraySafe(_usdStable, USD_STABLES_HISTORY, true); // true = no dups
            USD_STABLE_DECIMALS[_usdStable] = _decimals;
        } else {
            WHITELIST_USD_STABLES = _remAddressFromArray(_usdStable, WHITELIST_USD_STABLES);
        }
    }
    function _editDexRouters(address _router, bool _add) private {
        require(_router != address(0x0), "0 address");
        if (_add) {
            USWAP_V2_ROUTERS = _addAddressToArraySafe(_router, USWAP_V2_ROUTERS, true); // true = no dups
        } else {
            USWAP_V2_ROUTERS = _remAddressFromArray(_router, USWAP_V2_ROUTERS); // removes only one & order NOT maintained
        }
    }
    function _getStableHeldHighMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {

        address[] memory _stablesHeld;
        for (uint8 i=0; i < _stables.length;) {
            if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
                _stablesHeld = _addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

            unchecked {
                i++;
            }
        }
        return _getStableTokenHighMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    }
    function _getStableHeldLowMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {
        // NOTE: if nothing in _stables can cover _usdAmntReq, then returns address(0x0)
        address[] memory _stablesHeld;
        for (uint8 i=0; i < _stables.length;) {
            if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
                _stablesHeld = _addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

            unchecked {
                i++;
            }
        }
        return _getStableTokenLowMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    }
    function _stableHoldingsCovered(uint64 _usdAmnt, address _usdStable) private view returns (bool) {
        if (_usdStable == address(0x0)) 
            return false;
        uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
        return IERC20(_usdStable).balanceOf(address(this)) >= usdAmnt_;
    }
    function _getTokMarketValueForUsdAmnt(uint256 _usdAmnt, address _usdStable, address[] memory _stab_tok_path) private view returns (uint256) {
        uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
        (uint8 rtrIdx, uint256 tok_amnt) = _best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);
        return tok_amnt; 
    }
    function _perc_of_uint64(uint32 _perc, uint64 _num) private pure returns (uint64) {
        require(_perc <= 10000, 'err: invalid percent');
        return _perc_of_uint64_unchecked(_perc, _num);
    }
    function _perc_of_uint64_unchecked(uint32 _perc, uint64 _num) private pure returns (uint64) {
        // require(_perc <= 10000, 'err: invalid percent');
        uint32 aux_perc = _perc * 100; // Multiply by 100 to accommodate decimals
        uint64 result = (_num * uint64(aux_perc)) / 1000000; // chatGPT equation
        return result; // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)

        // NOTE: more efficient with no local vars allocated
        // return (_num * uint64(uint32(_perc) * 100)) / 1000000; // chatGPT equation
    }
    function _uint64_from_uint256(uint256 value) private pure returns (uint64) {
        require(value <= type(uint64).max, "Value exceeds uint64 range");
        uint64 convertedValue = uint64(value);
        return convertedValue;
    }
    function _exeSwapPlsForStable(uint256 _plsAmnt, address _usdStable) private returns (uint256) {
        address[] memory pls_stab_path = new address[](2);
        pls_stab_path[0] = TOK_WPLS;
        pls_stab_path[1] = _usdStable;
        (uint8 rtrIdx, uint256 stab_amnt) = _best_swap_v2_router_idx_quote(pls_stab_path, _plsAmnt, USWAP_V2_ROUTERS);
        uint256 stab_amnt_out = _swap_v2_wrap(pls_stab_path, USWAP_V2_ROUTERS[rtrIdx], _plsAmnt, address(this), true); // true = fromETH
        stab_amnt_out = _normalizeStableAmnt(USD_STABLE_DECIMALS[_usdStable], stab_amnt_out, _usd_decimals());
        return stab_amnt_out;
    }
    function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) private returns (uint256) {
        address usdStable = _stab_tok_path[0]; // required: _stab_tok_path[0] must be a stable
        uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[usdStable]);
        (uint8 rtrIdx, uint256 tok_amnt) = _best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);

        // NOTE: algo to account for contracts unable to be a receiver of its own token in UniswapV2Pool.sol
        // if out token in _stab_tok_path is BST, then swap w/ SWAP_DELEGATE as reciever,
        //   and then get tok_amnt_out from delegate (USER_maintenance)
        // else, swap with BST address(this) as receiver 
        if (_stab_tok_path[_stab_tok_path.length-1] == address(this) && _receiver == address(this))  {
            uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, SWAP_DELEGATE, false); // true = fromETH
            SWAPD.USER_maintenance(tok_amnt_out, _stab_tok_path[_stab_tok_path.length-1]);
            return tok_amnt_out;
        } else {
            uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
            return tok_amnt_out;
        }
    }
    function _addAddressToArraySafe(address _addr, address[] memory _arr, bool _safe) private pure returns (address[] memory) {
        if (_addr == address(0)) { return _arr; }

        // safe = remove first (no duplicates)
        if (_safe) { _arr = _remAddressFromArray(_addr, _arr); }

        // perform add to memory array type w/ static size
        address[] memory _ret = new address[](_arr.length+1);
        for (uint i=0; i < _arr.length;) { _ret[i] = _arr[i]; unchecked {i++;}}
        _ret[_ret.length-1] = _addr;
        return _ret;
    }
    function _remAddressFromArray(address _addr, address[] memory _arr) private pure returns (address[] memory) {
        if (_addr == address(0) || _arr.length == 0) { return _arr; }
        
        // NOTE: remove algorithm does NOT maintain order & only removes first occurance
        for (uint i = 0; i < _arr.length;) {
            if (_addr == _arr[i]) {
                _arr[i] = _arr[_arr.length - 1];
                assembly { // reduce memory _arr length by 1 (simulate pop)
                    mstore(_arr, sub(mload(_arr), 1))
                }
                return _arr;
            }

            unchecked {i++;}
        }
        return _arr;
    }
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
    function _usd_decimals() private pure returns (uint8) {
        return 6; // (6 decimals) 
            // * min USD = 0.000001 (6 decimals) 
            // uint16 max USD: ~0.06 -> 0.065535 (6 decimals)
            // uint32 max USD: ~4K -> 4,294.967295 USD (6 decimals)
            // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - DEX QUOTE SUPPORT                                    
    /* -------------------------------------------------------- */
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) private view returns (address) {
        // traverse _stables & select stable w/ the lowest market value
        uint256 curr_high_tok_val = 0;
        address curr_low_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the most when swapped 'from' WPLS
            //  the more USD stable received for 1 WPLS ~= the less overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (uint8 rtrIdx, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_high_tok_val) {
                curr_high_tok_val = tok_val;
                curr_low_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_low_val_stable;
    }
    
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) private view returns (address) {
        // traverse _stables & select stable w/ the highest market value
        uint256 curr_low_tok_val = 0;
        address curr_high_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the least when swapped 'from' WPLS
            //  the less USD stable received for 1 WPLS ~= the more overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (uint8 rtrIdx, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_low_tok_val) {
                curr_low_tok_val = tok_val;
                curr_high_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_high_val_stable;
    }

    // uniswap v2 protocol based: get router w/ best quote in 'uswapV2routers'
    function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) private view returns (uint8, uint256) {
        uint8 currHighIdx = 37;
        uint256 currHigh = 0;
        for (uint8 i = 0; i < _routers.length;) {
            uint256[] memory amountsOut = IUniswapV2Router02(_routers[i]).getAmountsOut(amount, path); // quote swap
            if (amountsOut[amountsOut.length-1] > currHigh) {
                currHigh = amountsOut[amountsOut.length-1];
                currHighIdx = i;
            }

            // NOTE: unchecked, never more than 255 (_routers)
            unchecked {
                i++;
            }
        }

        return (currHighIdx, currHigh);
    }

    // uniwswap v2 protocol based: get quote and execute swap
    function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) private returns (uint256) {
        require(path.length >= 2, 'err: path.length :/');
        uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(amntIn, path); // quote swap
        uint256 amntOut = _swap_v2(router, path, amntIn, amountsOut[amountsOut.length -1], outReceiver, fromETH); // approve & execute swap
                
        // verifiy new balance of token received
        uint256 new_bal = IERC20(path[path.length -1]).balanceOf(outReceiver);
        require(new_bal >= amntOut, " _swap: receiver bal too low :{ ");
        
        return amntOut;
    }
    
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
        if (from != address(this)) {
            return super.transferFrom(from, to, value);
        } else {
            _transfer(from, to, value); // balance checks, etc. indeed occur
        }
        return true;
    }
}
