// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./ICallitLib.sol";
interface ICallitConfigMarket {
    // vault migration
    function ACCOUNTS(uint256 _idx) external view returns(address); // public w/ public getter
    function ACCT_USD_BALANCES(address _key) external view returns(uint64); // public
    function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) external;
    function getUsdBalanceForAcct(address _acct) external view returns(uint64);
    function grossStableBalance(address[] memory _stables, address _vault) external view returns (uint64);
    function owedStableBalance() external view returns (uint64);
    // function LIVE_PAIR_ADDIES(uint256 _idx) external view returns(address);
    // function getLivePairAddies() external view returns(address[] memory);
    // function getLivePairAddiesCnt() external view returns(uint256);
    // function editLivePairAddress(address _pairAddr, address _ticket, bool _add) external;
    function getLiveTickets() external view returns(address[] memory);
    function editLiveTicketList(address _ticket, address  _pairAddr, bool _add) external;
    function TICK_PAIR_ADDR(address _key) external view returns(address);

    function _getMarketForTicket(address _ticket) external view returns(ICallitLib.MARKET memory, uint16, address);
    // function getMakerForTicket(address _ticket) external view returns(address);
    function pushAcctMarketVote(address _account, ICallitLib.MARKET_VOTE memory _markVote, bool _paid) external;
    function getMarketVotesForAcct(address _account, bool _paid) external view returns(ICallitLib.MARKET_VOTE[] memory);
    function moveMarketVoteToPaid(address _sender, uint64 _idxMove, ICallitLib.MARKET_VOTE calldata _m_vote) external;
    function setHashMarket(address _markHash, ICallitLib.MARKET memory _mark, string calldata _category) external;
    function setMakerForTickets(address _maker, address[] memory _tickets) external;
    function storeNewMarket(ICallitLib.MARKET memory _mark, address _maker) external;
    function getMarketHashesForMakerOrCategory(address _maker, string calldata _category) external view returns(address[] memory);
    function getMarketForHash(address _hash) external view returns(ICallitLib.MARKET memory);
    // function HASH_MARKET(address _key) external view returns(ICallitLib.MARKET memory);
    function getMarketCntForMaker(address _maker) external view returns(uint256);

    function pushAcctMarketReview(ICallitLib.MARKET_REVIEW memory _marketReview, address _maker) external;
    function getMarketReviewsForMaker(address _maker) external view returns(ICallitLib.MARKET_REVIEW[] memory);
}
interface ICallitConfig {
    function TOK_TICK_NAME_SEED() external view returns(string calldata);
    function TOK_TICK_SYMB_SEED() external view returns(string calldata);

    // token migration
    function setAcctHandle(address _sender, string calldata _handle) external;

    // vault migration
    function setPromoForHash(address _promoHash, ICallitLib.PROMO memory _promo) external;
    function getPromoForHash(address _promoHash) external view returns(ICallitLib.PROMO memory);
    function PROMO_USD_OWED(address _key) external view returns(uint64);
    function setUsdOwedForPromoHash(uint64 _usdOwed, address _promoCodeHash) external;
    function getPromoHashesForAcct(address _acct) external view returns(address[] memory);

    function ADMINS(address _key) external view returns(bool);
    // function adminStatus(address _admin) external view returns(bool);
    function KEEPER() external view returns(address);
    function ADDR_LIB() external view returns(address);
    function ADDR_VAULT() external view returns(address);
    function ADDR_DELEGATE() external view returns(address);
    function ADDR_CALL() external view returns(address);
    function ADDR_FACT() external view returns(address);
    function ADDR_CONFM() external view returns(address);

    function NEW_TICK_UNISWAP_V2_ROUTER() external returns(address);
    function NEW_TICK_UNISWAP_V2_FACTORY() external returns(address);
    function NEW_TICK_USD_STABLE() external returns(address);
    function DEPOSIT_USD_STABLE() external returns(address);
    function DEPOSIT_ROUTER() external returns(address);

    function PERC_REQ_CLAIM_PROMO_REWARD() external view returns(uint16);

    // default all fees to 0 (KEEPER setter available)
    function PERC_PROMO_CLAIM_FEE() external view returns(uint16);
    function PERC_MARKET_MAKER_FEE() external view returns(uint16);
    function PERC_PROMO_BUY_FEE() external view returns(uint16);
    function PERC_ARB_EXE_FEE() external view returns(uint16);
    function PERC_MARKET_CLOSE_FEE() external view returns(uint16);
    function PERC_PRIZEPOOL_VOTERS() external view returns(uint16);
    function PERC_VOTER_CLAIM_FEE() external view returns(uint16);
    function PERC_WINNER_CLAIM_FEE() external view returns(uint16);

    // arb algorithm settings
    // market settings
    function MIN_USD_CALL_TICK_TARGET_PRICE() external view returns(uint64);
    function USE_SEC_DEFAULT_VOTE_TIME() external view returns(bool);
    function SEC_DEFAULT_VOTE_TIME() external view returns(uint256);
    function MAX_RESULTS() external view returns(uint16);
    function MAX_EOA_MARKETS() external view returns(uint64);

    // lp settings
    function MIN_USD_MARK_LIQ() external view returns(uint64);
    function RATIO_LP_TOK_PER_USD() external view returns(uint16);
    function RATIO_LP_USD_PER_CALL_TOK() external view returns(uint64);

    // getter functions
    function keeperCheck(uint256 _check) external view returns(bool);
    function KEEPER_setConfig(address _conf) external;
    function getDexAddies() external view returns (address[] memory, address[] memory);
    function get_WHITELIST_USD_STABLES() external view returns(address[] memory);
    function get_USWAP_V2_ROUTERS() external view returns(address[] memory);
    // function VAULT_getStableTokenLowMarketValue() external view returns(address);
    function VAULT_deployTicket(uint256 _initSupplyNoDecs, string calldata _tokName, string calldata _tokSymb) external returns(address);

    // call token mint rewards
    function RATIO_CALL_MINT_PER_ARB_EXE() external view returns(uint32);
    function RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS() external view returns(uint32);
    function RATIO_CALL_MINT_PER_VOTE() external view returns(uint32);
    function RATIO_CALL_MINT_PER_MARK_CLOSE() external view returns(uint32);
    function RATIO_CALL_MINT_PER_LOSER() external view returns(uint32);
    function PERC_OF_LOSER_SUPPLY_EARN_CALL() external view returns(uint16);
    function RATIO_PROMO_USD_PER_CALL_MINT() external view returns(uint64);
    function MIN_USD_PROMO_TARGET() external view returns(uint64);

    // // lp settings
    // function KEEPER_logTicketPair(address _ticket, address _pair) external;
    // function MIN_USD_MARK_LIQ() external view returns(uint64);
    // // function RATIO_LP_TOK_PER_USD() external view returns(uint16);
    // // function RATIO_LP_USD_PER_CALL_TOK() external view returns(uint64);

    // function INIT_factory(address _delegate) external;
    // function KEEPER_setContracts(address _fact, address _delegate, address _lib) external;

    // function getWhitelistStables() external view returns (address[] memory);

    // NOTE: legacy public globals
    // function WHITELIST_USD_STABLES(uint256 _idx) external view returns(address); // private w/ public getter
    // function USD_STABLES_HISTORY(uint256 _idx) external view returns(address); // private w/ public getter
    function USWAP_V2_ROUTERS(uint256 _idx) external view returns(address); // public
    // function USD_STABLE_DECIMALS(address _key) external view returns(uint8); // public
    // function ROUTERS_TO_FACTORY(address _key) external view returns(address); // public
}