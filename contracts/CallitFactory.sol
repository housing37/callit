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
// import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
// import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./CallitTicket.sol"; // imports ERC20.sol -> IERC20.sol
import "./ICallitVault.sol"; // imports ICallitLib.sol

interface ICallitToken {
    function ACCT_CALL_VOTE_LOCK_TIME(address _key) external view returns(uint256); // public
    function INIT_factory() external;
    function FACT_setContracts(address _fact) external;
    function mintCallToksEarned(address _receiver, uint256 _callAmnt) external;
    function setCallTokenVoteLock(bool _lock) external;
    function decimals() external pure returns (uint8);
    // function balanceOf(address account) external returns(uint256);
    function balanceOf_voteCnt(address _voter) external view returns(uint64);
}
interface ICallitTicket {
    function mintForPriceParity(address _receiver, uint256 _amount) external;
    function burnForWinLoseClaim(address _account) external;
    function decimals() external pure returns (uint8);
    function balanceOf(address account) external returns(uint256);
}
interface ICallitDelegate {
    function INIT_factory() external;
    function makeNewMarket( string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                        uint64 _usdAmntLP, 
                        uint256 _dtCallDeadline, 
                        uint256 _dtResultVoteStart, 
                        uint256 _dtResultVoteEnd, 
                        string[] calldata _resultLabels, // note: could possibly remove to save memory (ie. removed _resultDescrs succcessfully)
                        uint256 _mark_num,
                        address _sender
                        ) external returns(ICallitLib.MARKET memory);
    // function initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward, address _sender) external;
    // function checkPromoBalance(address _promoCodeHash) external view returns(uint64);
    function buyCallTicketWithPromoCode(address _usdStableResult, address _ticket, address _promoCodeHash, uint64 _usdAmnt, address _reciever) external returns(uint64, uint256);
    function closeMarketCallsForTicket(ICallitLib.MARKET memory mark) external returns(uint64);
    function setAcctHandle(address _acct, string calldata _handle) external;    
}

