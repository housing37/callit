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
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";



// import "./SwapDelegate.sol";
import "./CallitTicket.sol";
// import "./ICallitLib.sol";

// interface ISwapDelegate { // (legacy)
//     function VERSION() external view returns (uint8);
//     function USER_INIT() external view returns (bool);
//     function USER() external view returns (address);
//     function USER_maintenance(uint256 _tokAmnt, address _token) external;
//     function USER_setUser(address _newUser) external;
//     function USER_burnToken(address _token, uint256 _tokAmnt) external;
// }

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
    function burnForWinClaim(address _account, uint256 _amount) external;
    function balanceOf(address account) external returns(uint256);
}

// contract LUSDShareToken is ERC20, Ownable { // (legacy)
contract CallitFactory is ERC20, Ownable {
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    // NOTE: SWAPD will only work with 1 contract at a time (ie. it checks for a 'USER')
    //  SWAPD needed for LUSDst integration, in '_exeBstPayout', if 'ENABLE_MARKET_BUY'
    //  SWAPD also needed for delegate burning in '_exeTokBuyBurn', if '!_selAuxPay'
    //    (to leave opp available for native pLUSDT contract burning w/ totalSupply())
    // ISwapDelegate private SWAPD;
    // address private constant SWAP_DELEGATE_INIT = address(0xA8d96d0c328dEc068Db7A7Ba6BFCdd30DCe7C254); // v5 (052924)
    // address private SWAP_DELEGATE = SWAP_DELEGATE_INIT;

    /* -------------------------------------------------------- */
    /* LUSDst additions (legacy)
    /* -------------------------------------------------------- */
    // bool public ENABLE_TOK_BURN_LOCK;
    // bool public ENABLE_BURN_DELEGATE;
    // bool public ENABLE_AUX_PAY;
    // address public TOK_BURN_LOCK;
    // address public TOK_pLUSD = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);

    /* -------------------------------------------------------- */
    /* GLOBALS (legacy)
    /* -------------------------------------------------------- */
    /* _ TOKEN INIT SUPPORT _ */
    string public tVERSION = '0.1';
    string private TOK_SYMB = string(abi.encodePacked("tCALL", tVERSION));
    string private TOK_NAME = string(abi.encodePacked("tCALL_", tVERSION));

    // TG @Nicoleoracle: "LUSDST for LUSD share token. We can start the token at  seven zero five. We can discuss this more"
    // string private TOK_SYMB = "CALL";
    // string private TOK_NAME = "CALL-IT";

    /* _ ADMIN SUPPORT _ */
    address public KEEPER;
    uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    // bool private ENABLE_MARKET_QUOTE; // set BST pay & burn val w/ market quote (else 1:1)
    // bool private ENABLE_MARKET_BUY; // cover BST pay & burn val w/ market buy (else use holdings & mint)
    // bool private ENABLE_AUX_BURN;
    // uint32 private PERC_SERVICE_FEE; // 0 = 0.00%, 505 = 5.05%, 2505 = 25.05%, 10000 = 100.00%
    // uint32 private PERC_BST_BURN;
    // uint32 private PERC_AUX_BURN;
    // uint32 private PERC_BUY_BACK_FEE;

    // SUMMARY: controlling how much USD to payout (usdBuyBackVal), effecting profits & demand to trade-in
    // SUMMARY: controlling how much BST to payout (bstPayout), effecting profits & demand on the open market
    // uint32 private RATIO_BST_PAYOUT = 10000; // default 10000 _ ie. 100.00% (bstPayout:usdPayout -> 1:1 USD)
    // uint32 private RATIO_USD_PAYOUT = 10000; // default 10000 _ ie. 100.00% (usdBuyBackVal:_bstAmnt -> 1:1 BST)
    
    /* _ ACCOUNT SUPPORT _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    address[] private ACCOUNTS;
    mapping(address => uint64) public ACCT_USD_BALANCES; 
    // mapping(address => ACCT_PAYOUT[]) public ACCT_USD_PAYOUTS;

    address[] public USWAP_V2_ROUTERS;
    address[] private WHITELIST_USD_STABLES;
    address[] private USD_STABLES_HISTORY;
    mapping(address => uint8) public USD_STABLE_DECIMALS;
    // mapping(address => address[]) private USD_BST_PATHS;

    /* -------------------------------------------------------- */
    /* STRUCTS (legacy)
    /* -------------------------------------------------------- */
    // struct ACCT_PAYOUT {
    //     address receiver;
    //     uint64 usdAmntDebit; // USD total ACCT deduction
    //     uint64 usdPayout; // USD payout value
    //     // uint64 bstPayout; // BST payout amount
    //     uint256 bstPayout; // BST payout amount
    //     uint64 usdFeeVal; // USD service fee amount
    //     uint64 usdBurnValTot; // to USD value burned (BST + aux token)
    //     uint64 usdBurnVal; // BST burned in USD value
    //     uint256 auxUsdBurnVal; // aux token burned in USD val during payout
    //     address auxTok; // aux token burned during payout
    //     uint32 ratioBstPay; // rate at which BST was paid (1<:1 USD)
    //     uint256 blockNumber; // current block number of this payout
    // }

    /* -------------------------------------------------------- */
    /* EVENTS - LUSDST (legacy)
    /* -------------------------------------------------------- */
    // event EnableLegacyUpdated(bool _prev, bool _new);
    // event SetTokenBurnLock(address _prev_tok, bool _prev_lock_stat, address _new_tok, bool _new_lock_stat);
    // event SetEnableBurnDelegate(bool _prev, bool _new);
    // event SetEnableAuxPay(bool _prev, bool _new);

    /* -------------------------------------------------------- */
    /* EVENTS (legacy)
    /* -------------------------------------------------------- */
    event KeeperTransfer(address _prev, address _new);
    event TokenNameSymbolUpdated(string TOK_NAME, string TOK_SYMB);
    // event SwapDelegateUpdated(address _prev, address _new);
    // event SwapDelegateUserUpdated(address _prev, address _new);
    // event TradeInFeePercUpdated(uint32 _prev, uint32 _new);
    // event PayoutPercsUpdated(uint32 _prev_0, uint32 _prev_1, uint32 _prev_2, uint32 _new_0, uint32 _new_1, uint32 _new_2);
    // event DexExecutionsUpdated(bool _prev_0, bool _prev_1, bool _prev_2, bool _new_0, bool _new_1, bool _new_2);
    event DepositReceived(address _account, uint256 _plsDeposit, uint64 _stableConvert);
    // event PayOutProcessed(address _from, address _to, uint64 _usdAmnt, uint64 _usdAmntPaid, uint64 _bstPayout, uint64 _usdFee, uint64 _usdBurnValTot, uint64 _usdBurnVal, uint64 _usdAuxBurnVal, address _auxToken, uint32 _ratioBstPay, uint256 _blockNumber);
    // event PayOutProcessed(address _from, address _to, uint64 _usdAmnt, uint64 _usdAmntPaid, uint256 _bstPayout, uint64 _usdFee, uint64 _usdBurnValTot, uint64 _usdBurnVal, uint64 _usdAuxBurnVal, address _auxToken, uint32 _ratioBstPay, uint256 _blockNumber);
    // event TradeInFailed(address _trader, uint64 _bstAmnt, uint64 _usdTradeVal);
    // event TradeInDenied(address _trader, uint64 _bstAmnt, uint64 _usdTradeVal);
    // event TradeInProcessed(address _trader, uint64 _bstAmnt, uint64 _usdTradeVal, uint64 _usdBuyBackVal, uint32 _ratioUsdPay, uint256 _blockNumber);
    event WhitelistStableUpdated(address _usdStable, uint8 _decimals, bool _add);
    event DexRouterUpdated(address _router, bool _add);
    // event DexUsdBstPathUpdated(address _usdStable, address[] _path);
    // event BuyAndBurnExecuted(address _burnTok, uint256 _burnAmnt);

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR (legacy)
    /* -------------------------------------------------------- */
    // NOTE: sets msg.sender to '_owner' ('Ownable' maintained)
    constructor(uint256 _initSupply) ERC20(TOK_NAME, TOK_SYMB) Ownable(msg.sender) {
        // CALLIT_LIB_ADDR = _callit_lib;
        // CALLIT_LIB = ICallitLib(_callit_lib);

        // set default globals (LUSDst additions)
        // TOK_BURN_LOCK = address(TOK_pLUSD);
        // ENABLE_TOK_BURN_LOCK = true; // deploy w/ ENABLED burn lock to pLUSD
        // ENABLE_BURN_DELEGATE = true; // deploy w/ ENABLED using SWAPD to burn
        // ENABLE_AUX_PAY = false; // deploy w/ DISABLED option to payout instead of burn
        
        // set default globals
        // ENABLE_MARKET_BUY = false;
        // PERC_SERVICE_FEE = 1000;  // 10.00% of _usdValue (in payOutBST) for service fee
        // PERC_AUX_BURN = 9000; // 90.00% of _usdValue (in payOutBST) for pLUSD buy&burn
        KEEPER = msg.sender;
        KEEPER_CHECK = 0;
        _mint(msg.sender, _initSupply * 10**uint8(decimals())); // 'emit Transfer'

        // // init 'ISwapDelegate' & set 'SWAP_DELEGATE' & set SWAPD init USER
        // //  to fascilitate contract buying its own contract token
        // _setSwapDelegate(SWAP_DELEGATE_INIT);

        // add a whitelist stable
        _editWhitelistStables(address(0xefD766cCb38EaF1dfd701853BFCe31359239F305), 18, true); // weDAI, decs, true = add

        // add default routers: pulsex (x2)
        _editDexRouters(address(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02), true); // pulseX v1, true = add
        // _editDexRouters(address(0x165C3410fC91EF562C50559f7d2289fEbed552d9), true); // pulseX v2, true = add

        

        // // add default stables & default USD_BST_PATHS (routing through WPLS required)
        // address[] memory path = new address[](3);
        // // address usdStable_0 = address(0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f); // weUSDT
        // // path[0] = usdStable_0;
        // // path[1] = TOK_WPLS;
        // // path[2] = address(this);
        // // _editWhitelistStables(usdStable_0, 6, true); // weDAI, decs, true = add
        // // _setUsdBstPath(usdStable_0, path);

        // address usdStable_1 = address(0xefD766cCb38EaF1dfd701853BFCe31359239F305); // weDAI
        // path[0] = usdStable_1;
        // path[1] = TOK_WPLS;
        // path[2] = address(this);
        // // _setUsdBstPath(usdStable_1, path);
        // _editWhitelistStables(usdStable_1, 18, true); // weDAI, decs, true = add
        
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
    // function KEEPER_setEnableAuxPay(bool _enable) external onlyKeeper() {
    //     bool prev = ENABLE_AUX_PAY;
    //     ENABLE_AUX_PAY = _enable;
    //     emit SetEnableAuxPay(prev, ENABLE_AUX_PAY);
    // }
    // function KEEPER_setEnableBurnDelegate(bool _enable) external onlyKeeper() {
    //     bool prev = ENABLE_BURN_DELEGATE;
    //     ENABLE_BURN_DELEGATE = _enable;
    //     emit SetEnableBurnDelegate(prev, ENABLE_BURN_DELEGATE);
    // }
    
    // // NOTE: if _lock = false, this means that ENABLE_TOK_BURN_LOCK
    // //  will ultimately be turned off and always use '_auxToken' in 'payOutBST'
    // function KEEPER_setTokenBurnLock(address _token, bool _lock) external onlyKeeper() {
    //     require(_token != address(0), ' 0 address ');
    //     address prev_tok = TOK_BURN_LOCK;
    //     bool prev_lock = ENABLE_TOK_BURN_LOCK;
    //     TOK_BURN_LOCK = _token;
    //     ENABLE_TOK_BURN_LOCK = _lock;
    //     emit SetTokenBurnLock(prev_tok, prev_lock, TOK_BURN_LOCK, ENABLE_TOK_BURN_LOCK);
    // }
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
    // function KEEPER_setSwapDelegate(address _swapd) external onlyKeeper() {
    //     require(_swapd != address(0), ' 0 address ;0 ');
    //     _setSwapDelegate(_swapd); // emits 'SwapDelegateUpdated'
    // }
    // function KEEPER_setSwapDelegateUser(address _newUser) external onlyKeeper() {
    //     address prev = SWAPD.USER();
    //     SWAPD.USER_setUser(_newUser);
    //     emit SwapDelegateUserUpdated(prev, SWAPD.USER());
    // }
    // function KEEPER_setPayoutPercs(uint32 _servFee, uint32 _bstBurn, uint32 _auxBurn) external onlyKeeper() {
    //     require(_servFee + _bstBurn + _auxBurn <= 10000, ' total percs > 100.00% ;) ');
    //     uint32 prev_0 = PERC_SERVICE_FEE;
    //     // uint32 prev_1 = PERC_BST_BURN;
    //     uint32 prev_2 = PERC_AUX_BURN;
    //     PERC_SERVICE_FEE = _servFee;
    //     // PERC_BST_BURN = _bstBurn;
    //     PERC_AUX_BURN = _auxBurn;
    //     // emit PayoutPercsUpdated(prev_0, prev_1, prev_2, PERC_SERVICE_FEE, PERC_BST_BURN, PERC_AUX_BURN);
    //     emit PayoutPercsUpdated(prev_0, 0, prev_2, PERC_SERVICE_FEE, 0, PERC_AUX_BURN);
    // }
    // function KEEPER_setDexOptions(bool _marketQuote, bool _marketBuy, bool _auxTokenBurn) external onlyKeeper() {
    //     // NOTE: some functions still indeed get quotes from dexes without this being enabled
    //     // require(_marketQuote || (!_marketBuy), ' invalid input combo :{=} ');
    //     // bool prev_0 = ENABLE_MARKET_QUOTE;
    //     bool prev_1 = ENABLE_MARKET_BUY;
    //     // bool prev_2 = ENABLE_AUX_BURN;

    //     // ENABLE_MARKET_QUOTE = _marketQuote;    
    //     ENABLE_MARKET_BUY = _marketBuy;
    //     // ENABLE_AUX_BURN = _auxTokenBurn;
        
    //     emit DexExecutionsUpdated(false, prev_1, false, false, ENABLE_MARKET_BUY, false);
    // }
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
    // function KEEPER_setUsdBstPath(address _usdStable, address[] memory _path) external onlyKeeper() {
    //     require(_usdStable != address(0) && _path.length > 1, ' invalid inputs :{=} ');
    //     require(_usdStable == _path[0], ' stable / entry path mismatch =)');
    //     _setUsdBstPath(_usdStable, _path);
    //     // NOTE: '_path' must be valid within all 'USWAP_V2_ROUTERS' addresses
    // }

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
    // function getAccountPayouts(address _account) external view returns (ACCT_PAYOUT[] memory) {
    //     require(_account != address(0), ' 0 address? ;[+] ');
    //     return ACCT_USD_PAYOUTS[_account];
    // }
    // function getDexOptions() external view returns (bool, bool, bool) {
    //     return (false, ENABLE_MARKET_BUY, false);
    // }
    // function getPayoutPercs() external view returns (uint32, uint32, uint32, uint32) {
    //     // return (PERC_SERVICE_FEE, PERC_BST_BURN, PERC_AUX_BURN, PERC_BUY_BACK_FEE);
    //     return (PERC_SERVICE_FEE, 0, PERC_AUX_BURN, 0);
    // }
    // function getUsdBstPath(address _usdStable) external view returns (address[] memory) {
    //     return USD_BST_PATHS[_usdStable];
    // }    
    function getUsdStablesHistory() external view returns (address[] memory) {
        return USD_STABLES_HISTORY;
    }    
    function getWhitelistStables() external view returns (address[] memory) {
        return WHITELIST_USD_STABLES;
    }
    function getDexRouters() external view returns (address[] memory) {
        return USWAP_V2_ROUTERS;
    }
    // function getSwapDelegateInfo() external view returns (address, uint8, address) {
    //     return (SWAP_DELEGATE, SWAPD.VERSION(), SWAPD.USER());
    // }

    /* -------------------------------------------------------- */
    /* GLOBALS (CALLIT)
    /* -------------------------------------------------------- */
    uint16 PERC_MARKET_MAKER_FEE; // TODO: KEEPER setter
    uint16 PERC_PROMO_BUY_FEE; // TODO: KEEPER setter
    uint16 PERC_ARB_EXE_FEE; // TODO: KEEPER setter
    uint16 PERC_MARKET_CLOSE_FEE; // TODO: KEEPER setter
    uint16 PERC_VOTE_CLAIM_FEE; // TODO: KEEPER setter

    // address public CALLIT_LIB_ADDR;
    // ICallitLib private CALLIT_LIB;

    address NEW_TICK_UNISWAP_V2_ROUTER;
    address NEW_TICK_UNISWAP_V2_FACTORY;
    address NEW_TICK_USD_STABLE;

    uint64 public TOK_TICK_INIT_SUPPLY = 1000000; // init supply used for new call ticket tokens (uint64 = ~18,000Q max)
    string public TOK_TICK_NAME_SEED = "TCK#";
    string public TOK_TICK_SYMB_SEED = "CALL-TICKET";
    // string private TOK_TICK_NAME_SEED = string(abi.encodePacked("TCK#"));
    // string private TOK_TICK_SYMB_SEED = string(abi.encodePacked("CALL-TICKET"));

    uint256 SEC_DEFAULT_VOTE_TIME = 24 * 60 * 60; // 24 * 60 * 60 == 86,400 sec == 24 hours
    bool USE_SEC_DEFAULT_VOTE_TIME = true; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    
    uint64 public MAX_EOA_MARKETS = type(uint8).max; // uint8 = 255 (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)
        // NOTE: additional launch security: caps EOA $CALL earned to 255
        //  but also limits the EOA following (KEEPER setter available; should raise after launch)

    uint64 public MIN_USD_CALL_TICK_TARGET_PRICE = 10000; // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
    uint16 MIN_USD_MARK_LIQ = 10; // min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    uint16 MAX_RESULTS = 100; // max # of result options a market may have (uint16 max = ~65K -> 65,535)
    uint8 MIN_HANDLE_SIZE = 1; // min # of chars for account handles
    uint8 MAX_HANDLE_SIZE = 25; // max # of chars for account handles
    uint64 MIN_USD_PROMO_TARGET = 100; // min $ target for creating promo codes
    uint64 RATIO_PROMO_USD_PER_CALL_TOK = 100; // usd amount buy needed per $CALL earned in promo (note: global across all promos to avoid exploitations)
        // LEFT OFF HERE  ... may need decimal precision integration
    uint64 RATIO_LP_USD_PER_CALL_TOK = 100; // init LP usd amount needed per $CALL earned by market maker
        // LEFT OFF HERE  ... may need decimal precision integration
    uint16 RATIO_LP_TOK_PER_USD = 10000;
    uint32 private PERC_PRIZEPOOL_VOTERS = 200; // (2%) _ 10000 = %100.00; 5000 = %50.00; 0001 = %00.01
    uint8 public RATIO_CALL_MINT_PER_LOSER = 1;
    uint16 public PERC_OF_LOSER_SUPPLY_EARN_CALL = 2500; // (25%) _ 10000 = %100.00; 5000 = %50.00; 0001 = %00.01

    mapping(address => bool) public ADMINS; // enable/disable admins (for promo support, etc)
    mapping(address => string) public ACCT_HANDLES; // market makers (etc.) can set their own handles
    mapping(address => MARKET[]) public ACCT_MARKETS; // store maker to all their MARKETs created mapping
    mapping(address => address) public TICKET_MAKERS; // store ticket to their MARKET.maker mapping
    mapping(address => PROMO) public PROMO_CODE_HASHES; // store promo code hashes to their PROMO mapping
    mapping(address => uint64) public EARNED_CALL_VOTES; // track EOAs to result votes allowed for open markets (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)
    mapping(address => uint256) public ACCT_CALL_VOTE_LOCK_TIME; // track EOA to their call token lock timestamp; remember to reset to 0 (ie. 'not locked')
    mapping(address => MARKET_VOTE[]) public ACCT_MARKET_VOTES; // store voter to their non-paid MARKET_VOTEs (markets voted in) mapping
    mapping(address => MARKET_VOTE[]) public ACCT_MARKET_VOTES_PAID; // store voter to their 'paid' MARKET_VOTEs (markets voted in) mapping
    mapping(address => MARKET_REVIEW[]) public ACCT_MARKET_REVIEWS; // store maker to all their MARKET_REVIEWs created by callers

    /* -------------------------------------------------------- */
    /* EVENTS (CALLIT)
    /* -------------------------------------------------------- */
    event MarketCreated(address _maker, uint256 _markNum, string _name, uint64 _usdAmntLP, uint256 _dtCallDeadline, uint256 _dtResultVoteStart, uint256 _dtResultVoteEnd, string[] _resultLabels, address[] _resultOptionTokens, uint256 _blockTime, bool _live);
    event PromoCreated(address _promoHash, address _promotor, string _promoCode, uint64 _usdTarget, uint64 usdUsed, uint8 _percReward, address _creator, uint256 _blockNumber);
    event PromoRewardPaid(address _promoCodeHash, uint64 _usdRewardPaid, address _promotor, address _buyer, address _ticket);
    event PromoBuyPerformed(address _buyer, address _promoCodeHash, address _usdStable, address _ticket, uint64 _grossUsdAmnt, uint64 _netUsdAmnt, uint256  _tickAmntOut);
    event AlertStableSwap(uint256 _tickStableReq, uint256 _contrStableBal, address _swapFromStab, address _swapToTickStab, uint256 _tickStabAmntNeeded, uint256 _swapAmountOut);
    event AlertZeroReward(address _sender, uint64 _usdReward, address _receiver);
    event MarketReviewed(address _caller, bool _resultAgree, address _marketMaker, uint256 _marketNum, uint64 _agreeCnt, uint64 _disagreeCnt);
    
    /* -------------------------------------------------------- */
    /* STRUCTS (CALLIT)
    /* -------------------------------------------------------- */
    struct PROMO {
        address promotor; // influencer wallet this promo is for
        string promoCode;
        uint64 usdTarget; // usd amount this promo is good for
        uint64 usdUsed; // usd amount this promo has used so far
        uint8 percReward; // % of caller buys rewarded
        address adminCreator; // admin who created this promo
        uint256 blockNumber; // block number this promo was created
    }
    struct MARKET {
        address maker; // EOA market maker
        uint256 marketNum; // used incrementally for MARKET[] in ACCT_MARKETS
        string name; // display name for this market (maybe auto-generate w/ )
        // MARKET_INFO marketInfo;
        string category;
        string rules;
        string imgUrl;
        MARKET_USD_AMNTS marketUsdAmnts;
        // uint64 usdAmntLP; // total usd provided by maker (will be split amount 'resultOptionTokens')
        // uint64 usdAmntPrizePool; // default 0, until market voting ends
        // uint64 usdAmntPrizePool_net; // default 0, until market voting ends
        // uint64 usdVoterRewardPool; // default 0, until close market calc
        // uint64 usdRewardPerVote; // default 0, until close mark calc
        MARKET_DATETIMES marketDatetimes;
        // uint256 dtCallDeadline; // unix timestamp 1970, no more bets, pull liquidity from all DEX LPs generated
        // uint256 dtResultVoteStart; // unix timestamp 1970, earned $CALL token EOAs may start voting
        // uint256 dtResultVoteEnd; // unix timestamp 1970, earned $CALL token EOAs voting ends
        MARKET_RESULTS marketResults;
        // string[] resultLabels; // required: length == _resultDescrs
        // string[] resultDescrs; // required: length == _resultLabels
        // address[] resultOptionTokens; // required: length == _resultLabels == _resultDescrs
        // address[] resultTokenLPs; // // required: length == _resultLabels == _resultDescrs == resultOptionTokens
        // address[] resultTokenRouters;
        // address[] resultTokenFactories;
        // address[] resultTokenUsdStables;
        // uint64[] resultTokenVotes;
        uint16 winningVoteResultIdx; // calc winning idx from resultTokenVotes 
        uint256 blockTimestamp; // sec timestamp this market was created
        uint256 blockNumber; // block number this market was created
        bool live;
    }
    // struct MARKET_INFO {
    //     string category;
    //     string rules;
    //     string imgUrl;
    // }
    struct MARKET_USD_AMNTS {
        uint64 usdAmntLP; // total usd provided by maker (will be split amount 'resultOptionTokens')
        uint64 usdAmntPrizePool; // default 0, until market voting ends
        uint64 usdAmntPrizePool_net; // default 0, until market voting ends
        uint64 usdVoterRewardPool; // default 0, until close market calc
        uint64 usdRewardPerVote; // default 0, until close mark calc
    }
    struct MARKET_DATETIMES {
        uint256 dtCallDeadline; // unix timestamp 1970, no more bets, pull liquidity from all DEX LPs generated
        uint256 dtResultVoteStart; // unix timestamp 1970, earned $CALL token EOAs may start voting
        uint256 dtResultVoteEnd; // unix timestamp 1970, earned $CALL token EOAs voting ends
    }
    struct MARKET_RESULTS {
        string[] resultLabels; // required: length == _resultDescrs
        string[] resultDescrs; // required: length == _resultLabels
        address[] resultOptionTokens; // required: length == _resultLabels == _resultDescrs
        address[] resultTokenLPs; // // required: length == _resultLabels == _resultDescrs == resultOptionTokens
        address[] resultTokenRouters;
        address[] resultTokenFactories;
        address[] resultTokenUsdStables;
        uint64[] resultTokenVotes;
    }
    struct MARKET_VOTE {
        address voter;
        address voteResultToken;
        uint16 voteResultIdx;
        uint64 voteResultCnt;
        address marketMaker;
        uint256 marketNum;
        bool paid;
    }
    struct MARKET_REVIEW { 
        address caller;
        bool resultAgree;
        address marketMaker;
        uint256 marketNum;
        uint64 agreeCnt;
        uint64 disagreeCnt;
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
    function KEEPER_setMinMaxAcctHandleSize(uint8 _min, uint8 _max) external onlyKeeper {
        MIN_HANDLE_SIZE = _min; // min # of chars for account handles
        MAX_HANDLE_SIZE = _max; // max # of chars for account handles
    }
    function KEEPER_setMinUsdPromoTarget(uint64 _usdTarget) external onlyKeeper {
        MIN_USD_PROMO_TARGET = _usdTarget;
    }
    function KEEPER_setRatioPromoBuyUsdPerCall(uint64 _usdBuyRequired) external onlyKeeper {
        RATIO_PROMO_USD_PER_CALL_TOK = _usdBuyRequired;
    }
    function KEEPER_setRatioMarketLpUsdPerCall(uint64 _usdLpRequired) external onlyKeeper {
        RATIO_LP_USD_PER_CALL_TOK = _usdLpRequired;
    }
    function KEEPER_setRatioLpTokPerUsd(uint16 _ratio) external onlyKeeper {
        RATIO_LP_TOK_PER_USD = _ratio;
    }
    function KEEPER_setTokTicketNameSymbSeeds(string calldata _nameSeed, string calldata _symbSeed) external onlyKeeper {
        TOK_TICK_NAME_SEED = _nameSeed;
        TOK_TICK_SYMB_SEED = _symbSeed;
    }
    function KEEPER_setTokTickInitSupply(uint64 _initSupply) external onlyKeeper {
        TOK_TICK_INIT_SUPPLY = _initSupply; // NOTE: uint64 max = ~18,000Q
    }
    function KEEPER_setMaxEoaMarkets(uint64 _max) external onlyKeeper { // uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
        MAX_EOA_MARKETS = _max;
    }
    function KEEPER_setMinInitMarketLiq(uint16 _min) external onlyKeeper {
        MIN_USD_MARK_LIQ = _min;
    }
    function KEEPER_setNewTicketEnvironment(address _router, address _factory, address _usdStable) external onlyKeeper {
        // max array size = 255 (uint8 loop)
        require(_isAddressInArray(_router, USWAP_V2_ROUTERS) && _isAddressInArray(_usdStable, WHITELIST_USD_STABLES), ' !whitelist router|stable :() ');
        NEW_TICK_UNISWAP_V2_ROUTER = _router;
        NEW_TICK_UNISWAP_V2_FACTORY = _factory;
        NEW_TICK_USD_STABLE = _usdStable;
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
    

    /* -------------------------------------------------------- */
    /* PUBLIC - ADMIN MUTATORS (CALLIT)
    /* -------------------------------------------------------- */
    function ADMIN_initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward) external onlyAdmin {
        require(_promotor != address(0) && _validNonWhiteSpaceString(_promoCode) && _usdTarget >= MIN_USD_PROMO_TARGET, ' !param(s) :={ ');
        address promoCodeHash = _generateAddressHash(_promotor, _promoCode);
        PROMO storage promo = PROMO_CODE_HASHES[promoCodeHash];
        require(promo.promotor == address(0), ' promo already exists :-O ');
        // PROMO_CODE_HASHES[promoCodeHash].push(PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number));
        PROMO_CODE_HASHES[promoCodeHash] = PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
        emit PromoCreated(promoCodeHash, _promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS (CALLIT)
    /* -------------------------------------------------------- */
    function getAccountMarkets(address _account) external view returns (MARKET[] memory) {
        require(_account != address(0), ' 0 address? ;[+] ');
        return ACCT_MARKETS[_account];
    }
    function checkPromoBalance(address _promoCodeHash) external view returns(uint64) {
        PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        return promo.usdTarget - promo.usdUsed;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - MUTATORS (CALLIT)
    /* -------------------------------------------------------- */
    function setMyAcctHandle(string calldata _handle) external {
        require(bytes(_handle).length >= MIN_HANDLE_SIZE && bytes(_handle).length <= MAX_HANDLE_SIZE, ' !_handle.length :[] ');
        require(bytes(_handle)[0] != 0x20, ' !_handle space start :+[ '); // 0x20 -> ASCII for ' ' (single space)
        if (_validNonWhiteSpaceString(_handle))
            ACCT_HANDLES[msg.sender] = _handle;
        else
            revert(' !blank space handles :-[=] ');        
    }
    function setCallTokenVoteLock(bool _lock) external {
        ACCT_CALL_VOTE_LOCK_TIME[msg.sender] = _lock ? block.timestamp : 0;
    }

    address[] private resultOptionTokens;
    address[] private resultTokenLPs;
    address[] private resultTokenRouters;
    address[] private resultTokenFactories;
    address[] private resultTokenUsdStables;
    uint64 [] private resultTokenVotes;

    /* -------------------------------------------------------- */
    /* PUBLIC - USER INTERFACE (CALLIT)
    /* -------------------------------------------------------- */
    function setMarketInfo(address _anyTicket, string calldata _category, string calldata _descr, string calldata _imgUrl) external {
        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (MARKET storage mark,) = _getMarketForTicket(TICKET_MAKERS[_anyTicket], _anyTicket); // reverts if market not found | address(0)
        require(mark.maker == msg.sender, ' only market maker :( ');
        mark.category = _category;
        mark.rules = _descr;
        mark.imgUrl = _imgUrl;
    }
    function makeNewMarket(string calldata _name, 
                            // string calldata _category, 
                            // string calldata _rules, 
                            // string calldata _imgUrl, 
                            uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, 
                            string[] calldata _resultDescrs
                            ) external { // _deductMarketMakerFees from _usdAmntLP
        require(_usdAmntLP >= MIN_USD_MARK_LIQ, ' need more liquidity! :{=} ');
        require(ACCT_USD_BALANCES[msg.sender] >= _usdAmntLP, ' low balance ;{ ');
        require(2 <= _resultLabels.length && _resultLabels.length <= MAX_RESULTS && _resultLabels.length == _resultDescrs.length, ' bad results count :( ');
        require(block.timestamp < _dtCallDeadline && _dtCallDeadline < _dtResultVoteStart && _dtResultVoteStart < _dtResultVoteEnd, ' invalid dt settings :[] ');

        // initilize/validate market number for struct MARKET tracking
        uint256 mark_num = ACCT_MARKETS[msg.sender].length;
        require(mark_num <= MAX_EOA_MARKETS, ' > MAX_EOA_MARKETS :O ');
        // require(ACCT_MARKETS[msg.sender].length <= MAX_EOA_MARKETS, ' > MAX_EOA_MARKETS :O ');

        // deduct 'market maker fees' from _usdAmntLP
        uint64 net_usdAmntLP = _deductFeePerc(_usdAmntLP, PERC_MARKET_MAKER_FEE, _usdAmntLP);

        // check for admin defualt vote time, update _dtResultVoteEnd accordingly
        if (USE_SEC_DEFAULT_VOTE_TIME) _dtResultVoteEnd = _dtResultVoteStart + SEC_DEFAULT_VOTE_TIME;

        // Loop through _resultLabels and deploy ERC20s for each (and generate LP)
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            // Deploy a new ERC20 token for each result label
            (string memory tok_name, string memory tok_symb) = _genTokenNameSymbol(msg.sender, mark_num, i, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
            address new_tick_tok = address (new CallitTicket(TOK_TICK_INIT_SUPPLY, tok_name, tok_symb));
            
            // Get amounts for initial LP & Create DEX LP for the token
            (uint64 usdAmount, uint256 tokenAmount) = _getAmountsForInitLP(net_usdAmntLP, _resultLabels.length, RATIO_LP_TOK_PER_USD);            
            address pairAddr = _createDexLP(NEW_TICK_UNISWAP_V2_ROUTER, NEW_TICK_UNISWAP_V2_FACTORY, new_tick_tok, NEW_TICK_USD_STABLE, tokenAmount, usdAmount);

            // verify ERC20 & LP was created
            require(new_tick_tok != address(0) && pairAddr != address(0), ' err: gen tick tok | lp :( ');

            resultOptionTokens[i] = new_tick_tok;
            resultTokenLPs[i] = pairAddr;

            resultTokenRouters[i] = NEW_TICK_UNISWAP_V2_ROUTER;
            resultTokenFactories[i] = NEW_TICK_UNISWAP_V2_FACTORY;
            resultTokenUsdStables[i] = NEW_TICK_USD_STABLE;
            resultTokenVotes[i] = 0;

            TICKET_MAKERS[new_tick_tok] = msg.sender;
            unchecked {i++;}
        }

        // deduct full OG usd input from account balance
        ACCT_USD_BALANCES[msg.sender] -= _usdAmntLP;

        // save this market and emit log
        ACCT_MARKETS[msg.sender].push(MARKET({maker:msg.sender, 
                                                marketNum:mark_num, 
                                                name:_name,

                                                // marketInfo:MARKET_INFO("", "", ""),
                                                category:"",
                                                rules:"", 
                                                imgUrl:"", 

                                                marketUsdAmnts:MARKET_USD_AMNTS(_usdAmntLP, 0, 0, 0, 0), 
                                                marketDatetimes:MARKET_DATETIMES(_dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd), 
                                                marketResults:MARKET_RESULTS(_resultLabels, _resultDescrs, resultOptionTokens, resultTokenLPs, resultTokenRouters, resultTokenFactories, resultTokenUsdStables, resultTokenVotes), 
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
    }
    function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt) external { // _deductPromoBuyFees from _usdAmnt
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');
        PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        require(promo.usdTarget - promo.usdUsed >= _usdAmnt, ' promo expired :( ' );
        require(ACCT_USD_BALANCES[msg.sender] >= _usdAmnt, ' low balance ;{ ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (MARKET storage mark, uint64 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
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
            _mintCallToksEarned(msg.sender, _usdAmnt / RATIO_PROMO_USD_PER_CALL_TOK);
        }

        // verify perc calc/taking <= 100% of _usdAmnt
        require(promo.percReward + PERC_PROMO_BUY_FEE <= 10000, ' buy promo fee perc mismatch :o ');

        // calc influencer reward from _usdAmnt to send to promo.promotor
        uint64 usdReward = _perc_of_uint64(promo.percReward, _usdAmnt);
        _payUsdReward(usdReward, promo.promotor); // pay w/ lowest value whitelist stable held (returns on 0 reward)
        emit PromoRewardPaid(_promoCodeHash, usdReward, promo.promotor, msg.sender, _ticket);

        // deduct usdReward & promo buy fee _usdAmnt
        uint64 net_usdAmnt = _usdAmnt - usdReward;
        net_usdAmnt = _deductFeePerc(net_usdAmnt, PERC_PROMO_BUY_FEE, _usdAmnt);

        // verifiy contract holds enough tick_stable_tok for DEX buy
        //  if not, swap another contract held stable that can indeed cover
        // address tick_stable_tok = mark.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
        address tick_stable_tok = mark.marketResults.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
        uint256 contr_stab_bal = IERC20(tick_stable_tok).balanceOf(address(this)); 
        if (contr_stab_bal < net_usdAmnt) { // not enough tick_stable_tok to cover 'net_usdAmnt' buy
            uint64 net_usdAmnt_needed = net_usdAmnt - _uint64_from_uint256(contr_stab_bal);
            (uint256 stab_amnt_out, address stab_swap_from)  = _swapBestStableForTickStable(net_usdAmnt_needed, tick_stable_tok);
            emit AlertStableSwap(net_usdAmnt, contr_stab_bal, stab_swap_from, tick_stable_tok, net_usdAmnt_needed, stab_amnt_out);

            // verify
            uint256 contr_stab_bal_check = IERC20(tick_stable_tok).balanceOf(address(this));
            require(contr_stab_bal_check >= net_usdAmnt, ' tick-stable swap failed :[] ' );
        }

        // swap remaining net_usdAmnt of tick_stable_tok for _ticket on DEX (_ticket receiver = msg.sender)
        // address[] memory usd_tick_path = [tick_stable_tok, _ticket]; // ref: https://ethereum.stackexchange.com/a/28048
        address[] memory usd_tick_path = new address[](2);
        usd_tick_path[0] = tick_stable_tok;
        usd_tick_path[1] = _ticket; // NOTE: not swapping for 'this' contract
        uint256 tick_amnt_out = _exeSwapStableForTok(net_usdAmnt, usd_tick_path, msg.sender); // msg.sender = _receiver

        // deduct full OG input _usdAmnt from account balance
        ACCT_USD_BALANCES[msg.sender] -= _usdAmnt;

        // update promo.usdUsed (add full OG input _usdAmnt)
        promo.usdUsed += _usdAmnt;

        // emit log
        emit PromoBuyPerformed(msg.sender, _promoCodeHash, tick_stable_tok, _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out);
    }
    function exeArbPriceParityForTicket(address _ticket) external { // _deductArbExeFees from arb profits
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (MARKET storage mark, uint64 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');

        // calc target usd price for _ticket (in order to bring this market to price parity)
        //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        uint64 ticketTargetPriceUSD = _getCallTicketUsdTargetPrice(mark, _ticket);

        // calc # of _ticket tokens to mint for DEX sell (to bring _ticket to price parity)
        uint64 /* ~18,000Q */ tokensToMint = _uint64_from_uint256(_calculateTokensToMint(mark.marketResults.resultTokenLPs[tickIdx], ticketTargetPriceUSD));

        // calc price to charge msg.sender for minting tokensToMint
        //  then deduct that amount from their account balance
        uint64 total_usd_cost = ticketTargetPriceUSD * tokensToMint;
        if (msg.sender != KEEPER) { // free for KEEPER
            // verify msg.sender usd balance covers contract sale of minted discounted tokens
            //  NOTE: msg.sender is buying 'tokensToMint' amount @ price = 'ticketTargetPriceUSD', from this contract
            //   'ticketTargetPriceUSD' price should be less usd then selling 'tokensToMint' @ current DEX price 
            //   HENCE, usd profit = gross_stab_amnt_out - total_usd_cost
            require(ACCT_USD_BALANCES[msg.sender] >= total_usd_cost, ' low balance :( ');
            ACCT_USD_BALANCES[msg.sender] -= total_usd_cost; // LEFT OFF HERE ... ticketTargetPriceUSD is uint256, but ACCT_USD_BALANCES is uint64
        }

        // mint tokensToMint count to this factory and sell on DEX on behalf of msg.sender
        //  NOTE: receiver == address(this), NOT msg.sender (need to deduct fees before paying msg.sender)
        ICallitTicket cTicket = ICallitTicket(_ticket);
        cTicket.mintForPriceParity(address(this), tokensToMint);
        require(cTicket.balanceOf(address(this)) >= tokensToMint, ' err: cTicket mint :<> ');
        // address[2] memory tok_stab_path = [_ticket, mark.resultTokenUsdStables[tickIdx]];
        address[] memory tok_stab_path = new address[](3);
        tok_stab_path[0] = _ticket;
        tok_stab_path[1] = mark.marketResults.resultTokenUsdStables[tickIdx];
        uint64 gross_stab_amnt_out = _uint64_from_uint256(_exeSwapTokForStable_router(tokensToMint, tok_stab_path, address(this), mark.marketResults.resultTokenRouters[tickIdx])); // swap tick: use specific router tck:tick-stable

        // calc & send net profits to msg.sender
        //  NOTE: msg.sender gets all of 'gross_stab_amnt_out' (since the contract keeps total_usd_cost)
        //  NOTE: 'net_usd_profits' is msg.sender's profit (after additional fees)
        // uint256 net_usd_profits = _deductArbExeFees(gross_stab_amnt_out, gross_stab_amnt_out); // LEFT OFF HERE ... finish _deductArbExeFees integration
        uint64 net_usd_profits = gross_stab_amnt_out - _perc_of_uint64(PERC_ARB_EXE_FEE, gross_stab_amnt_out);
        require(net_usd_profits > total_usd_cost, ' no profit from arb attempt :( '); // verify msg.sender profit
        IERC20(mark.marketResults.resultTokenUsdStables[tickIdx]).transfer(msg.sender, net_usd_profits);

        // LEFT OFF HERE ... need emit event log
    }
    function closeMarketCallsForTicket(address _ticket) external { // no fee
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');

        // algorithmic logic...
        //  get market for _ticket
        //  verify mark.marketDatetimes.dtCallDeadline has indeed passed
        //  loop through _ticket LP addresses and pull all liquidity

        // get MARKET & idx for _ticket & validate call time indeed ended (NOTE: MAX_EOA_MARKETS is uint64)
        (MARKET storage mark,) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline <= block.timestamp, ' _ticket call deadline not passed yet :(( ');
        require(mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls closed already :p '); // usdAmntPrizePool: defaults to 0, unless closed and liq pulled to fill it

        // loop through pair addresses and pull liquidity 
        address[] memory _ticketLPs = mark.marketResults.resultTokenLPs;
        for (uint16 i = 0; i < _ticketLPs.length;) { // MAX_RESULTS is uint16
            // IUniswapV2Factory uniswapFactory = IUniswapV2Factory(mark.resultTokenFactories[i]);
            IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(mark.marketResults.resultTokenRouters[i]);
            address pairAddress = _ticketLPs[i];
            
            // pull liquidity from pairAddress
            IERC20 pairToken = IERC20(pairAddress);
            uint256 liquidity = pairToken.balanceOf(address(this));  // Get the contract's balance of the LP tokens
            
            // Approve the router to spend the LP tokens
            pairToken.approve(address(uniswapRouter), liquidity);
            
            // Retrieve the token pair
            address token0 = IUniswapV2Pair(pairAddress).token0();
            address token1 = IUniswapV2Pair(pairAddress).token1();

            // check to make sure that token0 is the 'ticket' & token1 is the 'stable'
            require(mark.marketResults.resultOptionTokens[i] == token0 && mark.marketResults.resultTokenUsdStables[i] == token1, ' pair token mismatch w/ MARKET tck:usd :*() ');

            // get OG stable balance, so we can verify later
            uint256 OG_stable_bal = IERC20(mark.marketResults.resultTokenUsdStables[i]).balanceOf(address(this));

            // Remove liquidity
            (, uint256 amountToken1) = uniswapRouter.removeLiquidity(
                token0,
                token1,
                liquidity,
                0, // Min amount of token0, to prevent slippage (adjust based on your needs)
                0, // Min amount of token1, to prevent slippage (adjust based on your needs)
                address(this), // Send tokens to the contract itself or a specified recipient
                block.timestamp + 300 // Deadline (5 minutes from now)
            );

            unchecked {
                i++;
            }

            // verify correct ticket token stable was pulled and recieved
            require(IERC20(mark.marketResults.resultTokenUsdStables[i]).balanceOf(address(this)) >= OG_stable_bal, ' stab bal mismatch after liq pull :+( ');

            // update market prize pool usd received from LP (usdAmntPrizePool: defualts to 0)
            mark.marketUsdAmnts.usdAmntPrizePool += _uint64_from_uint256(amountToken1); // NOTE: write to market
        }

        // LEFT OFF HERE ... need emit event log
        //  mint $CALL token reward to msg.sender
    }
    function castVoteForMarketTicket(address _ticket) external { // no fee
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{=} ');
        require(IERC20(_ticket).balanceOf(msg.sender) == 0, ' no self voting ;( ');

        // algorithmic logic...
        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        //  - store vote in struct MARKET_VOTE and push to ACCT_MARKET_VOTES
        //  - 

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (MARKET storage mark, uint16 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteStart <= block.timestamp, ' market voting not started yet :p ');
        require(mark.marketDatetimes.dtResultVoteEnd > block.timestamp, ' market voting ended :p ');

        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        (bool is_maker, bool is_caller) = _addressIsMarketMakerOrCaller(msg.sender, mark);
        require(!is_maker && !is_caller, ' no self-voting :o ');

        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        uint64 vote_cnt = _validVoteCount(msg.sender, mark);
        require(vote_cnt > 0, ' invalid voter :{=} ');

        //  - store vote in struct MARKET
        mark.marketResults.resultTokenVotes[tickIdx] += vote_cnt; // NOTE: write to market

        // log market vote per EOA, so EOA can claim voter fees earned (where votes = "majority of votes / winning result option")
        ACCT_MARKET_VOTES[msg.sender].push(MARKET_VOTE(msg.sender, _ticket, tickIdx, vote_cnt, mark.maker, mark.marketNum, false)); // false = not paid

        // LEFT OFF HERE ... need emit event log
    }
    function closeMarketForTicket(address _ticket) external { // _deductMarketCloseFees from mark.marketUsdAmnts.usdAmntPrizePool
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{-} ');
        // algorithmic logic...
        //  - count votes in mark.resultTokenVotes 
        //  - set mark.winningVoteResultIdx accordingly
        //  - calc market usdVoterRewardPool (using global KEEPER set percent)
        //  - calc market usdRewardPerVote (for voter reward claiming)
        //  - calc & mint $CALL to market maker (if earned)
        //  - set market 'live' status = false;

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (MARKET storage mark,) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market voting not done yet ;=) ');

        // getting winning result index to set mark.winningVoteResultIdx
        //  for voter fee claim algorithm (ie. only pay majority voters)
        mark.winningVoteResultIdx = _getWinningVoteIdxForMarket(mark); // NOTE: write to market

        // calc & save total voter usd reward pool (ie. a % of prize pool in mark)
        mark.marketUsdAmnts.usdVoterRewardPool = _perc_of_uint64(PERC_PRIZEPOOL_VOTERS, mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market

        // calc & set net prize pool after taking out voter reward pool (+ other market close fees)
        mark.marketUsdAmnts.usdAmntPrizePool_net = mark.marketUsdAmnts.usdAmntPrizePool - mark.marketUsdAmnts.usdVoterRewardPool; // NOTE: write to market
        // mark.marketUsdAmnts.usdAmntPrizePool_net = _deductMarketCloseFees(mark.marketUsdAmnts.usdAmntPrizePool, mark.marketUsdAmnts.usdAmntPrizePool_net); // NOTE: write to market
        mark.marketUsdAmnts.usdAmntPrizePool_net = mark.marketUsdAmnts.usdAmntPrizePool_net - _perc_of_uint64(PERC_MARKET_CLOSE_FEE, mark.marketUsdAmnts.usdAmntPrizePool);
        // calc & save usd payout per vote ("usd per vote" = usd reward pool / total winning votes)
        mark.marketUsdAmnts.usdRewardPerVote = mark.marketUsdAmnts.usdVoterRewardPool / mark.marketResults.resultTokenVotes[mark.winningVoteResultIdx]; // NOTE: write to market

        // check if mark.maker earned $CALL tokens
        if (mark.marketUsdAmnts.usdAmntLP >= RATIO_LP_USD_PER_CALL_TOK) {
            // mint $CALL to mark.maker & log $CALL votes earned
            _mintCallToksEarned(mark.maker, mark.marketUsdAmnts.usdAmntLP / RATIO_LP_USD_PER_CALL_TOK);
        }

        // close market
        mark.live = false; // NOTE: write to market

        // LEFT OFF HERE ... need emit event log
        //  mint $CALL token reward to msg.sender

        // $CALL token earnings design...
        //  DONE - buyer earns $CALL in 'buyCallTicketWithPromoCode'
        //  DONE - market maker should earn call when market is closed (init LP requirement needed)
        //  - invoking 'closeMarketCallsForTicket' earns $CALL
        //  - invoking 'closeMarketForTicket' earns $CALL
        //  - market losers can trade-in their tickets for minted $CALL
        // log $CALL votes earned w/ ...
        // EARNED_CALL_VOTES[msg.sender] += (_usdAmnt / RATIO_PROMO_USD_PER_CALL_TOK);
    }
    function claimTicketRewards(address _ticket, bool _resultAgree) external {
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
        (MARKET storage mark, uint64 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market voting not done yet ;=) ');
        require(!mark.live, ' market still live :o ' );
        require(mark.winningVoteResultIdx == tickIdx, ' not a winner :( ');

        bool is_winner = mark.winningVoteResultIdx == tickIdx;
        if (is_winner) {
            // calc payout based on: _ticket.balanceOf(msg.sender) & mark.marketUsdAmnts.usdAmntPrizePool_net & _ticket.totalSupply();
            uint64 usdPerTicket = _uint64_from_uint256(uint256(mark.marketUsdAmnts.usdAmntPrizePool_net) / IERC20(_ticket).totalSupply());
            uint64 usdPrizePoolShare = _uint64_from_uint256(uint256(usdPerTicket) * IERC20(_ticket).balanceOf(msg.sender));

            // send payout to msg.sender
            _payUsdReward(usdPrizePoolShare, msg.sender);
        } else {
            // NOTE: perc requirement limits ability for exploitation and excessive $CALL minting
            uint64 perc_supply_owned = _perc_total_supply_owned(_ticket, msg.sender);
            if (perc_supply_owned >= PERC_OF_LOSER_SUPPLY_EARN_CALL) {
                // mint $CALL to loser msg.sender & log $CALL votes earned
                _mintCallToksEarned(msg.sender, RATIO_CALL_MINT_PER_LOSER);

                // NOTE: this action could open up a secondary OTC market for collecting loser tickets
                //  ie. collecting losers = minting $CALL
            }
        }

        // burn IERC20(_ticket).balanceOf(msg.sender)
        ICallitTicket cTicket = ICallitTicket(_ticket);
        cTicket.burnForWinClaim(msg.sender, cTicket.balanceOf(msg.sender));

        // log caller's review of market results
        _logMarketResultReview(mark, _resultAgree); // emits MarketReviewed
        
        // LEFT OFF HERE .. emit even log        
    }
    function claimVoterRewards() external { // _deductVoterClaimFees from usdRewardOwed
        // NOTE: loops through all non-piad msg.sender votes (including 'live' markets)
        require(ACCT_MARKET_VOTES[msg.sender].length > 0, ' no un-paid market votes :) ');
        uint64 usdRewardOwed = 0;
        for (uint64 i = 0; i < ACCT_MARKET_VOTES[msg.sender].length;) { // uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
            MARKET_VOTE storage m_vote = ACCT_MARKET_VOTES[msg.sender][i];
            (MARKET storage mark,) = _getMarketForTicket(m_vote.marketMaker, m_vote.voteResultToken); // reverts if market not found | address(0)

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
        usdRewardOwed = usdRewardOwed - _perc_of_uint64(PERC_VOTE_CLAIM_FEE, usdRewardOwed);
        _payUsdReward(usdRewardOwed, msg.sender); // pay w/ lowest value whitelist stable held (returns on 0 reward)
        // LEFT OFF HERE ... need emit event log
        // emit PromoRewardPaid(_promoCodeHash, usdReward, promo.promotor, msg.sender, _ticket);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (CALLIT)
    /* -------------------------------------------------------- */
    function _logMarketResultReview(MARKET storage _mark, bool _resultAgree) private {
        uint64 agreeCnt = 0;
        uint64 disagreeCnt = 0;
        uint64 reviewCnt = _uint64_from_uint256(ACCT_MARKET_REVIEWS[_mark.maker].length);
        if (reviewCnt > 0) {
            agreeCnt = ACCT_MARKET_REVIEWS[_mark.maker][reviewCnt-1].agreeCnt;
            disagreeCnt = ACCT_MARKET_REVIEWS[_mark.maker][reviewCnt-1].disagreeCnt;
        }

        agreeCnt = _resultAgree ? agreeCnt+1 : agreeCnt;
        disagreeCnt = !_resultAgree ? disagreeCnt+1 : disagreeCnt;
        ACCT_MARKET_REVIEWS[_mark.maker].push(MARKET_REVIEW(msg.sender, _resultAgree, _mark.maker, _mark.marketNum, agreeCnt, disagreeCnt));
        emit MarketReviewed(msg.sender, _resultAgree, _mark.maker, _mark.marketNum, agreeCnt, disagreeCnt);
    }
    function _perc_total_supply_owned(address _token, address _account) private view returns (uint64) {
        uint256 accountBalance = IERC20(_token).balanceOf(_account);
        uint256 totalSupply = IERC20(_token).totalSupply();

        // Prevent division by zero by checking if totalSupply is greater than zero
        require(totalSupply > 0, "Total supply must be greater than zero");

        // Calculate the percentage (in basis points, e.g., 1% = 100 basis points)
        uint256 percentage = (accountBalance * 10000) / totalSupply;

        return _uint64_from_uint256(percentage); // Returns the percentage in basis points (e.g., 500 = 5%)
    }
    function _moveMarketVoteIdxToPaid(MARKET_VOTE storage _m_vote, uint64 _idxMove) private {
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
    function _getWinningVoteIdxForMarket(MARKET storage _mark) private view returns(uint16) { // should be 'view' not 'pure'?
        // travers mark.resultTokenVotes for winning idx
        //  NOTE: default winning index is 0 & ties will settle on lower index
        uint16 idxCurrHigh = 0;
        for (uint16 i = 0; i < _mark.marketResults.resultTokenVotes.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            if (_mark.marketResults.resultTokenVotes[i] > _mark.marketResults.resultTokenVotes[idxCurrHigh])
                idxCurrHigh = i;
            unchecked {i++;}
        }
        return idxCurrHigh;
    }
    function _addressIsMarketMakerOrCaller(address _addr, MARKET storage _mark) private view returns(bool, bool) {
        bool is_maker = _mark.maker == msg.sender; // true = found maker
        bool is_caller = false;
        for (uint16 i = 0; i < _mark.marketResults.resultOptionTokens.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            is_caller = IERC20(_mark.marketResults.resultOptionTokens[i]).balanceOf(_addr) > 0; // true = found caller
            unchecked {i++;}
        }
        return (is_maker, is_caller);
    }
    function _mintCallToksEarned(address _receiver, uint64 _callAmnt) private {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        _mint(_receiver, _callAmnt);
        EARNED_CALL_VOTES[_receiver] += _callAmnt;

        // LEFT OFF HERE ... need emit even log
    }
    function _validVoteCount(address _voter, MARKET storage _mark) private view returns(uint64) {
        // if indeed locked && locked before _mark start time, calc & return active vote count
        if (ACCT_CALL_VOTE_LOCK_TIME[_voter] > 0 && ACCT_CALL_VOTE_LOCK_TIME[_voter] <= _mark.blockTimestamp) {
            uint64 votes_earned = EARNED_CALL_VOTES[_voter]; // note: EARNED_CALL_VOTES stores uint64 type
            uint64 votes_held = _uint64_from_uint256(balanceOf(address(this)));
            uint64 votes_active = votes_held >= votes_earned ? votes_earned : votes_held;
            return votes_active;
        }
        else
            return 0; // return no valid votes
    }
    function _payUsdReward(uint64 _usdReward, address _receiver) private {
        if (_usdReward == 0) {
            emit AlertZeroReward(msg.sender, _usdReward, _receiver);
            return;
        }
        // Get stable to work with ... (any stable that covers 'usdReward' is fine)
        //  NOTE: if no single stable can cover 'usdReward', lowStableHeld == 0x0, 
        address lowStableHeld = _getStableHeldLowMarketValue(_usdReward, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        require(lowStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // pay _receiver their usdReward w/ lowStableHeld (any stable thats covered)
        IERC20(lowStableHeld).transfer(_receiver, _usdReward);
            // LEFT OFF HERE ... need to validate decimals for lowStableHeld and usdReward
    }
    function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) private returns(uint256, address){
        // Get stable to work with ... (any stable that covers '_usdAmnt' is fine)
        //  NOTE: if no single stable can cover '_usdAmnt', highStableHeld == 0x0, 
        address highStableHeld = _getStableHeldHighMarketValue(_usdAmnt, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        require(highStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // create path and perform stable-to-stable swap
        // address[2] memory stab_stab_path = [highStableHeld, _tickStable];
        address[] memory stab_stab_path = new address[](3);
        stab_stab_path[0] = highStableHeld;
        stab_stab_path[1] = _tickStable;
        uint256 stab_amnt_out = _exeSwapTokForStable(_usdAmnt, stab_stab_path, address(this)); // no tick: use best from USWAP_V2_ROUTERS
        return (stab_amnt_out,highStableHeld);
    }
    function _isAddressInArray(address _addr, address[] memory _addrArr) private pure returns(bool) {
        for (uint8 i = 0; i < _addrArr.length;){ // max array size = 255 (uin8 loop)
            if (_addrArr[i] == _addr)
                return true;
            unchecked {i++;}
        }
        return false;
    }
    function _getCallTicketUsdTargetPrice(MARKET storage _mark, address _ticket) private view returns(uint64) {
        // algorithmic logic ...
        //  calc sum of usd value dex prices for all addresses in '_mark.resultOptionTokens' (except _ticket)
        //   -> input _ticket target price = 1 - SUM(all prices except _ticket)
        //   -> if result target price <= 0, then set/return input _ticket target price = $0.01

        address[] memory tickets = _mark.marketResults.resultOptionTokens;
        uint64 alt_sum = 0;
        for(uint16 i=0; i < tickets.length;) { // MAX_RESULTS is uint16
            if (tickets[i] != _ticket) {
                address pairAddress = _mark.marketResults.resultTokenLPs[i];
                uint64 amountsOut = _estimateLastPriceForTCK(pairAddress, _mark.marketResults.resultTokenUsdStables[i]);
                alt_sum += amountsOut; // LEFT OFF HERE ... may need to account for differnt stable deimcals
            }
            
            unchecked {i++;}
        }

        // NOTE: returns negative if alt_sum is greater than 1
        //  edge case should be handle in caller
        int64 target_price = 1 - int64(alt_sum);
        return target_price > 0 ? uint64(target_price) : MIN_USD_CALL_TICK_TARGET_PRICE; // note: min is likely 10000 (ie. $0.010000 w/ _usd_decimals() = 6)
    }
    function _getMarketForTicket(address _maker, address _ticket) private view returns(MARKET storage, uint16) {
        require(_maker != address (0) && _ticket != address(0), ' no address for market ;:[=] ');

        // NOTE: MAX_EOA_MARKETS is uint64
        MARKET[] storage markets = ACCT_MARKETS[_maker];
        for (uint64 i = 0; i < markets.length;) {
            MARKET storage mark = markets[i];
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
    // function _deductPrizePoolVoterFees(uint64 _usdAmnt, uint64 _net_usdAmnt) private returns(uint64) {
    //     mark.marketUsdAmnts.usdVoterRewardPool = _perc_of_uint64(PERC_PRIZEPOOL_VOTERS, _usdAmnt);
    //     return _net_usdAmnt - _perc_of_uint64(PERC_PRIZEPOOL_VOTERS, _usdAmnt);
    // }
    function _deductFeePerc(uint64 _net_usdAmnt, uint16 _feePerc, uint64 _usdAmnt) private pure returns(uint64) {
        require(_feePerc <= 10000, ' invalid fee perc :p '); // 10000 = 100.00%
        return _net_usdAmnt - _perc_of_uint64(_feePerc, _usdAmnt);
    }
    // function _deductVoterClaimFees(uint64 _usdAmnt, uint64 _net_usdAmnt) private pure returns(uint64){
    //     // NOTE: no other deductions yet from _usdAmnt
    //     uint8 feePerc0; // = global
    //     uint8 feePerc1; // = global
    //     uint8 feePerc2; // = global
    //     uint64 net_usdAmnt = _net_usdAmnt - (feePerc0 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc1 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc2 * _usdAmnt);
    //     return net_usdAmnt;
    //     // LEFT OFF HERE ... need globals for above and need decimal conversion consideration (maybe)
    // }
    // function _deductMarketCloseFees(uint64 _usdAmnt, uint64 _net_usdAmnt) private pure returns(uint64){
    //     // NOTE: PERC_PRIZEPOOL_VOTERS already deducted from _usdAmnt
    //     // NOTE: for naming convention should use 'PERC_PRIZEPOOL_...' just like 'PERC_PRIZEPOOL_VOTERS'
    //     uint8 feePerc0; // = global
    //     uint8 feePerc1; // = global
    //     uint8 feePerc2; // = global
    //     uint64 net_usdAmnt = _net_usdAmnt - (feePerc0 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc1 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc2 * _usdAmnt);
    //     return net_usdAmnt;
    //     // LEFT OFF HERE ... need globals for above and need decimal conversion consideration (maybe)
    // }
    // function _deductMarketMakerFees(uint64 _usdAmnt, uint64 _net_usdAmnt) private returns(uint64){
    // // function _deductMarketMakerFees(uint64 _usdAmnt) private pure returns(uint64){
    //     // NOTE: no other deductions yet from _usdAmnt
    //     uint8 feePerc0; // = global
    //     // uint8 feePerc1; // = global
    //     // uint8 feePerc2; // = global
    //     // uint64 net_usdAmnt = _usdAmnt - (feePerc0 * _usdAmnt);
    //     // net_usdAmnt = net_usdAmnt - (feePerc1 * _usdAmnt);
    //     // net_usdAmnt = net_usdAmnt - (feePerc2 * _usdAmnt);
    //     // return net_usdAmnt;
    //     return _usdAmnt - (feePerc0 * _usdAmnt);
    //     // LEFT OFF HERE ... need globals for above and need decimal conversion consideration (maybe)
    // }
    // function _deductArbExeFees(uint64 _usdAmnt, uint64 _net_usdAmnt) private pure returns(uint64){
    //     // NOTE: no other deductions yet from _usdAmnt
    //     uint8 feePerc0; // = global
    //     uint8 feePerc1; // = global
    //     uint8 feePerc2; // = global
    //     uint64 net_usdAmnt = _net_usdAmnt - (feePerc0 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc1 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc2 * _usdAmnt);
    //     return net_usdAmnt;
    //     // LEFT OFF HERE ... need globals for above and need decimal conversion consideration (maybe)
    // }
    // function _deductPromoBuyFees(uint64 _usdAmnt, uint64 _net_usdAmnt) private pure returns(uint64){
    //     // NOTE: promo.percReward already deducted from _usdAmnt
    //     uint8 feePerc0; // = global
    //     uint8 feePerc1; // = global
    //     uint8 feePerc2; // = global
    //     uint64 net_usdAmnt = _net_usdAmnt - (feePerc0 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc1 * _usdAmnt);
    //     net_usdAmnt = net_usdAmnt - (feePerc2 * _usdAmnt);
    //     return net_usdAmnt;
    //     // LEFT OFF HERE ... need globals for above and need decimal conversion consideration (maybe)
    // }
    function _genTokenNameSymbol(address _maker, uint256 _markNum, uint16 _resultNum, string storage _nameSeed, string storage _symbSeed) private pure returns(string memory, string memory) { 
        // Concatenate to form symbol & name
        // string memory last4 = _getLast4Chars(_maker);
        // Convert the last 2 bytes (4 characters) of the address to a string
        bytes memory addrBytes = abi.encodePacked(_maker);
        bytes memory last4 = new bytes(4);

        last4[0] = addrBytes[18];
        last4[1] = addrBytes[19];
        last4[2] = addrBytes[20];
        last4[3] = addrBytes[21];

        // return string(last4);
        // string memory tokenSymbol = string(abi.encodePacked(_nameSeed, last4, _markNum, string(abi.encodePacked(_resultNum))));
        // string memory tokenName = string(abi.encodePacked(_symbSeed, " ", last4, "-", _markNum, "-", string(abi.encodePacked(_resultNum))));
        // return (tokenName, tokenSymbol);

        return (string(abi.encodePacked(_nameSeed, last4, _markNum, string(abi.encodePacked(_resultNum)))), string(abi.encodePacked(_symbSeed, " ", last4, "-", _markNum, "-", string(abi.encodePacked(_resultNum)))));
    }
    // function _genTokenNameSymbol(address _maker, uint64 _markNum, uint16 _resultNum, string calldata _nameSeed, string calldata _symbSeed) private view returns(string memory, string memory) {
    //     // Convert the address to a string
    //     // string memory addrStr = toAsciiString(_maker);

    //     // // Extract the first 4 characters (excluding the "0x" prefix)
    //     // // string memory first4 = substring(addrStr, 2, 6);
        
    //     // // Extract the last 4 characters using length
    //     // // string memory last4 = substring(addrStr, 38, 42);
    //     // uint len = bytes(addrStr).length;
    //     // string memory last4 = substring(addrStr, len - 4, len);

    //     // Concatenate to form symbol & name
    //     string memory last4 = _getLast4Chars(_maker);
    //     // string memory tokenSymbol = append(TOK_TICK_NAME_SEED, last4, string(abi.encodePacked(_markNum)), string(abi.encodePacked(_resultNum)), 'heallo');
    //     string memory tokenSymbol = string(abi.encodePacked(_nameSeed, last4, _markNum, string(abi.encodePacked(_resultNum))));
    //     string memory tokenName = string(abi.encodePacked(_symbSeed, " ", last4, "-", _markNum, "-", string(abi.encodePacked(_resultNum))));
    //     // string memory tokenSymbol = string(abi.encodePacked(TOK_TICK_NAME_SEED, last4, _markNum, Strings.toString(_resultNum)));
    //     // string memory tokenName = string(abi.encodePacked(TOK_TICK_SYMB_SEED, last4, "-", _markNum, "-", Strings.toString(_resultNum)));

    //     return (tokenName, tokenSymbol);
    // }
    // function _getLast4Chars(address _addr) public pure returns (string memory) {
    //     // Convert the last 2 bytes (4 characters) of the address to a string
    //     bytes memory addrBytes = abi.encodePacked(_addr);
    //     bytes memory last4 = new bytes(4);

    //     last4[0] = addrBytes[18];
    //     last4[1] = addrBytes[19];
    //     last4[2] = addrBytes[20];
    //     last4[3] = addrBytes[21];

    //     return string(last4);
    // }

    // Assumed helper functions (implementations not shown)
    function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) private returns (address) {
        // LEFT OFF HERE ... _usdStable & _usdAmount must check and convert to use correct decimals
        //          need to properly set & use: uniswapRouter & uniswapFactory

        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(_uswapV2Router);
        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(_uswapv2Factory);

        // Approve tokens for Uniswap Router
        IERC20(_token).approve(_uswapV2Router, _tokenAmount);
        // Assuming you have a way to convert USD to ETH or a stablecoin in the contract
            
        // Add liquidity to the pool
        // (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter.addLiquidity(
        uniswapRouter.addLiquidity(
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

    function _getAmountsForInitLP(uint256 _usdAmntLP, uint256 _resultOptionCnt, uint32 _tokPerUsd) private pure returns(uint64, uint256) {
        require (_usdAmntLP > 0 && _resultOptionCnt > 0 && _tokPerUsd > 0, ' uint == 0 :{} ');
        return (_uint64_from_uint256(_usdAmntLP / _resultOptionCnt), uint256((_usdAmntLP / _resultOptionCnt) * _tokPerUsd));
    }
    function _validNonWhiteSpaceString(string calldata _s) private pure returns(bool) {
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
    function _generateAddressHash(address host, string memory uid) private pure returns (address) {
        // Concatenate the address and the string, and then hash the result
        bytes32 hash = keccak256(abi.encodePacked(host, uid));

        // LEFT OFF HERE ... is this a bug? 'uint160' ? shoudl be uint16? 
        address generatedAddress = address(uint160(uint256(hash)));
        return generatedAddress;
    }
    function _calculateTokensToMint(address pairAddress, uint targetPrice) private view returns (uint256) {
        // Assuming reserve0 is token and reserve1 is USD
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pairAddress).getReserves();

        // LEFT OFF HERE ... may need to compensate for different stable decimals
        //  *WARNING* need to consider this

        uint256 currentPrice = uint256(reserve1) * 1e18 / uint256(reserve0);
        require(targetPrice < currentPrice, "Target price must be less than current price.");

        // Calculate the amount of tokens to mint
        uint256 tokensToMint = (uint256(reserve1) * 1e18 / targetPrice) - uint256(reserve0);

        return tokensToMint;
    }
    // Option 1: Estimate the price using reserves
    function _estimateLastPriceForTCK(address _pairAddress, address _pairStable) private view returns (uint64) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(_pairAddress).getReserves();
        
        // Assuming token0 is the ERC20 token and token1 is the paired asset (e.g., ETH or a stablecoin)
        uint256 price = reserve1 * 1e18 / reserve0; // 1e18 for consistent decimals if token1 is ETH or a stablecoin
        
        // convert to contract '_usd_decimals()'
        uint64 price_ret = _uint64_from_uint256(_normalizeStableAmnt(USD_STABLE_DECIMALS[_pairStable], price, _usd_decimals()));
        return price_ret;
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
            // LEFT OFF HERE .. potential old bug (need to account for decimals of usdStable), potential fix ...
            // uint64 amntConvert = _uint64_from_uint256(_normalizeStableAmnt(USD_STABLE_DECIMALS[usdStable], stableAmntOut, _usd_decimals()));

        ACCT_USD_BALANCES[msg.sender] += amntConvert;
        ACCOUNTS = _addAddressToArraySafe(msg.sender, ACCOUNTS, true); // true = no dups

        emit DepositReceived(msg.sender, amntIn, amntConvert);
    }
    
    // // handle account payouts
    // //  NOTE: _usdValue must be in uint precision to address(this) '_usd_decimals()'
    // function payOutBST(uint64 _usdValue, address _payTo, address _auxToken, bool _selAuxPay) external {
    //     // NOTE: payOutBST runs multiple loops embedded (not analyzed yet, but less than BST legacy)        
    //     //  invokes _getStableHeldLowMarketValue -> _getStableTokenLowMarketValue -> _best_swap_v2_router_idx_quote
    //     //  invokes _exeTokBuyBurn -> _exeSwapStableForTok -> _best_swap_v2_router_idx_quote
    //     //  invokes _exeBstPayout -> _exeSwapStableForTok -> _best_swap_v2_router_idx_quote

    //     // ACCT_USD_BALANCES stores uint precision to 6 decimals
    //     require(_usdValue > 0, ' 0 _usdValue :[] ');
    //     require(ACCT_USD_BALANCES[msg.sender] >= _usdValue, ' low acct balance :{} ');
    //     require(_payTo != address(0), ' _payTo 0 address :( ');

    //     // calc & remove usd service fee value & pLUSD burn value (in usd)
    //     uint64 usdFee = _perc_of_uint64(PERC_SERVICE_FEE, _usdValue);
    //     uint64 usdAuxBurnVal = _perc_of_uint64(PERC_AUX_BURN, _usdValue);
    //     uint64 usdPayout = _usdValue - usdFee - usdAuxBurnVal; 
    //         // NOTE: usdPayout not used (ie. if usdPayout != 0, then that amount is simply left in the contract)
        
    //     // NOTE: integration runs 3 embedded loops 
    //     //  get whitelist stables with holdings that can cover usdPayout
    //     //  then choose stable with lowest market value (ie. contract holds high market val stables)
    //     // NOTE: lowStableHeld could possibly equal address(0x0)
    //     //  this is indeed ok as '_exeBstPayout' & '_exeTokBuyBurn' checks for this (falls back to mint | reverts)
    //     address lowStableHeld = _getStableHeldLowMarketValue(usdPayout, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
    //     // address highStableHeld = _getStableHeldHighMarketValue(usdPayout, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded

    //     // exe buy & burn w/ burnToken
    //     //  set burnToken to pLUSD or _auxToken (depends on ENABLE_TOK_BURN_LOCK)
    //     //  generate swap path: USD->burnToken (go through WPLS required)
    //     //  NOTE: _exeTokBuyBurn reverts if burnToken == address(0) in usd_tok_burn_path
    //     address burnToken = ENABLE_TOK_BURN_LOCK ? TOK_BURN_LOCK : _auxToken;
    //     address[] memory usd_tok_burn_path = new address[](3);
    //     usd_tok_burn_path[0] = lowStableHeld;
    //     usd_tok_burn_path[1] = TOK_WPLS;
    //     usd_tok_burn_path[2] = burnToken;
    //     (uint64 usdBurnValAux, uint256 LUSDstPayoutAmnt) = _exeTokBuyBurn(usdAuxBurnVal, usd_tok_burn_path, _selAuxPay, _payTo);
            
    //     // mint exactly the 'burnAmnt' (for payout)
    //     // if ENABLE_MARKET_BUY, pay from market buy
    //     _exeBstPayout(_payTo, LUSDstPayoutAmnt, usdBurnValAux, lowStableHeld);

    //     // update account balance, ACCT_USD_BALANCES stores uint precision to 6 decimals
    //     ACCT_USD_BALANCES[msg.sender] -= _usdValue; // _usdValue 'require' check above

    //     // log this payout, ACCT_USD_PAYOUTS stores uint precision to 6 decimals
    //     ACCT_USD_PAYOUTS[msg.sender].push(ACCT_PAYOUT(_payTo, _usdValue, usdPayout, LUSDstPayoutAmnt, usdFee, usdBurnValAux, 0, usdAuxBurnVal, burnToken, RATIO_BST_PAYOUT, block.number));
    //     emit PayOutProcessed(msg.sender, _payTo, _usdValue, usdPayout, LUSDstPayoutAmnt, usdFee, usdBurnValAux, 0, usdAuxBurnVal, burnToken, RATIO_BST_PAYOUT, block.number);
    // }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (legacy)
    /* -------------------------------------------------------- */
    // function _setUsdBstPath(address _usdStable, address[] memory _path) private {
    //     require(_usdStable != address(0) && _path.length > 1, ' invalid inputs ;{=} ');
    //     require(_usdStable == _path[0], ' stable / entry path mismatch ;) ');
    //     USD_BST_PATHS[_usdStable] = _path;
    //     emit DexUsdBstPathUpdated(_usdStable, _path);
    //     // NOTE: '_path' must be valid within all 'USWAP_V2_ROUTERS' addresses
    // }
    // function _setSwapDelegate(address _swapd) private {
    //     require(_swapd != address(0), ' 0 address ;-( ');
    //     address prev = address(SWAP_DELEGATE);
    //     SWAP_DELEGATE = _swapd;
    //     SWAPD = ISwapDelegate(SWAP_DELEGATE);
    //     if (SWAPD.USER_INIT()) {
    //         SWAPD.USER_setUser(address(this)); // first call to _setUser can set user w/o keeper
    //     }
    //     emit SwapDelegateUpdated(prev, SWAP_DELEGATE);
    // }
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
        (, uint256 tok_amnt) = _best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);
        return tok_amnt; 
    }
    function _perc_of_uint64(uint32 _perc, uint64 _num) private pure returns (uint64) {
        require(_perc <= 10000, 'err: invalid percent');
        // return _perc_of_uint64_unchecked(_perc, _num);
        return (_num * uint64(uint32(_perc) * 100)) / 1000000; // chatGPT equation
    }
    function _perc_of_uint64_unchecked(uint32 _perc, uint64 _num) private pure returns (uint64) {
        // require(_perc <= 10000, 'err: invalid percent');
        // uint32 aux_perc = _perc * 100; // Multiply by 100 to accommodate decimals
        // uint64 result = (_num * uint64(aux_perc)) / 1000000; // chatGPT equation
        // return result; // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)

        // NOTE: more efficient with no local vars allocated
        return (_num * uint64(uint32(_perc) * 100)) / 1000000; // chatGPT equation
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
        (uint8 rtrIdx,) = _best_swap_v2_router_idx_quote(pls_stab_path, _plsAmnt, USWAP_V2_ROUTERS);
        uint256 stab_amnt_out = _swap_v2_wrap(pls_stab_path, USWAP_V2_ROUTERS[rtrIdx], _plsAmnt, address(this), true); // true = fromETH
        stab_amnt_out = _normalizeStableAmnt(USD_STABLE_DECIMALS[_usdStable], stab_amnt_out, _usd_decimals());
        return stab_amnt_out;
    }
    // specify router to use
    function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        uint256 tok_amnt_out = _swap_v2_wrap(_tok_stab_path, _router, _tokAmnt, _receiver, false); // true = fromETH
        return tok_amnt_out;
    }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapTokForStable(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        
        (uint8 rtrIdx,) = _best_swap_v2_router_idx_quote(_tok_stab_path, _tokAmnt, USWAP_V2_ROUTERS);
        uint256 stable_amnt_out = _swap_v2_wrap(_tok_stab_path, USWAP_V2_ROUTERS[rtrIdx], _tokAmnt, _receiver, false); // true = fromETH        
        return stable_amnt_out;
    }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) private returns (uint256) {
        address usdStable = _stab_tok_path[0]; // required: _stab_tok_path[0] must be a stable
        uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[usdStable]);
        (uint8 rtrIdx,) = _best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);

        // NOTE: algo to account for contracts unable to be a receiver of its own token in UniswapV2Pool.sol
        // if out token in _stab_tok_path is BST, then swap w/ SWAP_DELEGATE as reciever,
        //   and then get tok_amnt_out from delegate (USER_maintenance)
        // else, swap with BST address(this) as receiver 
        // if (_stab_tok_path[_stab_tok_path.length-1] == address(this) && _receiver == address(this))  {
        //     uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, SWAP_DELEGATE, false); // true = fromETH
        //     SWAPD.USER_maintenance(tok_amnt_out, _stab_tok_path[_stab_tok_path.length-1]);
        //     return tok_amnt_out;
        // } else {
        //     uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
        //     return tok_amnt_out;
        // }

        uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
        return tok_amnt_out;
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
            (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
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
            (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
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
    function _swap_v2_quote(address[] memory _path, address _dexRouter, uint256 _amntIn) private view returns (uint256) {
        uint256[] memory amountsOut = IUniswapV2Router02(_dexRouter).getAmountsOut(_amntIn, _path); // quote swap
        return amountsOut[amountsOut.length -1];
    }
    // uniwswap v2 protocol based: get quote and execute swap
    function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) private returns (uint256) {
        require(path.length >= 2, 'err: path.length :/');
        uint256 amntOutQuote = _swap_v2_quote(path, router, amntIn);
        uint256 amntOut = _swap_v2(router, path, amntIn, amntOutQuote, outReceiver, fromETH); // approve & execute swap
                
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
        require(ACCT_CALL_VOTE_LOCK_TIME[msg.sender] == 0, ' tokens locked ;) ');
        if (from != address(this)) {
            return super.transferFrom(from, to, value);
        } else {
            _transfer(from, to, value); // balance checks, etc. indeed occur
        }
        return true;
    }
    function transfer(address to, uint256 value) public override returns (bool) {
        require(ACCT_CALL_VOTE_LOCK_TIME[msg.sender] == 0, ' tokens locked ;0 ');
        return super.transfer(to, value);
    }
}
