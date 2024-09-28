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

// local _ $ npm install @openzeppelin/contracts
// import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ICallitVault.sol"; // imports ICallitLib.sol
import "./ICallitConfig.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external returns(uint256);
    function transfer(address to, uint256 value) external returns (bool);
}
interface ICallitToken {
    function ACCT_CALL_VOTE_LOCK_TIME(address _key) external view returns(uint256); // public
    function EARNED_CALL_VOTES(address _key) external view returns(uint64); // public
    function mintCallToksEarned(address _receiver, uint256 _callAmntMint, uint64 _callVotesEarned, address _sender) external;
    function decimals() external pure returns (uint8);
    function balanceOf_voteCnt(address _voter) external view returns(uint64);
}
interface ICallitTicket {
    function burnForRewardClaim(address _account) external;
    function decimals() external pure returns (uint8);
    function setDeadlineTransferLock(bool _lock) external;
}
interface ICallitDelegate {
    function makeNewMarket( string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                        uint64 _usdAmntLP, 
                        uint256 _dtCallDeadline, 
                        uint256 _dtResultVoteStart, 
                        uint256 _dtResultVoteEnd, 
                        string[] calldata _resultLabels, // note: could possibly remove to save memory (ie. removed _resultDescrs succcessfully)
                        uint256 _mark_num,
                        address _sender
                        ) external returns(ICallitLib.MARKET memory);
    function buyCallTicketWithPromoCode(address _usdStableResult, address _ticket, address _promoCodeHash, uint64 _usdAmnt, address _reciever) external returns(uint64, uint256);
    function closeMarketCalls(ICallitLib.MARKET memory mark) external returns(uint64);
    // function PROMO_CODE_HASHES(address _key) external view returns(ICallitLib.PROMO memory);
    function claimVoterRewards() external;
    // function pushAcctMarketVote(address _account, ICallitLib.MARKET_VOTE memory _markVote) external;
    // function setHashMarket(address _markHash, ICallitLib.MARKET memory _mark, string calldata _category) external;
    // function storeNewMarket(ICallitLib.MARKET memory _mark, address _maker, address _markHash) external;
    // function _getMarketForTicket(address _ticket) external view returns(ICallitLib.MARKET memory, uint16, address);
    // function getMarketCntForMaker(address _maker) external view returns(uint256);
    // function getMarketHashesForMakerOrCategory(address _maker, string calldata _category) external view returns(address[] memory);
    // function getMarketForHash(address _hash) external view returns(ICallitLib.MARKET memory);
}

