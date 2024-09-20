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

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

// import "./CallitTicket.sol";
import "./ICallitLib.sol";
import "./ICallitVault.sol";
import "./ICallitConfig.sol";

interface IERC20x {
    function decimals() external pure returns (uint8);
}

contract CallitDelegate {
    /* GLOBALS (CALLIT) */
    // bool private ONCE_ = true;
    bool private FIRST_ = true;
    string public constant tVERSION = '0.42'; 
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    ICallitLib private LIB;     // set via CONF_setConfig
    ICallitVault private VAULT; // set via CONF_setConfig

    mapping(address => ICallitLib.PROMO) public PROMO_CODE_HASHES; // store promo code hashes to their PROMO mapping

    // // NOTE: a copy of all MARKET in ICallitLib.MARKET[] is stored in DELEGATE (via ACCT_MARKET_HASHES -> HASH_MARKET)
    // //  ie. ACCT_MARKETS[_maker][0] == HASH_MARKET[ACCT_MARKET_HASHES[_maker][0]]
    // //      HENCE, always -> ACCT_MARKETS.length == ACCT_MARKET_HASHES.length
    // mapping(address => ICallitLib.MARKET[]) public ACCT_MARKETS; // store maker to all their MARKETs created mapping ***
    mapping(address => ICallitLib.MARKET_VOTE[]) private ACCT_MARKET_VOTES; // store voter to their non-paid MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & private until market close; live = false) ***
    mapping(address => ICallitLib.MARKET_VOTE[]) public ACCT_MARKET_VOTES_PAID; // store voter to their 'paid' MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & avail when market close; live = false) *
    mapping(string => address[]) private CATEGORY_MARK_HASHES; // store category to list of market hashes
    mapping(address => address[]) private ACCT_MARKET_HASHES; // store maker to list of market hashes
    mapping(address => ICallitLib.MARKET) private HASH_MARKET; // store market hash to its MARKET
    mapping(address => address) public TICKET_MAKER; // store ticket to their MARKET.maker mapping
    address[] public MARKET_HASH_LST; // store list of all market haches

    function getMarketForHash(address _hash) external view returns(ICallitLib.MARKET memory) {
        ICallitLib.MARKET memory mark = HASH_MARKET[_hash];
        require(mark.maker != address(0), ' !maker :0 ');
        return mark;
    }
    function getMarketHashesForMakerOrCategory(address _maker, string calldata _category) external view returns(address[] memory) {
        if (bytes(_category).length > 1) { // note: sending a single 'space', signals use _maker
            require(CATEGORY_MARK_HASHES[_category].length > 0, ' no _cat market :/ ');
            return CATEGORY_MARK_HASHES[_category];
        } else if (_maker != address(0)) {
            require(ACCT_MARKET_HASHES[_maker].length > 0, ' no _maker markets :/ ');
            return ACCT_MARKET_HASHES[_maker];
        } else {
            require(MARKET_HASH_LST.length > 0, ' no markets :/ ');
            return MARKET_HASH_LST;
        }
    }
    function storeNewMarket(ICallitLib.MARKET memory _mark, address _maker, address _markHash) external onlyFactory {
        require(_maker != address(0) && _markHash != address(0), ' bad maker | hash :*{ ');
        // ACCT_MARKETS[_maker].push(_mark);
        ACCT_MARKET_HASHES[_maker].push(_markHash);
        HASH_MARKET[_markHash] = _mark;
        MARKET_HASH_LST.push(_markHash);
    }
    function pushAcctMarketVote(address _account, ICallitLib.MARKET_VOTE memory _markVote) external onlyFactory {
        require(_account != address(0), ' bad _account :*{ ');
        ACCT_MARKET_VOTES[_account].push(_markVote);
    }
    function setHashMarket(address _markHash, ICallitLib.MARKET memory _mark, string calldata _category) external onlyFactory {
        require(_markHash != address(0), ' bad hash :*{ ');
        HASH_MARKET[_markHash] = _mark;
        if (bytes(_category).length > 1) CATEGORY_MARK_HASHES[_category].push(_markHash);
    }

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // legacy & callit promo
    event KeeperTransfer(address _prev, address _new);
    event PromoCreated(address _promoHash, address _promotor, string _promoCode, uint64 _usdTarget, uint64 usdUsed, uint8 _percReward, address _creator, uint256 _blockNumber);
    event PromoRewardsPaid(address _sender, address _promoCodeHash, uint64 _usdPaid, address _promotor);
    event VoterRewardsClaimed(address _claimer, uint64 _usdRewardOwed, uint64 _usdRewardOwed_net);

    /* -------------------------------------------------------- */
    /* CONSTRUTOR
    /* -------------------------------------------------------- */
    constructor() {

    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == CONF.KEEPER(), "!keeper :p");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == CONF.KEEPER() || CONF.ADMINS(msg.sender) == true, " !admin :p");
        // require(msg.sender == CONF.KEEPER() || CONF.adminStatus(msg.sender) == true, " !admin :p");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.KEEPER(), " !keeper & !fact :p");
        _;
    }
    modifier onlyConfig() { 
        // allows 1st onlyConfig attempt to freely pass
        //  NOTE: don't waste this on anything but CONF_setConfig
        if (!FIRST_) 
            require(msg.sender == address(CONF), ' !CONF :[ ');
        FIRST_ = false;
        _;
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :<> ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(_conf);
        LIB = ICallitLib(CONF.ADDR_LIB());
        VAULT = ICallitVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
    /* -------------------------------------------------------- */
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
    
    /* -------------------------------------------------------- */
    /* PUBLIC - ADMIN SUPPORT
    /* -------------------------------------------------------- */
    // CALLIT admin
    function ADMIN_initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward) external onlyAdmin {
        // address promoCodeHash = _initPromoForWallet(_promotor, _promoCode, _usdTarget, _percReward, msg.sender);

        // no 2 percs taken out of promo buy
        require(CONF.PERC_PROMO_BUY_FEE() + _percReward < 10000, ' invalid promo buy _perc :(=) ');
        require(_promotor != address(0) && LIB._validNonWhiteSpaceString(_promoCode) && _usdTarget >= CONF.MIN_USD_PROMO_TARGET(), ' !param(s) :={ ');
        address promoCodeHash = LIB._generateAddressHash(_promotor, _promoCode);
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[promoCodeHash];
        require(promo.promotor == address(0), ' promo already exists :-O ');
        PROMO_CODE_HASHES[promoCodeHash] = ICallitLib.PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);
        // return promoCodeHash;
        emit PromoCreated(promoCodeHash, _promotor, _promoCode, _usdTarget, 0, _percReward, msg.sender, block.number);

        // LEFT OFF HERE ... never storing promoCodeHash generated (only emitting event with it)
    }
    function checkPromoBalance(address _promoCodeHash) external view returns(uint64) {
        // return _checkPromoBalance(_promoCodeHash);
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        // require(promo.promotor != address(0), ' invalid promo :-O ');
        return promo.usdTarget - promo.usdUsed; // note: w/o 'require', should simply return 0
    }
    function getMarketCntForMaker(address _maker) external view returns(uint256) {
        // NOTE: MAX_EOA_MARKETS is uint64
        return ACCT_MARKET_HASHES[_maker].length;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - FACTORY SUPPORT
    /* -------------------------------------------------------- */
    // invoked if function invoked doesn't exist OR no receive() implemented & ETH received w/o data
    fallback() external payable {
        // fwd any PLS recieved to VAULT (convert to USD stable & process deposit)
        VAULT.deposit{value: msg.value}(msg.sender);
    }
    function makeNewMarket( string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                            uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, // note: could possibly remove to save memory (ie. removed _resultDescrs succcessfully)
                            uint256 _mark_num,
                            address _sender
                            ) external onlyFactory returns(ICallitLib.MARKET memory) { 
        require(VAULT.ACCT_USD_BALANCES(_sender) >= _usdAmntLP, ' low balance ;{ ');
        require(block.timestamp < _dtCallDeadline && _dtCallDeadline < _dtResultVoteStart && _dtResultVoteStart < _dtResultVoteEnd, ' invalid dt settings :[] ');

        // check for admin defualt vote time, update _dtResultVoteEnd accordingly
        if (CONF.USE_SEC_DEFAULT_VOTE_TIME()) _dtResultVoteEnd = _dtResultVoteStart + CONF.SEC_DEFAULT_VOTE_TIME();

        // deduct 'market maker fees' from _usdAmntLP
        uint64 net_usdAmntLP = LIB._deductFeePerc(_usdAmntLP, CONF.PERC_MARKET_MAKER_FEE(), _usdAmntLP);

        // save this market and emit log
        ICallitLib.MARKET memory mark = ICallitLib.MARKET({maker:_sender, 
                                                marketNum:_mark_num, 
                                                name:_name,

                                                // marketInfo:MARKET_INFO("", "", ""),
                                                category:"",
                                                rules:"", 
                                                imgUrl:"", 

                                                marketUsdAmnts:ICallitLib.MARKET_USD_AMNTS(_usdAmntLP, 0, 0, 0, 0), 
                                                marketDatetimes:ICallitLib.MARKET_DATETIMES(_dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd), 
                                                // marketResults:mark_results,
                                                marketResults:VAULT.createDexLP(_resultLabels, net_usdAmntLP, CONF.RATIO_LP_TOK_PER_USD()), 
                                                winningVoteResultIdx:0, 
                                                blockTimestamp:block.timestamp, 
                                                blockNumber:block.number, 
                                                live:true}); // true = live

        // Loop through _resultLabels and log deployed ERC20s tickets into TICKET_MAKER mapping
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // set ticket to maker mapping (additional access support)
            TICKET_MAKER[mark.marketResults.resultOptionTokens[i]] = _sender;
            unchecked {i++;}
        }

        // deduct full OG usd input from account balance
        VAULT.edit_ACCT_USD_BALANCES(_sender, _usdAmntLP, false); // false = sub

        // return (mark,_dtResultVoteEnd);
        return mark;
        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    }
    function buyCallTicketWithPromoCode(address _usdStableResult, address _ticket, address _promoCodeHash, uint64 _usdAmnt, address _sender) external onlyFactory returns(uint64, uint256) { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0) && promo.usdTarget - promo.usdUsed >= _usdAmnt && promo.promotor != _sender, ' invalid promo :-O ');

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        // NOTE: potential exploitation preventions (in current callstack 'require' checks)
        //  promotor can't earn both $CALL & USD reward w/ their own promo
        //  maker can't earn $CALL twice on same market (from both "promo buy" & "making market")

        // update promo.usdUsed (add full OG input _usdAmnt)
        promo.usdUsed += _usdAmnt;

        // pay promotor usd reward & purchase _sender's tickets from DEX
        //  NOTE: indeed verifies "_percReward + PERC_PROMO_BUY_FEE < 10000"
        // NOTE: *WARNING* if this require fails ... 
        //  then this promo code cannot be used until PERC_PROMO_BUY_FEE is lowered accordingly
        return VAULT._payPromotorDeductFeesBuyTicket(promo.percReward, _usdAmnt, promo.promotor, _promoCodeHash, _ticket, _usdStableResult, _sender);
    }
    function closeMarketCalls(ICallitLib.MARKET memory mark) external onlyFactory returns(uint64) { // NOTE: !_deductFeePerc; reward mint
        // algorithmic logic...
        //  get market for _ticket
        //  verify mark.marketDatetimes.dtCallDeadline has indeed passed
        //  loop through _ticket LP addresses and pull all liquidity

        // loop through pair addresses and pull liquidity 
        address[] memory _ticketLPs = mark.marketResults.resultTokenLPs;
        uint64 usdAmntPrizePool = 0;
        for (uint16 i = 0; i < _ticketLPs.length;) { // MAX_RESULTS is uint16
            // NOTE: amountToken1 = usd stable amount received (which is all we care about)
            uint256 amountToken1 = VAULT._exePullLiquidityFromLP(mark.marketResults.resultTokenRouters[i], _ticketLPs[i], mark.marketResults.resultOptionTokens[i], mark.marketResults.resultTokenUsdStables[i]);

            // update market prize pool usd received from LP (usdAmntPrizePool: defualts to 0)
            usdAmntPrizePool += LIB._uint64_from_uint256(LIB._normalizeStableAmnt(IERC20x(mark.marketResults.resultTokenUsdStables[i]).decimals(), amountToken1, VAULT._usd_decimals())); 

            unchecked {
                i++;
            }
        }

        return usdAmntPrizePool;
    }
    function claimVoterRewards(address _sender) external onlyFactory { // _deductFeePerc PERC_VOTER_CLAIM_FEE from usdRewardOwed
        // NOTE: loops through all non-piad msg.sender votes (including 'live' markets)
        require(ACCT_MARKET_VOTES[_sender].length > 0, ' no un-paid market votes :) ');
        uint64 usdRewardOwed = 0;
        for (uint64 i = 0; i < ACCT_MARKET_VOTES[_sender].length;) { // uint64 max = ~18,000Q -> 18,446,744,073,709,551,615
            ICallitLib.MARKET_VOTE storage m_vote = ACCT_MARKET_VOTES[_sender][i];
            (ICallitLib.MARKET memory mark,,) = _getMarketForTicket(m_vote.voteResultToken); // reverts if market not found | address(0)

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
                ACCT_MARKET_VOTES_PAID[_sender].push(m_vote);
                uint64 lastIdx = uint64(ACCT_MARKET_VOTES[_sender].length) - 1;
                if (i != lastIdx) { ACCT_MARKET_VOTES[_sender][i] = ACCT_MARKET_VOTES[_sender][lastIdx]; }
                ACCT_MARKET_VOTES[_sender].pop(); // Remove the last element (now a duplicate)

                continue; // Skip 'i++'; continue w/ current idx, to check new item at position 'i'
            }
            unchecked {i++;}
        }

        // deduct fees and pay voter rewards
        // pay w/ lowest value whitelist stable held (returns on 0 reward)
        uint64 usdRewardOwed_net = LIB._deductFeePerc(usdRewardOwed, CONF.PERC_VOTER_CLAIM_FEE(), usdRewardOwed);
        VAULT._payUsdReward(_sender, usdRewardOwed_net, _sender);
        
        // emit log for rewards claimed
        emit VoterRewardsClaimed(msg.sender, usdRewardOwed, usdRewardOwed_net);

        // NOTE: no $CALL tokens minted for this action   
    }
    function claimPromotorRewards(address _promoCodeHash) external {
        ICallitLib.PROMO memory promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' !promotor :p ');

        uint64 usdTargRem = promo.usdTarget - promo.usdUsed;
        require(usdTargRem < LIB._perc_of_uint64(CONF.PERC_REQ_CLAIM_PROMO_REWARD(), promo.usdTarget), ' target not hit yet :0 ');
        uint64 usdPaid = VAULT.payPromoUsdReward(msg.sender, _promoCodeHash, promo.usdUsed, promo.promotor); // invokes _payUsdReward
        emit PromoRewardsPaid(msg.sender, _promoCodeHash, usdPaid, promo.promotor);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE SUPPORTING
    /* -------------------------------------------------------- */
    function _getMarketForTicket(address _ticket) public view returns(ICallitLib.MARKET memory, uint16, address) {
        require(_ticket != address(0), ' no address for market ;:[=] ');

        // NOTE: MAX_EOA_MARKETS is uint64
        // address _maker = TICKET_MAKER[_ticket];
        address[] memory mark_hashes = ACCT_MARKET_HASHES[TICKET_MAKER[_ticket]];
        for (uint64 i = 0; i < mark_hashes.length;) {
            ICallitLib.MARKET memory mark = HASH_MARKET[mark_hashes[i]];
            for (uint16 x = 0; x < mark.marketResults.resultOptionTokens.length;) {
                if (mark.marketResults.resultOptionTokens[x] == _ticket)
                    return (mark, x, mark_hashes[i]);
                    // return mark;
                unchecked {x++;}
            }   
            unchecked {
                i++;
            }
        }
        
        revert(' market not found :( ');
    }
}