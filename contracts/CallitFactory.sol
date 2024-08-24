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
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy

// local _ $ npm install @openzeppelin/contracts
// import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./CallitTicket.sol";
import "./ICallitLib.sol";
import "./ICallitVault.sol";

interface ICallitTicket {
    function mintForPriceParity(address _receiver, uint256 _amount) external;
    function burnForWinLoseClaim(address _account, uint256 _amount) external;
    function balanceOf(address account) external returns(uint256);
}

// contract CallitFactory is ERC20, Ownable {
contract CallitFactory {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    /* _ ADMIN SUPPORT (legacy) _ */
    address public KEEPER;
    // uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    string public tVERSION = '0.7';
    string private TOK_SYMB = string(abi.encodePacked("tCALL", tVERSION));
    string private TOK_NAME = string(abi.encodePacked("tCALL-IT_", tVERSION));
    // string private TOK_SYMB = "CALL";
    // string private TOK_NAME = "CALL-IT";

    /* GLOBALS (CALLIT) */
    address public LIB_ADDR = address(0x657428d6E3159D4a706C00264BD0DdFaf7EFaB7e); // CallitLib v1.0
    address public VAULT_ADDR = address(0xa8667527F00da10cadE9533952e069f5209273c2); // CallitVault v0.4
    ICallitLib   private LIB = ICallitLib(LIB_ADDR);
    ICallitVault private VAULT = ICallitVault(VAULT_ADDR);

    // note: makeNewMarket
    // call ticket token settings (note: init supply -> RATIO_LP_TOK_PER_USD)
    // address public NEW_TICK_UNISWAP_V2_ROUTER;
    // address public NEW_TICK_UNISWAP_V2_FACTORY;
    // address public NEW_TICK_USD_STABLE;
    // string  public TOK_TICK_NAME_SEED = "TCK#";
    // string  public TOK_TICK_SYMB_SEED = "CALL-TICKET";

    // arb algorithm settings
    uint64 public MIN_USD_CALL_TICK_TARGET_PRICE = 10000; // 10000 == $0.010000 -> likely always be min (ie. $0.01 w/ _usd_decimals() = 6 decimals)

    // market settings
    bool    public USE_SEC_DEFAULT_VOTE_TIME = true; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    uint256 public SEC_DEFAULT_VOTE_TIME = 24 * 60 * 60; // 24 * 60 * 60 == 86,400 sec == 24 hours
    uint16  public MAX_RESULTS = 10; // max # of result options a market may have (uint16 max = ~65K -> 65,535)
    uint64  public MAX_EOA_MARKETS = type(uint8).max; // uint8 = 255 (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)
        // NOTE: additional launch security: caps EOA $CALL earned to 255
        //  but also limits the EOA following (KEEPER setter available; should raise after launch)
    
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

    // note: makeNewMarket
    // // temp-arrays for 'makeNewMarket' support
    // address[] private resultOptionTokens;
    // address[] private resultTokenLPs;
    // address[] private resultTokenRouters;
    // address[] private resultTokenFactories;
    // address[] private resultTokenUsdStables;
    // uint64 [] private resultTokenVotes;
    
    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // // legacy
    // event KeeperTransfer(address _prev, address _new);
    // event TokenNameSymbolUpdated(string TOK_NAME, string TOK_SYMB);
    // event DepositReceived(address _account, uint256 _plsDeposit, uint64 _stableConvert);

    // // callit
    // event MarketCreated(address _maker, uint256 _markNum, string _name, uint64 _usdAmntLP, uint256 _dtCallDeadline, uint256 _dtResultVoteStart, uint256 _dtResultVoteEnd, string[] _resultLabels, address[] _resultOptionTokens, uint256 _blockTime, bool _live);
    // event PromoCreated(address _promoHash, address _promotor, string _promoCode, uint64 _usdTarget, uint64 usdUsed, uint8 _percReward, address _creator, uint256 _blockNumber);
    // event PromoBuyPerformed(address _buyer, address _promoCodeHash, address _usdStable, address _ticket, uint64 _grossUsdAmnt, uint64 _netUsdAmnt, uint256  _tickAmntOut);
    // event MarketReviewed(address _caller, bool _resultAgree, address _marketMaker, uint256 _marketNum, uint64 _agreeCnt, uint64 _disagreeCnt);
    // event ArbPriceCorrectionExecuted(address _executer, address _ticket, uint64 _tickTargetPrice, uint64 _tokenMintCnt, uint64 _usdGrossReceived, uint64 _usdTotalPaid, uint64 _usdNetProfit, uint64 _callEarnedAmnt);
    // event MarketCallsClosed(address _executer, address _ticket, address _marketMaker, uint256 _marketNum, uint64 _usdAmntPrizePool, uint64 _callEarnedAmnt);
    // event MarketClosed(address _sender, address _ticket, address _marketMaker, uint256 _marketNum, uint64 _winningResultIdx, uint64 _usdPrizePoolPaid, uint64 _usdVoterRewardPoolPaid, uint64 _usdRewardPervote, uint64 _callEarnedAmnt);
    // event TicketClaimed(address _sender, address _ticket, bool _is_winner, bool _resultAgree);
    // event VoterRewardsClaimed(address _claimer, uint64 _usdRewardOwed, uint64 _usdRewardOwed_net);
    // event CallTokensEarned(address _sedner, address _receiver, uint64 _callAmntEarned, uint64 _callPrevBal, uint64 _callCurrBal);

    // /* -------------------------------------------------------- */
    // /* STRUCTS (CALLIT)
    // /* -------------------------------------------------------- */

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR (legacy)
    /* -------------------------------------------------------- */
    // NOTE: sets msg.sender to '_owner' ('Ownable' maintained)
    // constructor(uint256 _initSupply) ERC20(TOK_NAME, TOK_SYMB) Ownable(msg.sender) {     
    constructor(uint256 _initSupply) {     
        // set FACT_ADDR in VAULT
        VAULT.INIT_factory();

        // set default globals
        KEEPER = msg.sender;
        // _mint(msg.sender, _initSupply * 10**uint8(decimals())); // 'emit Transfer'

        // NOTE: whitelist stable & dex routers set in VAULT constructor
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
    function KEEPER_setKeeper(address _newKeeper) external onlyKeeper {
        require(_newKeeper != address(0), 'err: 0 address');
        address prev = address(KEEPER);
        KEEPER = _newKeeper;
      //  emit KeeperTransfer(prev, KEEPER);
    }
    function KEEPER_setTokNameSymb(string memory _tok_name, string memory _tok_symb) external onlyKeeper() {
        require(bytes(_tok_name).length > 0 && bytes(_tok_symb).length > 0, ' invalid input  :<> ');
        TOK_NAME = _tok_name;
        TOK_SYMB = _tok_symb;
      //  emit TokenNameSymbolUpdated(TOK_NAME, TOK_SYMB);
    }
    function KEEPER_setVaultLib(address _vault, address _lib) external onlyKeeper {
        require(_vault != address(0) && _lib != address(0), ' invalid addies :0 ' );
        VAULT_ADDR = _vault;
        VAULT = ICallitVault(_vault);

        LIB_ADDR = _lib;
        LIB = ICallitLib(_lib);
    }
    function KEEPER_editAdmin(address _admin, bool _enable) external onlyKeeper {
        require(_admin != address(0), ' !_admin :{+} ');
        ADMINS[_admin] = _enable;
    }
    function KEEPER_setMarketSettings(uint16 _maxResultOpts, uint64 _maxEoaMarkets, uint64 _minUsdArbTargPrice) external {
        MAX_RESULTS = _maxResultOpts; // max # of result options a market may have
        MAX_EOA_MARKETS = _maxEoaMarkets;
        // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
        MIN_USD_CALL_TICK_TARGET_PRICE = _minUsdArbTargPrice;
    }
    // note: makeNewMarket
    // function KEEPER_setNewTicketEnvironment(address _router, address _factory, address _usdStable, string calldata _nameSeed, string calldata _symbSeed) external onlyKeeper {
    //     // max array size = 255 (uint8 loop)
    //     require(LIB._isAddressInArray(_router, VAULT.USWAP_V2_ROUTERS()) && LIB._isAddressInArray(_usdStable, VAULT.WHITELIST_USD_STABLES()), ' !whitelist router|stable :() ');
    //     NEW_TICK_UNISWAP_V2_ROUTER = _router;
    //     NEW_TICK_UNISWAP_V2_FACTORY = _factory;
    //     NEW_TICK_USD_STABLE = _usdStable;
    //     TOK_TICK_NAME_SEED = _nameSeed;
    //     TOK_TICK_SYMB_SEED = _symbSeed;
    // }
    function KEEPER_setDefaultVoteTime(uint256 _sec, bool _enable) external onlyKeeper {
        SEC_DEFAULT_VOTE_TIME = _sec; // 24 * 60 * 60 == 86,400 sec == 24 hours
        USE_SEC_DEFAULT_VOTE_TIME = _enable; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    }
    // CALLIT admin
    function ADMIN_initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward) external onlyAdmin {
        // no 2 percs taken out of promo buy
        require(VAULT.PERC_PROMO_BUY_FEE() + _percReward < 10000, ' invalid promo buy _perc :(=) ');
        require(_promotor != address(0) && LIB._validNonWhiteSpaceString(_promoCode) && _usdTarget >= VAULT.MIN_USD_PROMO_TARGET(), ' !param(s) :={ ');
        address promoCodeHash = LIB._generateAddressHash(_promotor, _promoCode);
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[promoCodeHash];
        require(promo.promotor == address(0), ' promo already exists :-O ');
        // PROMO_CODE_HASHES[promoCodeHash].push(PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number));
        PROMO_CODE_HASHES[promoCodeHash] = ICallitLib.PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
      //  emit PromoCreated(promoCodeHash, _promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    // CALLIT
    // function getAccountMarkets(address _account) external view returns (ICallitLib.MARKET[] memory) {
    //     require(_account != address(0), ' 0 address? ;[+] ');
    //     return ACCT_MARKETS[_account];
    // }
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

        // send PLS to vault for processing (handle swap for usd stable)
        VAULT.deposit{value: amntIn}(msg.sender);

      //  emit DepositReceived(msg.sender, amntIn, 0);

        // NOTE: at this point, the vault has the deposited stable and the vault has stored accont balances
    }
    function setMyAcctHandle(string calldata _handle) external {
        require(bytes(_handle).length >= 1, ' !_handle.length :[] ');
        require(bytes(_handle)[0] != 0x20, ' !_handle space start :+[ '); // 0x20 -> ASCII for ' ' (single space)
        if (LIB._validNonWhiteSpaceString(_handle))
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
    // function makeNewMarket(string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
    //                         // string calldata _category, 
    //                         // string calldata _rules, 
    //                         // string calldata _imgUrl, 
    //                         uint64 _usdAmntLP, 
    //                         uint256 _dtCallDeadline, 
    //                         uint256 _dtResultVoteStart, 
    //                         uint256 _dtResultVoteEnd, 
    //                         string[] calldata _resultLabels, 
    //                         string[] calldata _resultDescrs
    //                         ) external { 
    //     require(_usdAmntLP >= MIN_USD_MARK_LIQ, ' need more liquidity! :{=} ');
    //     require(VAULT.ACCT_USD_BALANCES(msg.sender) >= _usdAmntLP, ' low balance ;{ ');
    //     require(2 <= _resultLabels.length && _resultLabels.length <= MAX_RESULTS && _resultLabels.length == _resultDescrs.length, ' bad results count :( ');
    //     require(block.timestamp < _dtCallDeadline && _dtCallDeadline < _dtResultVoteStart && _dtResultVoteStart < _dtResultVoteEnd, ' invalid dt settings :[] ');

    //     // initilize/validate market number for struct MARKET tracking
    //     uint256 mark_num = ACCT_MARKETS[msg.sender].length;
    //     require(mark_num <= MAX_EOA_MARKETS, ' > MAX_EOA_MARKETS :O ');
    //     // require(ACCT_MARKETS[msg.sender].length <= MAX_EOA_MARKETS, ' > MAX_EOA_MARKETS :O ');

    //     // deduct 'market maker fees' from _usdAmntLP
    //     uint64 net_usdAmntLP = LIB._deductFeePerc(_usdAmntLP, PERC_MARKET_MAKER_FEE, _usdAmntLP);

    //     // check for admin defualt vote time, update _dtResultVoteEnd accordingly
    //     if (USE_SEC_DEFAULT_VOTE_TIME) _dtResultVoteEnd = _dtResultVoteStart + SEC_DEFAULT_VOTE_TIME;

    //     // Loop through _resultLabels and deploy ERC20s for each (and generate LP)
    //     for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
    //         // Get/calc amounts for initial LP (usd and token amounts)
    //         (uint64 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(net_usdAmntLP, _resultLabels.length, RATIO_LP_TOK_PER_USD);            

    //         // Deploy a new ERC20 token for each result label (init supply = tokenAmount; transfered to VAULT to create LP)
    //         (string memory tok_name, string memory tok_symb) = LIB._genTokenNameSymbol(msg.sender, mark_num, i, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
    //         address new_tick_tok = address (new CallitTicket(tokenAmount, address(VAULT), tok_name, tok_symb));
            
    //         // Create DEX LP for new ticket token (from VAULT, using VAULT's stables, and VAULT's minted new tick init supply)
    //         address pairAddr = VAULT._createDexLP(NEW_TICK_UNISWAP_V2_ROUTER, NEW_TICK_UNISWAP_V2_FACTORY, new_tick_tok, NEW_TICK_USD_STABLE, tokenAmount, usdAmount);

    //         // verify ERC20 & LP was created
    //         require(new_tick_tok != address(0) && pairAddr != address(0), ' err: gen tick tok | lp :( ');

    //         // push this ticket option's settings to storage temp results array
    //         //  temp array will be added to MARKET struct (then deleted on function return)
    //         resultOptionTokens.push(new_tick_tok);
    //         resultTokenLPs.push(pairAddr);

    //         resultTokenRouters.push(NEW_TICK_UNISWAP_V2_ROUTER);
    //         resultTokenFactories.push(NEW_TICK_UNISWAP_V2_FACTORY);
    //         resultTokenUsdStables.push(NEW_TICK_USD_STABLE);
    //         resultTokenVotes.push(0);

    //         // set ticket to maker mapping (additional access support)
    //         TICKET_MAKERS[new_tick_tok] = msg.sender;
    //         unchecked {i++;}
    //     }

    //     // deduct full OG usd input from account balance
    //     // VAULT.ACCT_USD_BALANCES[msg.sender] -= _usdAmntLP;
    //     VAULT.edit_ACCT_USD_BALANCES(msg.sender, _usdAmntLP, false); // false = sub

    //     // save this market and emit log
    //     ACCT_MARKETS[msg.sender].push(ICallitLib.MARKET({maker:msg.sender, 
    //                                             marketNum:mark_num, 
    //                                             name:_name,

    //                                             // marketInfo:MARKET_INFO("", "", ""),
    //                                             category:"",
    //                                             rules:"", 
    //                                             imgUrl:"", 

    //                                             marketUsdAmnts:ICallitLib.MARKET_USD_AMNTS(_usdAmntLP, 0, 0, 0, 0), 
    //                                             marketDatetimes:ICallitLib.MARKET_DATETIMES(_dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd), 
    //                                             marketResults:ICallitLib.MARKET_RESULTS(_resultLabels, _resultDescrs, resultOptionTokens, resultTokenLPs, resultTokenRouters, resultTokenFactories, resultTokenUsdStables, resultTokenVotes), 
    //                                             winningVoteResultIdx:0, 
    //                                             blockTimestamp:block.timestamp, 
    //                                             blockNumber:block.number, 
    //                                             live:true})); // true = live
    //   //  emit MarketCreated(msg.sender, mark_num, _name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, resultOptionTokens, block.timestamp, true); // true = live
        
    //     // Step 4: Clear tempArray (optional)
    //     // delete tempArray; // This will NOT effect whats stored in ACCT_MARKETS
    //     delete resultOptionTokens;
    //     delete resultTokenLPs;
    //     delete resultTokenRouters;
    //     delete resultTokenFactories;
    //     delete resultTokenUsdStables;
    //     delete resultTokenVotes;

    //     // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    // }
    function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt) external { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        require(promo.usdTarget - promo.usdUsed >= _usdAmnt, ' promo expired :( ' );
        require(VAULT.ACCT_USD_BALANCES(msg.sender) >= _usdAmnt, ' low balance ;{ ');

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
        if (_usdAmnt >= VAULT.RATIO_PROMO_USD_PER_CALL_MINT()) {
            // mint $CALL to msg.sender & log $CALL votes earned
            _mintCallToksEarned(msg.sender, _usdAmnt / VAULT.RATIO_PROMO_USD_PER_CALL_MINT()); // emit CallTokensEarned
        }

        // verify perc calc/taking <= 100% of _usdAmnt
        require(promo.percReward + VAULT.PERC_PROMO_BUY_FEE() < 10000, ' buy promo fee perc mismatch :o ');

        // pay promotor usd reward & purchase msg.sender's tickets from DEX
        (uint64 net_usdAmnt, uint256 tick_amnt_out) = VAULT._payPromotorDeductFeesBuyTicket(promo.percReward, _usdAmnt, promo.promotor, _promoCodeHash, _ticket, mark.marketResults.resultTokenUsdStables[tickIdx], VAULT.PERC_PROMO_BUY_FEE(), msg.sender);
        
        // emit log
      //  emit PromoBuyPerformed(msg.sender, _promoCodeHash, mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out);

        // update promo.usdUsed (add full OG input _usdAmnt)
        promo.usdUsed += _usdAmnt;
    }
    function exeArbPriceParityForTicket(address _ticket) external { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint64 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');

        // // calc target usd price for _ticket (in order to bring this market to price parity)
        // //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        // //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        // // uint64 ticketTargetPriceUSD = _getCallTicketUsdTargetPrice(mark, _ticket, MIN_USD_CALL_TICK_TARGET_PRICE);
        // uint64 ticketTargetPriceUSD = VAULT._getCallTicketUsdTargetPrice(mark.marketResults.resultOptionTokens, mark.marketResults.resultTokenLPs, mark.marketResults.resultTokenUsdStables, _ticket, MIN_USD_CALL_TICK_TARGET_PRICE);

        // // (uint64 tokensToMint, uint64 gross_stab_amnt_out, uint64 total_usd_cost, uint64 net_usd_profits) = _performTicketMintaAndDexSell(_ticket, ticketTargetPriceUSD, mark.marketResults.resultTokenUsdStables[tickIdx], mark.marketResults.resultTokenLPs[tickIdx], mark.marketResults.resultTokenRouters[tickIdx], PERC_ARB_EXE_FEE);
        // (uint64 tokensToMint, uint64 total_usd_cost) = VAULT._performTicketMint(mark, tickIdx, ticketTargetPriceUSD, _ticket, msg.sender);
        // (uint64 gross_stab_amnt_out, uint64 net_usd_profits) = VAULT._performTicketMintedDexSell(mark, tickIdx, _ticket, VAULT.PERC_ARB_EXE_FEE(), tokensToMint, total_usd_cost, msg.sender);
        (uint64 ticketTargetPriceUSD, uint64 tokensToMint, uint64 total_usd_cost, uint64 gross_stab_amnt_out, uint64 net_usd_profits) = VAULT.exeArbPriceParityForTicket(mark, tickIdx, TICKET_MAKERS[_ticket], _ticket, MIN_USD_CALL_TICK_TARGET_PRICE);
        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_ARB_EXE()); // emit CallTokensEarned

        // // emit log of this arb price correction
      //  emit ArbPriceCorrectionExecuted(msg.sender, _ticket, ticketTargetPriceUSD, tokensToMint, gross_stab_amnt_out, total_usd_cost, net_usd_profits, callEarnedAmnt);
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
            uint256 amountToken1 = VAULT._exePullLiquidityFromLP(mark.marketResults.resultTokenRouters[i], _ticketLPs[i], mark.marketResults.resultOptionTokens[i], mark.marketResults.resultTokenUsdStables[i]);

            // update market prize pool usd received from LP (usdAmntPrizePool: defualts to 0)
            mark.marketUsdAmnts.usdAmntPrizePool += LIB._uint64_from_uint256(amountToken1); // NOTE: write to market

            unchecked {
                i++;
            }
        }

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS()); // emit CallTokensEarned

        // emit log for this closed market calls event
      //  emit MarketCallsClosed(msg.sender, _ticket, mark.maker, mark.marketNum, mark.marketUsdAmnts.usdAmntPrizePool, callEarnedAmnt);
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
        (bool is_maker, bool is_caller) = LIB._addressIsMarketMakerOrCaller(msg.sender, mark.maker, mark.marketResults.resultOptionTokens);
        require(!is_maker && !is_caller, ' no self-voting :o ');

        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        // uint64 vote_cnt = _validVoteCount(msg.sender, mark);
        // uint64 vote_cnt = LIB._validVoteCount(balanceOf(msg.sender), EARNED_CALL_VOTES[msg.sender], ACCT_CALL_VOTE_LOCK_TIME[msg.sender], mark.blockTimestamp);
        uint64 vote_cnt = 37;
        require(vote_cnt > 0, ' invalid voter :{=} ');

        //  - store vote in struct MARKET
        mark.marketResults.resultTokenVotes[tickIdx] += vote_cnt; // NOTE: write to market

        // log market vote per EOA, so EOA can claim voter fees earned (where votes = "majority of votes / winning result option")
        ACCT_MARKET_VOTES[msg.sender].push(ICallitLib.MARKET_VOTE(msg.sender, _ticket, tickIdx, vote_cnt, mark.maker, mark.marketNum, false)); // false = not paid
            // NOTE: *WARNING* if ACCT_MARKET_VOTES was public, then anyone can see the votes before voting has ended

        // NOTE: do not want to emit event log for casting votes 
        //  this will allow people to see majority votes before voting

        // mint $CALL token reward to msg.sender
        _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_VOTE()); // emit CallTokensEarned
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
        mark.winningVoteResultIdx = LIB._getWinningVoteIdxForMarket(mark.marketResults.resultTokenVotes); // NOTE: write to market

        // validate total % pulling from 'usdVoterRewardPool' is not > 100% (10000 = 100.00%)
        require(VAULT.PERC_PRIZEPOOL_VOTERS() + VAULT.PERC_MARKET_CLOSE_FEE() < 10000, ' perc error ;( ');

        // calc & save total voter usd reward pool (ie. a % of prize pool in mark)
        mark.marketUsdAmnts.usdVoterRewardPool = LIB._perc_of_uint64(VAULT.PERC_PRIZEPOOL_VOTERS(), mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market

        // calc & set net prize pool after taking out voter reward pool (+ other market close fees)
        mark.marketUsdAmnts.usdAmntPrizePool_net = mark.marketUsdAmnts.usdAmntPrizePool - mark.marketUsdAmnts.usdVoterRewardPool; // NOTE: write to market
        mark.marketUsdAmnts.usdAmntPrizePool_net = LIB._deductFeePerc(mark.marketUsdAmnts.usdAmntPrizePool_net, VAULT.PERC_MARKET_CLOSE_FEE(), mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market
        
        // calc & save usd payout per vote ("usd per vote" = usd reward pool / total winning votes)
        mark.marketUsdAmnts.usdRewardPerVote = mark.marketUsdAmnts.usdVoterRewardPool / mark.marketResults.resultTokenVotes[mark.winningVoteResultIdx]; // NOTE: write to market

        // check if mark.maker earned $CALL tokens
        if (mark.marketUsdAmnts.usdAmntLP >= VAULT.RATIO_LP_USD_PER_CALL_TOK()) {
            // mint $CALL to mark.maker & log $CALL votes earned
            _mintCallToksEarned(mark.maker, mark.marketUsdAmnts.usdAmntLP / VAULT.RATIO_LP_USD_PER_CALL_TOK()); // emit CallTokensEarned
        }

        // close market
        mark.live = false; // NOTE: write to market

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_MARK_CLOSE()); // emit CallTokensEarned

        // emit log for closed market
      //  emit MarketClosed(msg.sender, _ticket, mark.maker, mark.marketNum, mark.winningVoteResultIdx, mark.marketUsdAmnts.usdAmntPrizePool_net, mark.marketUsdAmnts.usdVoterRewardPool, mark.marketUsdAmnts.usdRewardPerVote, callEarnedAmnt);

        // $CALL token earnings design...
        //  DONE - buyer earns $CALL in 'buyCallTicketWithPromoCode'
        //  DONE - market maker should earn call when market is closed (init LP requirement needed)
        //  DONE - invoking 'closeMarketCallsForTicket' earns $CALL
        //  DONE - invoking 'closeMarketForTicket' earns $CALL
        //  DONE - market losers can trade-in their tickets for minted $CALL
        // log $CALL votes earned w/ ...
        // EARNED_CALL_VOTES[msg.sender] += (_usdAmnt / RATIO_PROMO_USD_PER_CALL_MINT);
    }
    function claimTicketRewards(address _ticket, bool _resultAgree) external { // _deductFeePerc PERC_WINNER_CLAIM_FEE from usdPrizePoolShare
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
            uint64 usdPerTicket = LIB._uint64_from_uint256(uint256(mark.marketUsdAmnts.usdAmntPrizePool_net) / IERC20(_ticket).totalSupply());
            uint64 usdPrizePoolShare = LIB._uint64_from_uint256(uint256(usdPerTicket) * IERC20(_ticket).balanceOf(msg.sender));

            // send payout to msg.sender
            usdPrizePoolShare = LIB._deductFeePerc(usdPrizePoolShare, VAULT.PERC_WINNER_CLAIM_FEE(), usdPrizePoolShare);
            VAULT._payUsdReward(msg.sender, usdPrizePoolShare, msg.sender);
        } else {
            // NOTE: perc requirement limits ability for exploitation and excessive $CALL minting
            uint64 perc_supply_owned = LIB._perc_total_supply_owned(_ticket, msg.sender);
            if (perc_supply_owned >= VAULT.PERC_OF_LOSER_SUPPLY_EARN_CALL()) {
                // mint $CALL to loser msg.sender & log $CALL votes earned
                _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_LOSER()); // emit CallTokensEarned

                // NOTE: this action could open up a secondary OTC market for collecting loser tickets
                //  ie. collecting losers = minting $CALL
            }
        }

        // burn IERC20(_ticket).balanceOf(msg.sender)
        ICallitTicket cTicket = ICallitTicket(_ticket);
        cTicket.burnForWinLoseClaim(msg.sender, cTicket.balanceOf(msg.sender));

        // log caller's review of market results
        // _logMarketResultReview(mark, _resultAgree); // emits MarketReviewed
        (ICallitLib.MARKET_REVIEW memory marketReview, uint64 agreeCnt, uint64 disagreeCnt) = LIB._logMarketResultReview(mark.maker, mark.marketNum, ACCT_MARKET_REVIEWS[mark.maker], _resultAgree);
        ACCT_MARKET_REVIEWS[mark.maker].push(marketReview);
      //  emit MarketReviewed(msg.sender, _resultAgree, mark.maker, mark.marketNum, agreeCnt, disagreeCnt);
          
        // emit log event for claimed ticket
      //  emit TicketClaimed(msg.sender, _ticket, is_winner, _resultAgree);

        // NOTE: no $CALL tokens minted for this action   
    }
    function claimVoterRewards() external { // _deductFeePerc PERC_VOTER_CLAIM_FEE from usdRewardOwed
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
            if (m_vote.paid) { // NOTE: move this market vote index 'i', to paid
                // add this MARKET_VOTE to ACCT_MARKET_VOTES_PAID[msg.sender]
                // remove _idxMove MARKET_VOTE from ACCT_MARKET_VOTES[msg.sender]
                //  by replacing it with the last element (then popping last element)
                ACCT_MARKET_VOTES_PAID[msg.sender].push(m_vote);
                uint64 lastIdx = uint64(ACCT_MARKET_VOTES[msg.sender].length) - 1;
                if (i != lastIdx) { ACCT_MARKET_VOTES[msg.sender][i] = ACCT_MARKET_VOTES[msg.sender][lastIdx]; }
                ACCT_MARKET_VOTES[msg.sender].pop(); // Remove the last element (now a duplicate)

                // _moveMarketVoteIdxToPaid(m_vote, i); // 082224: removed from call stack
                continue; // Skip 'i++'; continue w/ current idx, to check new item at position 'i'
            }
            unchecked {i++;}
        }

        // deduct fees and pay voter rewards
        uint64 usdRewardOwed_net = LIB._deductFeePerc(usdRewardOwed, VAULT.PERC_VOTER_CLAIM_FEE(), usdRewardOwed);
        VAULT._payUsdReward(msg.sender, usdRewardOwed_net, msg.sender); // pay w/ lowest value whitelist stable held (returns on 0 reward)

        // emit log for rewards claimed
      //  emit VoterRewardsClaimed(msg.sender, usdRewardOwed, usdRewardOwed_net);

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
    function _mintCallToksEarned(address _receiver, uint64 _callAmnt) private returns(uint64) {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        // _mint(_receiver, _callAmnt);
        uint64 prevEarned = EARNED_CALL_VOTES[_receiver];
        EARNED_CALL_VOTES[_receiver] += _callAmnt;

        // emit log for call tokens earned
      //  emit CallTokensEarned(msg.sender, _receiver, _callAmnt, prevEarned, EARNED_CALL_VOTES[_receiver]);
        return EARNED_CALL_VOTES[_receiver];
        // NOTE: call tokens earned on ...
        //  buyCallTicketWithPromoCode
        //  closeMarketForTicket
        //  claimTicketRewards
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
    // function burn(uint64 _burnAmnt) external {
    //     require(_burnAmnt > 0, ' burn nothing? :0 ');
    //     _burn(msg.sender, _burnAmnt); // NOTE: checks _balance[msg.sender]
    // }
    // function decimals() public pure override returns (uint8) {
    //     // return 6; // (6 decimals) 
    //         // * min USD = 0.000001 (6 decimals) 
    //         // uint16 max USD: ~0.06 -> 0.065535 (6 decimals)
    //         // uint32 max USD: ~4K -> 4,294.967295 USD (6 decimals) _ max num: ~4B -> 4,294,967,295
    //         // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    //     return 18; // (18 decimals) 
    //         // * min USD = 0.000000000000000001 (18 decimals) 
    //         // uint64 max USD: ~18 -> 18.446744073709551615 (18 decimals)
    //         // uint128 max USD: ~340T -> 340,282,366,920,938,463,463.374607431768211455 (18 decimals)
    // }
    // function transferFrom(address from, address to, uint256 value) public override returns (bool) {
    //     require(ACCT_CALL_VOTE_LOCK_TIME[msg.sender] == 0, ' tokens locked ;) ');
    //     // checks msg.sender 'allowance(from, msg.sender, value)' 
    //     //  then invokes '_transfer(from, to, value)'
    //     return super.transferFrom(from, to, value);
    // }
    // function transfer(address to, uint256 value) public override returns (bool) {
    //     require(ACCT_CALL_VOTE_LOCK_TIME[msg.sender] == 0, ' tokens locked ;0 ');
    //     return super.transfer(to, value); // invokes '_transfer(msg.sender, to, value)'
    // }
}