contract CallitFactory {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    /* GLOBALS (CALLIT) */
    string public tVERSION = '0.66';
    bool private FIRST_ = true;
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    ICallitConfigMarket private CONFM; // set via CONF_setConfig
    ICallitLib private LIB;     // set via CONF_setConfig
    ICallitVault private VAULT; // set via CONF_setConfig
    ICallitDelegate private DELEGATE; // set via CONF_setConfig
    ICallitToken private CALL;  // set via CONF_setConfig
    uint64 private CALL_INIT_MINT;
    
    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    event MarketCreated(address _maker, uint256 _markNum, address _markHash, string _name, uint64 _usdAmntLP, uint256 _dtCallDeadline, uint256 _dtResultVoteStart, uint256 _dtResultVoteEnd, string[] _resultLabels, address[] _resultOptionTokens, uint256 _blockTime, bool _live);
    event PromoBuyPerformed(address _buyer, address _promoCodeHash, address _usdStable, address _ticket, uint64 _grossUsdAmnt, uint64 _netUsdAmnt, uint256  _tickAmntOut, uint64 _callEarnedAmnt);
    event MarketReviewed(address _caller, bool _resultAgree, address _marketMaker, uint256 _marketNum, address _markHash, uint64 _agreeCnt, uint64 _disagreeCnt);
    event ArbPriceCorrectionExecuted(address _executer, address _ticket, uint64 _tickTargetPrice, uint64 _tokenMintCnt, uint64 _usdGrossReceived, uint64 _usdTotalPaid, uint64 _usdNetProfit, uint64 _callEarnedAmnt);
    event MarketCallsClosed(address _executer, address _ticket, address _marketMaker, uint256 _marketNum, address _markHash, uint64 _usdAmntPrizePool, uint64 _callEarnedAmnt);
    event MarketClosed(address _sender, address _ticket, address _marketMaker, uint256 _marketNum, address _markHash, uint64 _winningResultIdx, uint64 _usdPrizePoolPaid, uint64 _usdVoterRewardPoolPaid, uint64 _usdRewardPervote, uint64 _callEarnedAmnt);
    event TicketRewardsClaimed(address _sender, address _ticket, bool _is_winner, bool _resultAgree);

    /* -------------------------------------------------------- */
    /* CONSTRUCTOR
    /* -------------------------------------------------------- */
    constructor(uint64 _CALL_initSupply) {
        CALL_INIT_MINT = _CALL_initSupply;
        // NOTE: CALL initSupply is minted to KEEPER via CONF_setConfig init call (ie. _mintCallToksEarned)
        // NOTE: whitelist stable & dex routers set in CONF constructor
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == CONF.KEEPER(), "!keeper :p");
        _;
    }
    modifier onlyConfig() { 
        // allows 1st onlyConfig attempt to freely pass
        //  NOTE: don't waste this on anything but CONF_setConfig
        if (!FIRST_) {
            require(msg.sender == address(CONF), ' !CONF :p '); // first validate CONF
            _; // then proceed to set CONF++
        } else {
            _; // first proceed to set CONF++
            _mintCallToksEarned(CONF.KEEPER(), CALL_INIT_MINT); // then mint CALL to keeper
            FIRST_ = false; // never again
        } 
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :< ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(ADDR_CONFIG);
        CONFM = ICallitConfigMarket(CONF.ADDR_CONFM());
        LIB = ICallitLib(CONF.ADDR_LIB());
        VAULT = ICallitVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
        DELEGATE = ICallitDelegate(CONF.ADDR_DELEGATE());
        CALL = ICallitToken(CONF.ADDR_CALL());
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER setters
    /* -------------------------------------------------------- */
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(CONF.KEEPER()).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _amount must be in uint precision to _erc20.decimals()
            require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(CONF.KEEPER(), _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - UI (CALLIT)
    /* -------------------------------------------------------- */
    function getMarketForTicket(address _ticket) external view returns(ICallitLib.MARKET memory) {
        (ICallitLib.MARKET memory mark,,) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        return mark;
    }
    function getMarketForHash(address _hash) external view returns(ICallitLib.MARKET memory) {
        return CONFM.getMarketForHash(_hash); // checks require
    }
    function getPromosForAcct(address _acct) external view returns(ICallitLib.PROMO[] memory) {
        address[] memory promoHashes = CONF.getPromoHashesForAcct(_acct); // checks require on _acct & length > 0
        ICallitLib.PROMO[] memory ret_promos = new ICallitLib.PROMO[](promoHashes.length);
        for (uint64 i=0; i < promoHashes.length;) {
            // ICallitLib.PROMO memory promo = CONF.getPromoForHash(promoHashes[i]);
            ret_promos[i] = CONF.getPromoForHash(promoHashes[i]);
            unchecked { i++; }
        }

        require(ret_promos[0].promotor != address(0), ' no promos found :// ');
        return ret_promos;
    }
    function getMarketCntForMakerOrCategory(address _maker, string calldata _category) external view returns(uint256) {
        // NOTE: MAX_EOA_MARKETS is uint64
        address[] memory mark_hashes = CONFM.getMarketHashesForMakerOrCategory(_maker, _category); // note: checks for _category.length > 1
        return mark_hashes.length;
    }
    function getMarketHashesForMakerOrCategory(string calldata _category, address _maker, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) external view returns(address[] memory) {
        // require(_maker != address(0), ' !_maker ;[=] '); // 
        address[] memory mark_hashes = CONFM.getMarketHashesForMakerOrCategory(_maker, _category); // note: checks for _category.length > 1 & _maker != address(0)
        require(mark_hashes.length > 0 && _retCnt > 0 && mark_hashes.length >= _idxStart + _retCnt, ' out of range :p ');
        address[] memory ret_hashes = new address[](_retCnt);
        uint8 cnt_;
        for (uint8 i = 0; cnt_ < _retCnt && _idxStart + i < mark_hashes.length;) {
            // check for mismatch, skip & inc only 'i' (note: _all == _live|!_live)
            ICallitLib.MARKET memory mark = CONFM.getMarketForHash(mark_hashes[_idxStart + i]);
            if (!_all && mark.live != _live) { 
                unchecked {i++;} 
                continue; 
            }

            // log market hash found; continue w/ inc both 'i' & 'cnt_'
            ret_hashes[cnt_] = mark_hashes[_idxStart + i];
            unchecked {
                i++; cnt_++;
            }
        }
        return ret_hashes;
    }
    function getMarketsForMakerOrCategory(string calldata _category, address _maker, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) external view returns(ICallitLib.MARKET[] memory) {
    // function getMarketsForMaker(address _maker, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) external view returns(ICallitLib.MARKET_INFO[] memory) {
        // require(_maker != address(0), ' !_maker ;[-] ');
        address[] memory mark_hashes = CONFM.getMarketHashesForMakerOrCategory(_maker, _category); // note: checks for _category.length > 1 & _maker != address(0)
        require(mark_hashes.length > 0 && _retCnt > 0 && mark_hashes.length >= _idxStart + _retCnt, ' out of range :-p ');
        return _getMarketReturns(mark_hashes, _all, _live, _idxStart, _retCnt);
    }
    function _getMarketReturns(address[] memory _markHashes, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) private view returns(ICallitLib.MARKET[] memory) {
    // function _getMarketReturns(address[] memory _markHashes, bool _all, bool _live, uint8 _idxStart, uint8 _retCnt) private view returns(ICallitLib.MARKET_INFO[] memory) {
        // init return array
        ICallitLib.MARKET[] memory marks_ret = new ICallitLib.MARKET[](_retCnt); // pre-verified _retCnt > 0
        // ICallitLib.MARKET_INFO[] memory mark_infos = new ICallitLib.MARKET_INFO[](_retCnt);
        uint8 cnt_;
        for (uint8 i = 0; cnt_ < _retCnt && _idxStart + i < _markHashes.length;) {
            ICallitLib.MARKET memory mark = CONFM.getMarketForHash(_markHashes[_idxStart + i]);

            // check for mismatch, skip & inc only 'i' (note: _all = _live|!_live)
            if (!_all && mark.live != _live) { unchecked {i++;} continue; }
                 
            // log market found; continue w/ inc both 'i' & 'cnt_'
            marks_ret[cnt_] = mark; // note: use 'cnt_' not '_idxStart + i'
            // uint256[] memory dt_deadlines = new uint256[](3);
            // dt_deadlines[0] = mark.marketDatetimes.dtCallDeadline;
            // dt_deadlines[1] = mark.marketDatetimes.dtResultVoteStart;
            // dt_deadlines[2] = mark.marketDatetimes.dtResultVoteEnd;
            // mark_infos[cnt_] = ICallitLib.MARKET_INFO({
            //                     marketNum: mark.marketNum, 
            //                     marketName: mark.name, 
            //                     imgUrl: mark.imgUrl, 
            //                     initUsdAmntLP_tot: mark.marketUsdAmnts.usdAmntLP, 
            //                     resultLabels: mark.marketResults.resultLabels,
            //                     resultTickets: mark.marketResults.resultOptionTokens,
            //                     dtDeadlines: dt_deadlines,
            //                     live: mark.live
            //                 });
            unchecked {
                i++; cnt_++;
            }
        }
        // require(mark_infos.length > 0, ' none :-( ');
        // return mark_infos;
        require(marks_ret[0].maker != address(0), ' none :-( ');
        return marks_ret;
    }

    /* ref: https://docs.soliditylang.org/en/latest/contracts.html#fallback-function
        The fallback function is executed on a call to the contract if none of the other 
        functions match the given function signature, 
        or if no data was supplied at all and there is no receive Ether function. 
        The fallback function always receives data, but in order to also receive Ether it must be marked payable.
    */
    // invoked if function invoked doesn't exist OR no receive() implemented & ETH received w/o data
    fallback() external payable {
        // handle contract USD value deposits (convert PLS to USD stable)
        // fwd any PLS recieved to VAULT (convert to USD stable & process deposit)
        VAULT.deposit{value: msg.value}(msg.sender);
        // NOTE: at this point, the vault has the deposited stable and the vault has stored accont balances
        //  emit DepositReceived(msg.sender, amntIn, 0);
    }
    function setAcctHandle(string calldata _handle) external {
        CONF.setAcctHandle(msg.sender, _handle); // checks require for _handle
    }
    function setMarketInfo(address _anyTicket, string calldata _category, string calldata _rules, string calldata _imgUrl) external {
        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark,, address markHash) = CONFM._getMarketForTicket(_anyTicket); // reverts if market not found | address(0)
        require(mark.maker == msg.sender, ' only market maker :( ');
        require(mark.marketUsdAmnts.usdAmntPrizePool == 0, ' call deadline passed :( ');
        require(bytes(_category).length > 1, ' cat too short  :0 ');
        
        mark.category = _category;
        mark.rules = _rules;
        mark.imgUrl = _imgUrl;

        // log category created for this ticket's market hash
        CONFM.setHashMarket(markHash, mark, _category);
    }
    function makeNewMarket(string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                            uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, 
                            string[] calldata _resultDescrs
                            ) external { 
        require(_usdAmntLP >= CONF.MIN_USD_MARK_LIQ(), ' need more liquidity! :{=} ');
        require(2 <= _resultLabels.length && _resultLabels.length <= CONF.MAX_RESULTS() && _resultLabels.length == _resultDescrs.length, ' bad results count :( ');

        // initilize/validate market number for struct MARKET tracking
        uint256 mark_num = CONFM.getMarketCntForMaker(msg.sender);
        require(mark_num <= CONF.MAX_EOA_MARKETS(), ' > MAX_EOA_MARKETS :O ');

        // save this market and emit log
        // note: could possibly remove '_resultLabels' to save memory (ie. removed _resultDescrs succcessfully)
        ICallitLib.MARKET memory mark = DELEGATE.makeNewMarket(_name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, mark_num, msg.sender);
        mark.marketResults.resultDescrs = _resultDescrs; // bc it won't fit in 'DELEGATE.makeNewMark' :/
        // ACCT_MARKETS[msg.sender].push(mark);

        // gen market hash references & store w/ new market in delegate
        // address markHash = LIB._generateAddressHash(msg.sender, string(abi.encodePacked(mark_num)));
        CONFM.storeNewMarket(mark, msg.sender); // sets HASH_MARKET

        // // Loop through _resultLabels and log deployed ERC20s tickets into TICKET_MAKERS mapping
        // for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
        //     // set ticket to maker mapping (additional access support)
        //     TICKET_MAKERS[mark.marketResults.resultOptionTokens[i]] = msg.sender;
        //     unchecked {i++;}
        // }
        // emit MarketCreated(msg.sender, mark_num, _name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, mark.marketResults.resultOptionTokens, block.timestamp, true); // true = live
        emit MarketCreated(msg.sender, mark_num, mark.marketHash, _name, _usdAmntLP, _dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd, _resultLabels, mark.marketResults.resultOptionTokens, block.timestamp, true); // true = live

        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    }   
    function buyCallTicketWithPromoCode(address _ticket, address _promoCodeHash, uint64 _usdAmnt) external { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
        require(_ticket != address(0), ' invalid _ticket :-{} ');
        require(CONFM.ACCT_USD_BALANCES(msg.sender) >= _usdAmnt, ' low balance ;{ ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark, uint16 tickIdx,) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');
        require(mark.maker != msg.sender,' !promo buy for maker ;( '); 

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        (uint64 net_usdAmnt, uint256 tick_amnt_out) = DELEGATE.buyCallTicketWithPromoCode(mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _promoCodeHash, _usdAmnt, msg.sender);

        // check if msg.sender earned $CALL tokens
        uint64 callEarnedAmnt;
        if (_usdAmnt >= CONF.RATIO_PROMO_USD_PER_CALL_MINT()) {
            // mint $CALL to msg.sender & log $CALL votes earned
            callEarnedAmnt = _usdAmnt / CONF.RATIO_PROMO_USD_PER_CALL_MINT();
            _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned
        }

        // emit log
        emit PromoBuyPerformed(msg.sender, _promoCodeHash, mark.marketResults.resultTokenUsdStables[tickIdx], _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out, callEarnedAmnt);
    }
    function exeArbPriceParityForTicket(address _ticket) external { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
        require(_ticket != address(0), ' invalid _ticket :-{} ');

        // get MARKET & idx for _ticket & validate call time not ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark, uint16 tickIdx,) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline > block.timestamp, ' _ticket call deadline has passed :( ');

        // calc target usd price for _ticket (in order to bring this market to price parity)
        //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        // (uint64 ticketTargetPriceUSD, uint64 tokensToMint, uint64 total_usd_cost, uint64 gross_stab_amnt_out, uint64 net_usd_profits) = VAULT.exeArbPriceParityForTicket(mark, tickIdx, MIN_USD_CALL_TICK_TARGET_PRICE, msg.sender);
        (uint64 ticketTargetPriceUSD, uint64 tokensToMint, uint64 total_usd_cost, uint64 gross_stab_amnt_out, uint64 net_usd_profits) = VAULT.exeArbPriceParityForTicket(mark, tickIdx, msg.sender);

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = CONF.RATIO_CALL_MINT_PER_ARB_EXE();
        _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned

        // emit log of this arb price correction
        emit ArbPriceCorrectionExecuted(msg.sender, _ticket, ticketTargetPriceUSD, tokensToMint, gross_stab_amnt_out, total_usd_cost, net_usd_profits, callEarnedAmnt);
    }
    function closeMarketCallsForTicket(address _ticket) external { // NOTE: !_deductFeePerc; reward mint
        require(_ticket != address(0), ' invalid _ticket :-{} ');

        // algorithmic logic...
        //  get market for _ticket
        //  verify mark.marketDatetimes.dtCallDeadline has indeed passed
        //  loop through _ticket LP addresses and pull all liquidity

        // get MARKET & idx for _ticket & validate call time indeed ended (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark,, address markHash) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtCallDeadline <= block.timestamp && mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls not ready yet | closed :( ');
        // require(mark.marketUsdAmnts.usdAmntPrizePool == 0, ' calls closed already :p '); // usdAmntPrizePool: defaults to 0, unless closed and liq pulled to fill it

        // note: loops through market pair addresses and pulls liquidity for each
        mark.marketUsdAmnts.usdAmntPrizePool = DELEGATE.closeMarketCalls(mark); // NOTE: write to market
        CONFM.setHashMarket(markHash, mark, '');

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = CONF.RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS();
        _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned

        // emit log for this closed market calls event
        emit MarketCallsClosed(msg.sender, _ticket, mark.maker, mark.marketNum, markHash, mark.marketUsdAmnts.usdAmntPrizePool, callEarnedAmnt);
    }
    function initMyVoterHash() external {
        CONF.initVoterHashForAcct(msg.sender);
            // NOTE: this integration hides ticket address voting for from mempool/on-chain logs
            //     ie. they only see the _senderTicketHash generated 
            //         along w/ what market is being voted on
            //         but they can’t see which actual ticket
            //     note: if a malicious actor sees the code for CONF.initVoterHashForAcct
            //         then they can indeed figure out an EOA’s voter hash by reviewing 
            //          the chain’s call history for ‘initVoterHashForAcct’
            //          and replicating it using the seed params found inside the function code
            //         if they have an EOA’s voter hash, they can then loop through all 
            //          resultOptionTokens for the market (markHash) that was voted on,
            //          and retrieve the ticket address that _senderTicketHash references 
    }
    function getMyVoterHash() external view returns(address) {
        return CONF.getVoterHashForAcct(msg.sender);
    }
    // function castVoteForMarketTicket(address _ticket) external { // NOTE: !_deductFeePerc; reward mint
    function castVoteForMarketTicket(address _senderTicketHash, address _markHash) external { // NOTE: !_deductFeePerc; reward mint
        require(_senderTicketHash != address(0) && _markHash != address(0), ' invalid hash :-{=} ');
        // require(IERC20(_ticket).balanceOf(msg.sender) == 0, ' no votes ;( ');

        // *WARNING* -> malicious actors could still monitor the chain activity (tx-by-tx)
        //    this function call potentially allows someone to manually track ticket counts as they come in
        //     (ie. a web page could be created that displays & tracks ticket votes as they come in)
        // HOWEVER, acquiring the soure code for 'CONF.initVoterHashForAcct' is required ...
        //  if a malicious actor sees the code for CONF.initVoterHashForAcct
        //      then they can indeed figure out an EOA’s voter hash by reviewing 
        //      the chain’s call history for ‘initVoterHashForAcct’
        //      and replicating it using the seed params found inside the function code
        //  if they can replicate EOA voter hashes, they can then loop through all 
        //      resultOptionTokens for the market (markHash) that the EOAs voted on,
        //      and retrieve the ticket address that _senderTicketHash references 

        // get ticket address from _senderTicketHash
        //  loop through all tickets in _markHash
        //   find ticket where hash(msg.sender-voter-hash + ticket) == _senderTicketHash
        ICallitLib.MARKET memory mark = CONFM.getMarketForHash(_markHash);
        address ticket;
        for (uint8 i=0; i < mark.marketResults.resultOptionTokens.length;){
            address[] memory toHash = new address[](2);
            toHash[0] = CONF.getVoterHashForAcct(msg.sender);
            toHash[1] = mark.marketResults.resultOptionTokens[i];
            address ticketHash = LIB.genHashOfAddies(toHash);
            if (ticketHash == _senderTicketHash) {
                ticket = mark.marketResults.resultOptionTokens[i];
                break;
            }
                
            unchecked{i++;}
        }
        require(ticket != address(0), ' bad ticket hash :/ '); // note: ticket holder check in LIB._addressIsMarketMakerOrCaller
        // require(IERC20(ticket).balanceOf(msg.sender) == 0, ' no votes ;( ');

        // algorithmic logic...
        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        //  - store vote in struct MARKET_VOTE and push to ACCT_MARKET_VOTES
        //  - 

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        // (ICallitLib.MARKET memory mark, uint16 tickIdx, address markHash) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        (, uint16 tickIdx,) = CONFM._getMarketForTicket(ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteStart <= block.timestamp && mark.marketDatetimes.dtResultVoteEnd > block.timestamp, ' inactive market voting :p ');

        //  - verify msg.sender is NOT this market's maker or caller (ie. no self voting)
        // (bool is_maker, bool is_caller) = _addressIsMarketMakerOrCaller(msg.sender, mark);
        (bool is_maker, bool is_caller) = LIB._addressIsMarketMakerOrCaller(msg.sender, mark.maker, mark.marketResults.resultOptionTokens);
        require(!is_maker && !is_caller, ' no self-voting :o ');

        //  - verify $CALL token held/locked through out this market time period
        //  - vote count = uint(EARNED_CALL_VOTES[msg.sender])
        // uint64 vote_cnt = LIB._validVoteCount(CALL.balanceOf_voteCnt(msg.sender), CALL.EARNED_CALL_VOTES(msg.sender), CALL.ACCT_CALL_VOTE_LOCK_TIME(msg.sender), mark.blockTimestamp);
        uint64 vote_cnt = LIB.getValidVoteCount(CALL.balanceOf_voteCnt(msg.sender), CONF.RATIO_CALL_TOK_PER_VOTE(), CALL.EARNED_CALL_VOTES(msg.sender), CALL.ACCT_CALL_VOTE_LOCK_TIME(msg.sender), mark.blockTimestamp);
        require(vote_cnt > 0, ' invalid voter :{=} ');
            // LEFT OFF HERE ... integrate ability for regular $CALL holders to vote 
            //  (ie. at lower ratio... maybe 1:10 votes to holdings)

        //  - store vote in struct MARKET
        mark.marketResults.resultTokenVotes[tickIdx] += vote_cnt; // NOTE: write to market
        CONFM.setHashMarket(_markHash, mark, '');

        // log market vote per EOA, so EOA can claim voter fees earned (where votes = "majority of votes / winning result option")
        //  NOTE: *WARNING* if ACCT_MARKET_VOTES was public, then anyone can see the votes before voting has ended
        // DELEGATE.ACCT_MARKET_VOTES[msg.sender].push(ICallitLib.MARKET_VOTE(msg.sender, _ticket, tickIdx, vote_cnt, mark.maker, mark.marketNum, false)); // false = not paid
        CONFM.pushAcctMarketVote(msg.sender, ICallitLib.MARKET_VOTE(msg.sender, ticket, tickIdx, vote_cnt, mark.maker, mark.marketNum, mark.marketHash, false), false); // false, false = un-paid, un-paid

        // mint $CALL token reward to msg.sender
        _mintCallToksEarned(msg.sender, CONF.RATIO_CALL_MINT_PER_VOTE()); // emit CallTokensEarned

        // event MarketTicketVote

        // NOTE: -> DO NOT want to emit event log for casting votes 
        //  this will allow people to see majority votes before voting        
    }

    function closeMarketForTicket(address _ticket) external { // _deductFeePerc PERC_MARKET_CLOSE_FEE from mark.marketUsdAmnts.usdAmntPrizePool
        require(_ticket != address(0), ' invalid _ticket :-{-} ');
        // algorithmic logic...
        //  - count votes in mark.resultTokenVotes 
        //  - set mark.winningVoteResultIdx accordingly
        //  - calc market usdVoterRewardPool (using global KEEPER set percent)
        //  - calc market usdRewardPerVote (for voter reward claiming)
        //  - calc & mint $CALL to market maker (if earned)
        //  - set market 'live' status = false;

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark,, address markHash) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
        require(mark.marketDatetimes.dtResultVoteEnd <= block.timestamp, ' market voting not done yet ;=) ');

        // getting winning result index to set mark.winningVoteResultIdx
        //  for voter fee claim algorithm (ie. only pay majority voters)
        // mark.winningVoteResultIdx = _getWinningVoteIdxForMarket(mark); // NOTE: write to market
        mark.winningVoteResultIdx = LIB._getWinningVoteIdxForMarket(mark.marketResults.resultTokenVotes); // NOTE: write to market

        // validate total % pulling from 'usdVoterRewardPool' is not > 100% (10000 = 100.00%)
        require(CONF.PERC_PRIZEPOOL_VOTERS() + CONF.PERC_MARKET_CLOSE_FEE() < 10000, ' perc error ;( ');

        // calc & save total voter usd reward pool (ie. a % of prize pool in mark)
        mark.marketUsdAmnts.usdVoterRewardPool = LIB._perc_of_uint64(CONF.PERC_PRIZEPOOL_VOTERS(), mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market

        // calc & set net prize pool after taking out voter reward pool (+ other market close fees)
        mark.marketUsdAmnts.usdAmntPrizePool_net = mark.marketUsdAmnts.usdAmntPrizePool - mark.marketUsdAmnts.usdVoterRewardPool; // NOTE: write to market
        mark.marketUsdAmnts.usdAmntPrizePool_net = LIB._deductFeePerc(mark.marketUsdAmnts.usdAmntPrizePool_net, CONF.PERC_MARKET_CLOSE_FEE(), mark.marketUsdAmnts.usdAmntPrizePool); // NOTE: write to market
            // LEFT OFF HERE .. latest failed here with enum error
            //  0x4e487b710000000000000000000000000000000000000000000000000000000000000012
            //  Panic errors use the selector 0x4e487b71 and the following codes:
            //  0x12 – Invalid enum value (i.e., an enum has been assigned an invalid value).
            
        // calc & save usd payout per vote ("usd per vote" = usd reward pool / total winning votes)
        mark.marketUsdAmnts.usdRewardPerVote = mark.marketUsdAmnts.usdVoterRewardPool / mark.marketResults.resultTokenVotes[mark.winningVoteResultIdx]; // NOTE: write to market

        // check if mark.maker earned $CALL tokens
        if (mark.marketUsdAmnts.usdAmntLP >= CONF.RATIO_LP_USD_PER_CALL_TOK()) {
            // mint $CALL to mark.maker & log $CALL votes earned
            _mintCallToksEarned(mark.maker, mark.marketUsdAmnts.usdAmntLP / CONF.RATIO_LP_USD_PER_CALL_TOK()); // emit CallTokensEarned
        }

        // close market
        mark.live = false; // NOTE: write to market
        CONFM.setHashMarket(markHash, mark, '');

        // mint $CALL token reward to msg.sender
        uint64 callEarnedAmnt = CONF.RATIO_CALL_MINT_PER_MARK_CLOSE();
        _mintCallToksEarned(msg.sender, callEarnedAmnt); // emit CallTokensEarned

        // un-lock ticket transfers (ie. call deadline passed & all liquidity pulled, no more bets)
        for (uint16 i=0; i < mark.marketResults.resultOptionTokens.length;) {
            ICallitTicket(mark.marketResults.resultOptionTokens[i]).setDeadlineTransferLock(false); // false = un-locked
            unchecked {i++;}
        }

        // emit log for closed market
        emit MarketClosed(msg.sender, _ticket, mark.maker, mark.marketNum, markHash, mark.winningVoteResultIdx, mark.marketUsdAmnts.usdAmntPrizePool_net, mark.marketUsdAmnts.usdVoterRewardPool, mark.marketUsdAmnts.usdRewardPerVote, callEarnedAmnt);
    }
    function claimTicketRewards(address _ticket, bool _resultAgree) external { // _deductFeePerc PERC_WINNER_CLAIM_FEE from usdPrizePoolShare
        require(_ticket != address(0), ' invalid _ticket :-{+} ');
        require(IERC20(_ticket).balanceOf(msg.sender) > 0, ' ticket !owned ;( ');
        // algorithmic logic...
        //  - check if market voting ended & makr not live
        //  - check if _ticket is a winner
        //  - calc payout based on: _ticket.balanceOf(msg.sender) & mark.marketUsdAmnts.usdAmntPrizePool_net & _ticket.totalSupply();
        //  - send payout to msg.sender
        //  - burn IERC20(_ticket).balanceOf(msg.sender)
        //  - log _resultAgree in MARKET_REVIEW

        // get MARKET & idx for _ticket & validate vote time started (NOTE: MAX_EOA_MARKETS is uint64)
        (ICallitLib.MARKET memory mark, uint16 tickIdx, address markHash) = CONFM._getMarketForTicket(_ticket); // reverts if market not found | address(0)
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
            usdPrizePoolShare = LIB._deductFeePerc(usdPrizePoolShare, CONF.PERC_WINNER_CLAIM_FEE(), usdPrizePoolShare);
            VAULT._payUsdReward(msg.sender, usdPrizePoolShare, msg.sender); // emits 'transfer' event log
        } else {
            // NOTE: perc requirement limits ability for exploitation and excessive $CALL minting
            if (LIB._perc_total_supply_owned(_ticket, msg.sender) >= CONF.PERC_OF_LOSER_SUPPLY_EARN_CALL()) {
                // mint $CALL to loser msg.sender & log $CALL votes earned
                _mintCallToksEarned(msg.sender, CONF.RATIO_CALL_MINT_PER_LOSER()); // emit CallTokensEarned

                // NOTE: this action could open up a secondary OTC market for collecting loser tickets
                //  ie. collecting losers = minting $CALL
            } else {
                // if msg.sender doesn't have enough to claim as loser
                //  then revert (ie. do not burn, leave loser tokens on the market)
                revert(' need more losers :O ');
            }
        }

        // burn IERC20(_ticket).balanceOf(msg.sender)
        ICallitTicket cTicket = ICallitTicket(_ticket);
        cTicket.burnForRewardClaim(msg.sender);

        // log caller's review of market results
        // (ICallitLib.MARKET_REVIEW memory marketReview, uint64 agreeCnt, uint64 disagreeCnt) = LIB._logMarketResultReview(mark.maker, mark.marketNum, CONFM.getMarketReviewsForMaker(mark.maker), _resultAgree);
        ICallitLib.MARKET_REVIEW memory marketReview = LIB.genMarketResultReview(msg.sender, mark, CONFM.getMarketReviewsForMaker(mark.maker), _resultAgree);
        CONFM.pushAcctMarketReview(marketReview, mark.maker);

        // emit log event for reviewing market result
        emit MarketReviewed(msg.sender, _resultAgree, mark.maker, mark.marketNum, markHash, marketReview.agreeCnt, marketReview.disagreeCnt);
          
        // emit log event for claimed ticket
        emit TicketRewardsClaimed(msg.sender, _ticket, is_winner, _resultAgree);

        // NOTE: no $CALL tokens minted for this action
    }
    function claimVoterRewards() external { // _deductFeePerc PERC_VOTER_CLAIM_FEE from usdRewardOwed
        DELEGATE.claimVoterRewards(); // emits 'VoterRewardsClaimed'
        // NOTE: no $CALL tokens minted for this action

    //     // NOTE: loops through all non-piad msg.sender votes (including 'live' markets)
    //     require(ACCT_MARKET_VOTES[msg.sender].length > 0, ' no un-paid market votes :) ');
    //     uint64 usdRewardOwed = 0;
    //     for (uint64 i = 0; i < ACCT_MARKET_VOTES[msg.sender].length;) { // uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
    //         ICallitLib.MARKET_VOTE storage m_vote = ACCT_MARKET_VOTES[msg.sender][i];
    //         (ICallitLib.MARKET storage mark,,) = _getMarketForTicket(m_vote.marketMaker, m_vote.voteResultToken); // reverts if market not found | address(0)

    //         // skip live MARKETs
    //         if (mark.live) {
    //             unchecked {i++;}
    //             continue;
    //         }

    //         // verify voter should indeed be paid & add usd reward to usdRewardOwed
    //         //  ie. msg.sender's vote == winning result option (majority of votes)
    //         //       AND ... this MARKET_VOTE has not been paid yet
    //         if (m_vote.voteResultIdx == mark.winningVoteResultIdx && !m_vote.paid) {
    //             usdRewardOwed += mark.marketUsdAmnts.usdRewardPerVote * m_vote.voteResultCnt;
    //             m_vote.paid = true; // set paid // NOTE: write to market
    //         }

    //         // check for 'paid' MARKET_VOTE found in ACCT_MARKET_VOTES (& move to ACCT_MARKET_VOTES_PAID)
    //         //  NOTE: integration moves MARKET_VOTE that was just set as 'paid' above, to ACCT_MARKET_VOTES_PAID
    //         //   AND ... catches any 'prev-paid' MARKET_VOTEs lingering in non-paid ACCT_MARKET_VOTES array
    //         if (m_vote.paid) { // NOTE: move this market vote index 'i', to paid
    //             // add this MARKET_VOTE to ACCT_MARKET_VOTES_PAID[msg.sender]
    //             // remove _idxMove MARKET_VOTE from ACCT_MARKET_VOTES[msg.sender]
    //             //  by replacing it with the last element (then popping last element)
    //             ACCT_MARKET_VOTES_PAID[msg.sender].push(m_vote);
    //             uint64 lastIdx = uint64(ACCT_MARKET_VOTES[msg.sender].length) - 1;
    //             if (i != lastIdx) { ACCT_MARKET_VOTES[msg.sender][i] = ACCT_MARKET_VOTES[msg.sender][lastIdx]; }
    //             ACCT_MARKET_VOTES[msg.sender].pop(); // Remove the last element (now a duplicate)

    //             continue; // Skip 'i++'; continue w/ current idx, to check new item at position 'i'
    //         }
    //         unchecked {i++;}
    //     }

    //     // deduct fees and pay voter rewards
    //     // pay w/ lowest value whitelist stable held (returns on 0 reward)
    //     VAULT._payUsdReward(msg.sender, LIB._deductFeePerc(usdRewardOwed, CONF.PERC_VOTER_CLAIM_FEE(), usdRewardOwed), msg.sender);

    //     // emit log for rewards claimed
    //   //  emit VoterRewardsClaimed(msg.sender, usdRewardOwed, usdRewardOwed_net);

    //     // NOTE: no $CALL tokens minted for this action   
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (CALLIT MANAGER) // NOTE: migrate to CallitVault (ALL)
    /* -------------------------------------------------------- */
    function _mintCallToksEarned(address _receiver, uint64 _callAmnt) private {
        // mint _callAmnt $CALL to _receiver & log $CALL votes earned
        //  NOTE: _callAmnt decimals should be accounted for on factory invoking side
        //      allows for factory minting fractions of a token if needed
        CALL.mintCallToksEarned(_receiver, _callAmnt * 10**uint8(CALL.decimals()), _callAmnt, msg.sender); 
            // NOTE: updates CALL.EARNED_CALL_VOTES & emits CallTokensEarned
    }
}
