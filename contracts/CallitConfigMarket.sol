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

import './ICallitConfig.sol';
interface IERC20 {
    function transfer(address _to, uint256 _amount) external;
}
contract CallitConfigMarket {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    // address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);
    
    /* GLOBALS (CALLIT) */
    string public tVERSION = '0.1';
    bool private FIRST_ = true;
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    // ICallitLib private LIB;     // set via CONF_setConfig
    // ICallitVault private VAULT; // set via CONF_setConfig
    // ICallitDelegate private DELEGATE; // set via CONF_setConfig
    // ICallitToken private CALL;  // set via CONF_setConfig

    mapping(address => ICallitLib.PROMO) public PROMO_CODE_HASHES; // store promo code hashes to their PROMO mapping
    mapping(address => ICallitLib.MARKET_REVIEW[]) private ACCT_MARKET_REVIEWS; // store maker to all their MARKET_REVIEWs created by callers

    // NOTE: a copy of all MARKET in ICallitLib.MARKET[] is stored in DELEGATE (via ACCT_MARKET_HASHES -> HASH_MARKET)
    //  ie. ACCT_MARKETS[_maker][0] == HASH_MARKET[ACCT_MARKET_HASHES[_maker][0]]
    //      HENCE, always -> ACCT_MARKETS.length == ACCT_MARKET_HASHES.length
    // mapping(address => ICallitLib.MARKET[]) public ACCT_MARKETS; // store maker to all their MARKETs created mapping ***
    mapping(address => ICallitLib.MARKET_VOTE[]) private ACCT_MARKET_VOTES; // store voter to their non-paid MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & private until market close; live = false) ***
    mapping(address => ICallitLib.MARKET_VOTE[]) public ACCT_MARKET_VOTES_PAID; // store voter to their 'paid' MARKET_VOTEs (ICallitLib.MARKETs voted in) mapping (note: used & avail when market close; live = false) *
    mapping(string => address[]) private CATEGORY_MARK_HASHES; // store category to list of market hashes
    mapping(address => address[]) private ACCT_MARKET_HASHES; // store maker to list of market hashes
    mapping(address => ICallitLib.MARKET) private HASH_MARKET; // store market hash to its MARKET
    mapping(address => address) public TICKET_MAKER; // store ticket to their MARKET.maker mapping
    address[] public MARKET_HASH_LST; // store list of all market haches

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */


    /* -------------------------------------------------------- */
    /* CONSTRUCTOR
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
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.ADDR_DELEGATE() || msg.sender == CONF.KEEPER(), " !keeper & !fact :p");
        _;
    }
    modifier onlyConfig() { 
        // allows 1st onlyConfig attempt to freely pass
        //  NOTE: don't waste this on anything but CONF_setConfig
        if (!FIRST_) 
            require(msg.sender == address(CONF), ' !CONF :/ ');
        FIRST_ = false;
        _;
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :< ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(ADDR_CONFIG);
        // LIB = ICallitLib(CONF.ADDR_LIB());
        // VAULT = ICallitVault(CONF.ADDR_VAULT()); // set via CONF_setConfig
        // DELEGATE = ICallitDelegate(CONF.ADDR_DELEGATE());
        // CALL = ICallitToken(CONF.ADDR_CALL());
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER setters
    /* -------------------------------------------------------- */
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            payable(CONF.KEEPER()).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _amount must be in uint precision to _erc20.decimals()
            IERC20(_erc20).transfer(CONF.KEEPER(), _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }
    /* -------------------------------------------------------- */
    /* PUBLIC - MUTATORS
    /* -------------------------------------------------------- */
    function pushAcctMarketReview(ICallitLib.MARKET_REVIEW memory _marketReview, address _maker) external onlyFactory {
        require(_maker != address(0), ' !_maker :=/ ');
        ACCT_MARKET_REVIEWS[_maker].push(_marketReview);
    }
    function getMarketReviewsForMaker(address _maker) external view returns(ICallitLib.MARKET_REVIEW[] memory) {
        require(_maker != address(0), ' !_maker :--/ ');
        return ACCT_MARKET_REVIEWS[_maker];

        // LEFT OFF HERE ...
        //  people need to get a list of seperate reviews 
        //  as well as the sum of all agreeCnt & disagreeCnt in all reviews
    }
    function storeNewMarket(ICallitLib.MARKET memory _mark, address _maker, address _markHash) external onlyFactory {
        require(_maker != address(0) && _markHash != address(0), ' bad maker | hash :*{ ');
        // ACCT_MARKETS[_maker].push(_mark);
        ACCT_MARKET_HASHES[_maker].push(_markHash);
        HASH_MARKET[_markHash] = _mark;
        MARKET_HASH_LST.push(_markHash);
    }
    function pushAcctMarketVote(address _account, ICallitLib.MARKET_VOTE memory _markVote, bool _paid) external onlyFactory {
        require(_account != address(0), ' bad _account :*{ ');
        if (_paid) ACCT_MARKET_VOTES[_account].push(_markVote);
        else ACCT_MARKET_VOTES_PAID[_account].push(_markVote);
    }
    function moveMarketVoteToPaid(address _sender, uint64 _idxMove, ICallitLib.MARKET_VOTE calldata _m_vote) external onlyFactory {
        // NOTE: move this market vote index '_idxMove', to paid
        // add this MARKET_VOTE to ACCT_MARKET_VOTES_PAID[msg.sender]
        // remove _idxMove MARKET_VOTE from ACCT_MARKET_VOTES[msg.sender]
        //  by replacing it with the last element (then popping last element)
        ACCT_MARKET_VOTES_PAID[_sender].push(_m_vote);
        uint64 lastIdx = uint64(ACCT_MARKET_VOTES[_sender].length) - 1;
        if (_idxMove != lastIdx) { ACCT_MARKET_VOTES[_sender][_idxMove] = ACCT_MARKET_VOTES[_sender][lastIdx]; }
        ACCT_MARKET_VOTES[_sender].pop(); // Remove the last element (now a duplicate)
    }
    function setHashMarket(address _markHash, ICallitLib.MARKET memory _mark, string calldata _category) external onlyFactory {
        require(_markHash != address(0), ' bad hash :*{ ');
        HASH_MARKET[_markHash] = _mark;
        if (bytes(_category).length > 1) CATEGORY_MARK_HASHES[_category].push(_markHash);
    }
    function setMakerForTickets(address _maker, address[] memory _tickets) external onlyFactory {
        require(_tickets.length > 0 && _maker != address(0));
        // Loop through _resultLabels and log deployed ERC20s tickets into TICKET_MAKER mapping
        for (uint16 i = 0; i < _tickets.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // set ticket to maker mapping (additional access support)
            TICKET_MAKER[_tickets[i]] = _maker;
            unchecked {i++;}
        }
    }
    function setPromoForHash(address _promoHash, ICallitLib.PROMO memory _promo) external {
        require(_promo.promotor != address(0) && _promoHash != address(0), ' no promo|hash :/ ');
        PROMO_CODE_HASHES[_promoHash] = _promo;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    function getPomoForHash(address _promoHash) external view returns(ICallitLib.PROMO memory) {
        require(_promoHash != address(0), ' no hash :/ ');
        return PROMO_CODE_HASHES[_promoHash];
    }
    function getMakerForTicket(address _ticket) external view returns(address) {
        require(_ticket != address(0), ' !_maker ;() ');
        return TICKET_MAKER[_ticket];
    }
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
    function getMarketVotesForAcct(address _account, bool _paid) external view returns(ICallitLib.MARKET_VOTE[] memory) {
        require(_account != address(0), ' bad _account :{ ');
        if (_paid) return ACCT_MARKET_VOTES[_account];
        else return ACCT_MARKET_VOTES_PAID[_account];
    }
    function getMarketCntForMaker(address _maker) external view returns(uint256) {
        // NOTE: MAX_EOA_MARKETS is uint64
        return ACCT_MARKET_HASHES[_maker].length;
    }
    function _getMarketForTicket(address _ticket) external view returns(ICallitLib.MARKET memory, uint16, address) {
        require(_ticket != address(0), ' no address for market ;:[=] ');

        // NOTE: MAX_EOA_MARKETS is uint64
        // address _maker = TICKET_MAKER[_ticket];
        address[] memory mark_hashes = ACCT_MARKET_HASHES[TICKET_MAKER[_ticket]];
        // address[] memory mark_hashes = CONF.getMarketHashesForMakerOrCategory(CONF.getMakerForTicket(_ticket), '');
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