contract CallitFactory {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    /* _ ADMIN SUPPORT (legacy) _ */
    address public KEEPER;
    // uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
    string public tVERSION = '0.18';

    /* GLOBALS (CALLIT) */
    address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
    address public VAULT_ADDR = address(0x1E96e984B48185d63449d86Fb781E298Ac12FB49); // CallitVault v0.13
    address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
    address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
    // address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitToken v0.18
    
    ICallitLib   private LIB = ICallitLib(LIB_ADDR);
    ICallitVault private VAULT = ICallitVault(VAULT_ADDR);
    ICallitDelegate private DELEGATE = ICallitDelegate(DELEGATE_ADDR);
    ICallitToken private CALL = ICallitToken(CALL_ADDR);

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
    // mapping(address => bool) public ADMINS; // enable/disable admins (for promo support, etc)
    mapping(address => address) public TICKET_MAKERS; // store ticket to their MARKET.maker mapping
    mapping(address => ICallitLib.MARKET_REVIEW[]) public ACCT_MARKET_REVIEWS; // store maker to all their MARKET_REVIEWs created by callers

    // used externals & private
    mapping(address => ICallitLib.MARKET[]) public ACCT_MARKETS; // store maker to all their MARKETs created mapping ***
    mapping(address => ICallitLib.MARKET_VOTE[]) private ACCT_MARKET_VOTES; // store voter to their non-paid MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & private until market close; live = false) ***
    mapping(address => uint64) public EARNED_CALL_VOTES; // track EOAs to result votes allowed for open markets (uint64 max = ~18,000Q -> 18,446,744,073,709,551,615)
    
    // used private only
    mapping(address => ICallitLib.MARKET_VOTE[]) public  ACCT_MARKET_VOTES_PAID; // store voter to their 'paid' MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & avail when market close; live = false) *

    // lp settings
    uint64 public MIN_USD_MARK_LIQ = 1000000; // (1000000 = $1.000000) min usd liquidity need for 'makeNewMarket' (total to split across all resultOptions)
    
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
    constructor(uint64 _CALL_initSupply_noDecimals) {
        VAULT.INIT_factory(DELEGATE_ADDR); // set FACT_ADDR & DELEGATE_ADDR in VAULT
        DELEGATE.INIT_factory(); // set FACT_ADDR in DELEGATE
        CALL.INIT_factory(); // set FACT_ADDR in CallitToken

        // set default globals
        KEEPER = msg.sender;

        // mint initial CALl to keeper
        _mintCallToksEarned(KEEPER, _CALL_initSupply_noDecimals);

        // NOTE: CALL initSupply is minted to KEEPER via _mintCallToksEarned (ie. CALL.mintCallToksEarned)
        // NOTE: whitelist stable & dex routers set in VAULT constructor
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == KEEPER, "!keeper :p");
        _;
    }
    // modifier onlyAdmin() {
    //     require(msg.sender == KEEPER || ADMINS[msg.sender] == true, " !admin :p");
    //     _;
    // }
    
    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER setters
    /* -------------------------------------------------------- */
    // legacy
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            // require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(KEEPER).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _amount must be in uint precision to _erc20.decimals()
            // require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(KEEPER, _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }
    function KEEPER_setKeeper(address _newKeeper) external onlyKeeper {
        require(_newKeeper != address(0), 'err: 0 address');
        // address prev = address(KEEPER);
        KEEPER = _newKeeper;
      //  emit KeeperTransfer(prev, KEEPER);
    }
    function KEEPER_setContracts(address _delegate, address _vault, address _lib, address _newFact) external onlyKeeper {
        require(_delegate != address(0) && _vault != address(0) && _lib != address(0), ' invalid addies :0 ' );
        DELEGATE_ADDR = _delegate;
        DELEGATE = ICallitDelegate(DELEGATE_ADDR);

        VAULT_ADDR = _vault;
        VAULT = ICallitVault(VAULT_ADDR);

        LIB_ADDR = _lib;
        LIB = ICallitLib(LIB_ADDR);

        if (_newFact != address(0))
            CALL.FACT_setContracts(_newFact);
    }
    // function KEEPER_editAdmin(address _admin, bool _enable) external onlyKeeper {
    //     require(_admin != address(0), ' !_admin :{+} ');
    //     ADMINS[_admin] = _enable;
    // }
    function KEEPER_setMarketSettings(uint16 _maxResultOpts, uint64 _maxEoaMarkets, uint64 _minUsdArbTargPrice, uint256 _secDefaultVoteTime, bool _useDefaultVotetime) external {
        MAX_RESULTS = _maxResultOpts; // max # of result options a market may have
        MAX_EOA_MARKETS = _maxEoaMarkets;
        // ex: 10000 == $0.010000 (ie. $0.01 w/ _usd_decimals() = 6 decimals)
        MIN_USD_CALL_TICK_TARGET_PRICE = _minUsdArbTargPrice;

        SEC_DEFAULT_VOTE_TIME = _secDefaultVoteTime; // 24 * 60 * 60 == 86,400 sec == 24 hours
        USE_SEC_DEFAULT_VOTE_TIME = _useDefaultVotetime; // NOTE: false = use msg.sender's _dtResultVoteEnd in 'makerNewMarket'
    }
    // // CALLIT admin
    // function ADMIN_initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward) external onlyAdmin {
    //     DELEGATE.initPromoForWallet(_promotor, _promoCode, _usdTarget, _percReward, msg.sender);
    // //    emit PromoCreated(promoCodeHash, _promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
    // }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    // CALLIT
    // function getAccountMarkets(address _account) external view returns (ICallitLib.MARKET[] memory) {
    //     require(_account != address(0), ' 0 address? ;[+] ');
    //     return ACCT_MARKETS[_account];
    // }
    // function checkPromoBalance(address _promoCodeHash) external view returns(uint64) {
    //     return DELEGATE.checkPromoBalance(_promoCodeHash);
    // }

    /* -------------------------------------------------------- */
    /* PUBLIC - UI (CALLIT)
    /* -------------------------------------------------------- */
    // handle contract USD value deposits (convert PLS to USD stable)
    receive() external payable {
        // extract PLS value sent
        // uint256 amntIn = msg.value; 

        // send PLS to vault for processing (handle swap for usd stable)
        VAULT.deposit{value: msg.value}(msg.sender);

      //  emit DepositReceived(msg.sender, amntIn, 0);

        // NOTE: at this point, the vault has the deposited stable and the vault has stored accont balances
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
                            uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, 
                            string[] calldata _resultDescrs
                            ) external { 
        require(_usdAmntLP >= MIN_USD_MARK_LIQ, ' need more liquidity! :{=} ');
        require(VAULT.ACCT_USD_BALANCES(msg.sender) >= _usdAmntLP, ' low balance ;{ ');
        require(2 <= _resultLabels.length && _resultLabels.length <= MAX_RESULTS && _resultLabels.length == _resultDescrs.length, ' bad results count :( ');
        require(block.timestamp < _dtCallDeadline && _dtCallDeadline < _dtResultVoteStart && _dtResultVoteStart < _dtResultVoteEnd, ' invalid dt settings :[] ');

        // initilize/validate market number for struct MARKET tracking
        uint256 mark_num = ACCT_MARKETS[msg.sender].length;
        require(mark_num <= MAX_EOA_MARKETS, ' > MAX_EOA_MARKETS :O ');
        
        // check for admin defualt vote time, update _dtResultVoteEnd accordingly
        if (USE_SEC_DEFAULT_VOTE_TIME) _dtResultVoteEnd = _dtResultVoteStart + SEC_DEFAULT_VOTE_TIME;

        // save this market and emit log
        // note: could possibly remove '_resultLabels' to save memory (ie. removed _resultDescrs succcessfully)
        ICallitLib.MARKET memory mark = DELEGATE.makeNewMarket(_name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, mark_num, msg.sender);
        mark.marketResults.resultDescrs = _resultDescrs; // bc it won't fit in 'DELEGATE.makeNewMark' :/
        ACCT_MARKETS[msg.sender].push(mark);

        // Loop through _resultLabels and log deployed ERC20s tickets into TICKET_MAKERS mapping
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // set ticket to maker mapping (additional access support)
            TICKET_MAKERS[mark.marketResults.resultOptionTokens[i]] = msg.sender;
            unchecked {i++;}
        }
        // emit MarketCreated(msg.sender, mark_num, _name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, mark.marketResults.resultOptionTokens, block.timestamp, true); // true = live

        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    }   
    function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt) external { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');
        require(VAULT.ACCT_USD_BALANCES(msg.sender) >= _usdAmnt, ' low balance ;{ ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint16 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');
        require(mark.maker != msg.sender,' !promo buy for maker ;( '); 

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        (uint64 net_usdAmnt, uint256 tick_amnt_out) = DELEGATE.buyCallTicketWithPromoCode(mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _promoCodeHash, _usdAmnt, msg.sender);

        // emit log
      //  emit PromoBuyPerformed(msg.sender, _promoCodeHash, mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out);

        // check if msg.sender earned $CALL tokens
        if (_usdAmnt >= VAULT.RATIO_PROMO_USD_PER_CALL_MINT()) {
            // mint $CALL to msg.sender & log $CALL votes earned
            _mintCallToksEarned(msg.sender, _usdAmnt / VAULT.RATIO_PROMO_USD_PER_CALL_MINT()); // emit CallTokensEarned
        }
    }
    function exeArbPriceParityForTicket(address _ticket) external { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{} ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint16 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');

        // calc target usd price for _ticket (in order to bring this market to price parity)
        //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        (uint64 ticketTargetPriceUSD, uint64 tokensToMint, uint64 total_usd_cost, uint64 gross_stab_amnt_out, uint64 net_usd_profits) = VAULT.exeArbPriceParityForTicket(mark, tickIdx, MIN_USD_CALL_TICK_TARGET_PRICE, msg.sender);

        // mint $CALL token reward to msg.sender
        _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_ARB_EXE()); // emit CallTokensEarned

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
        require(mark.marketDatetimes.dtCallDeadline <= block.timestamp && mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls not ready yet | closed :( ');
        // require(mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls closed already :p '); // usdAmntPrizePool: defaults to 0, unless closed and liq pulled to fill it

        // note: loops through market pair addresses and pulls liquidity for each
        mark.marketUsdAmnts.usdAmntPrizePool = DELEGATE.closeMarketCallsForTicket(mark); // NOTE: write to market

        // mint $CALL token reward to msg.sender
        _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS()); // emit CallTokensEarned

        // emit log for this closed market calls event
      //  emit MarketCallsClosed(msg.sender, _ticket, mark.maker, mark.marketNum, mark.marketUsdAmnts.usdAmntPrizePool, callEarnedAmnt);
    }
    function castVoteForMarketTicket(address _ticket) external { // NOTE: !_deductFeePerc; reward mint
        require(_ticket != address(0) && TICKET_MAKERS[_ticket] != address(0), ' invalid _ticket :-{=} ');
        require(IERC20(_ticket).balanceOf(msg.sender) == 0, ' no votes ;( ');

        // algorithmic logic...
        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        //  - store vote in struct MARKET_VOTE and push to ACCT_MARKET_VOTES
        //  - 

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET storage mark, uint16 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteStart <= block.timestamp && mark.marketDatetimes.dtResultVoteEnd > block.timestamp, ' inactive market voting :p ');

        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        // (bool is_maker, bool is_caller) = _addressIsMarketMakerOrCaller(msg.sender, mark);
        (bool is_maker, bool is_caller) = LIB._addressIsMarketMakerOrCaller(msg.sender, mark.maker, mark.marketResults.resultOptionTokens);
        require(!is_maker && !is_caller, ' no self-voting :o ');

        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        // uint64 vote_cnt = _validVoteCount(msg.sender, mark);
        uint64 vote_cnt = LIB._validVoteCount(CALL.balanceOf_voteCnt(msg.sender), EARNED_CALL_VOTES[msg.sender], CALL.ACCT_CALL_VOTE_LOCK_TIME(msg.sender), mark.blockTimestamp);
        // uint64 vote_cnt = 37;
        require(vote_cnt > 0, ' invalid voter :{=} ');

        //  - store vote in struct MARKET
        mark.marketResults.resultTokenVotes[tickIdx] += vote_cnt; // NOTE: write to market

        // log market vote per EOA, so EOA can claim voter fees earned (where votes = "majority of votes / winning result option")
        //  NOTE: *WARNING* if ACCT_MARKET_VOTES was public, then anyone can see the votes before voting has ended
        ACCT_MARKET_VOTES[msg.sender].push(ICallitLib.MARKET_VOTE(msg.sender, _ticket, tickIdx, vote_cnt, mark.maker, mark.marketNum, false)); // false = not paid

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
        _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_MARK_CLOSE()); // emit CallTokensEarned

        // emit log for closed market
      //  emit MarketClosed(msg.sender, _ticket, mark.maker, mark.marketNum, mark.winningVoteResultIdx, mark.marketUsdAmnts.usdAmntPrizePool_net, mark.marketUsdAmnts.usdVoterRewardPool, mark.marketUsdAmnts.usdRewardPerVote, callEarnedAmnt);
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
        (ICallitLib.MARKET storage mark, uint16 tickIdx) = _getMarketForTicket(TICKET_MAKERS[_ticket], _ticket); // reverts if market not found | address(0)
        require(!mark.live && mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market still live|voting ;) ');

        bool is_winner = mark.winningVoteResultIdx == tickIdx;
        if (is_winner) {
            // calc payout based on: _ticket.balanceOf(msg.sender) & mark.marketUsdAmnts.usdAmntPrizePool_net & _ticket.totalSupply();
            //  usdPerTicket = net prize / _ticket totalSupply brought down to 6 decimals
            //  NOTE: indeed normalizes to VAULT._usd_deciamls()
            // NOTE: not log logging | storing usdPerTicket
            // NOTE: not storing usdPrizePoolShare (but logged in 'transfer' emit)
            uint64 usdPerTicket = mark.marketUsdAmnts.usdAmntPrizePool_net / LIB._uint64_from_uint256(LIB._normalizeStableAmnt(ICallitTicket(_ticket).decimals(), IERC20(_ticket).totalSupply(), VAULT._usd_decimals()));
            uint64 usdPrizePoolShare = usdPerTicket * LIB._uint64_from_uint256(LIB._normalizeStableAmnt(ICallitTicket(_ticket).decimals(), IERC20(_ticket).balanceOf(msg.sender), VAULT._usd_decimals()));

            // send payout to msg.sender
            usdPrizePoolShare = LIB._deductFeePerc(usdPrizePoolShare, VAULT.PERC_WINNER_CLAIM_FEE(), usdPrizePoolShare);
            VAULT._payUsdReward(msg.sender, usdPrizePoolShare, msg.sender); // emits 'transfer' event log
        } else {
            // NOTE: perc requirement limits ability for exploitation and excessive $CALL minting
            if (LIB._perc_total_supply_owned(_ticket, msg.sender) >= VAULT.PERC_OF_LOSER_SUPPLY_EARN_CALL()) {
                // mint $CALL to loser msg.sender & log $CALL votes earned
                _mintCallToksEarned(msg.sender, VAULT.RATIO_CALL_MINT_PER_LOSER()); // emit CallTokensEarned

                // NOTE: this action could open up a secondary OTC market for collecting loser tickets
                //  ie. collecting losers = minting $CALL
            }
        }

        // burn IERC20(_ticket).balanceOf(msg.sender)
        ICallitTicket cTicket = ICallitTicket(_ticket);
        cTicket.burnForWinLoseClaim(msg.sender);

        // log caller's review of market results
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
    function _mintCallToksEarned(address _receiver, uint64 _callAmnt) private {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        //  NOTE: _callAmnt decimals should be accounted for on factory invoking side
        //      allows for factory minting fractions of a token if needed
        CALL.mintCallToksEarned(_receiver, _callAmnt * 10**uint8(CALL.decimals())); 
        uint256 prevEarned = EARNED_CALL_VOTES[_receiver];
        EARNED_CALL_VOTES[_receiver] += _callAmnt; 
        
        // emit log for call tokens earned
        // emit CallTokensEarned(msg.sender, _receiver, _callAmnt, prevEarned, EARNED_CALL_VOTES[_receiver]);
    }
}
