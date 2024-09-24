// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
interface ICallitLib {
    /* -------------------------------------------------------- */
    /* STRUCTS (CALLIT)
    /* -------------------------------------------------------- */
    struct PROMO {
        address promotor; // influencer wallet this promo is for
        string promoCode;
        address promoCodeHash;
        uint64 usdTarget; // usd amount this promo is good for
        uint64 usdUsed; // usd amount this promo has used so far
        uint8 percReward; // % of caller buys rewarded
        address adminCreator; // admin who created this promo
        uint256 blockNumber; // block number this promo was created
    }
    // struct MARKET_INFO { // 091924: not in use
    //     uint256 marketNum;
    //     string marketName;
    //     string imgUrl;
    //     uint256 initUsdAmntLP_tot;
    //     string[] resultLabels;
    //     address[] resultTickets;
    //     uint256[] dtDeadlines; // call closed, vote start, vote end
    //     bool live;
    // }
    struct MARKET {
        address maker; // EOA market maker
        uint256 marketNum; // used incrementally for MARKET[] in ACCT_MARKETS
        address marketHash; // uesd to ref market in HASH_MARKET
        string name; // display name for this market (maybe auto-generate w/ )
        string category;
        string rules;
        string imgUrl;
        MARKET_USD_AMNTS marketUsdAmnts;
        MARKET_DATETIMES marketDatetimes;
        MARKET_RESULTS marketResults;
        uint16 winningVoteResultIdx; // calc winning idx from resultTokenVotes 
        uint256 blockTimestamp; // sec timestamp this market was created
        uint256 blockNumber; // block number this market was created
        bool live;
    }
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
        address marketHash;
        bool paid;
    }
    struct MARKET_REVIEW { // NOTE: acts as a running log of totals w/ each review data
        address reviewer;
        bool resultAgree;
        address marketMaker;
        uint256 marketNum;
        address marketHash;
        uint64 agreeCnt;
        uint64 disagreeCnt;
        uint64 reviewCnt;
    }
    // note: only these used in CallitFactory ... (maybe less after CallitDelegate integration)    
    // function _logMarketResultReview(address _maker, uint256 _markNum, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) external view returns(ICallitLib.MARKET_REVIEW memory, uint64, uint64);
    function genMarketResultReview(address _sender, ICallitLib.MARKET memory _mark, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) external view returns(ICallitLib.MARKET_REVIEW memory);
    function _validVoteCount(uint64 votes_held, uint64 _votesEarned, uint256 _voterLockTime, uint256 _markCreateTime) external pure returns(uint64);
    function _addressIsMarketMakerOrCaller(address _addr, address _markMaker, address[] memory _resultOptionTokens) external view returns(bool, bool);
    function _validNonWhiteSpaceString(string calldata _s) external pure returns(bool);
    function _generateAddressHash(address host, string memory uid) external pure returns (address);
    function _getWinningVoteIdxForMarket(uint64[] memory _resultTokenVotes) external view returns(uint16);
    function _perc_of_uint64(uint32 _perc, uint64 _num) external pure returns (uint64);
    function _deductFeePerc(uint64 _net_usdAmnt, uint16 _feePerc, uint64 _usdAmnt) external pure returns(uint64);
    function _uint64_from_uint256(uint256 value) external pure returns (uint64);
    function _perc_total_supply_owned(address _token, address _account) external view returns (uint64);
    function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) external pure returns (uint256);
    
    // note: only these used in CallitVault ...
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
    function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) external view returns (uint8, uint256);
    function _getCallTicketUsdTargetPrice(ICallitLib.MARKET memory _mark, uint16 _tickIdx, uint64 _usdMinTargetPrice, uint8 _usd_decs) external view returns(uint64);
    function _addAddressToArraySafe(address _addr, address[] memory _arr, bool _safe) external pure returns (address[] memory);
    function _calculateTokensToMint(address _pairAddr, uint256 _usdTargetPrice) external view returns (uint256);
    // function _estimateLastPriceForTCK(address _pairAddress) external view returns (uint256);
    function _remAddressFromArray(address _addr, address[] memory _arr) external pure returns (address[] memory);

    // note: only these used in CallitDelegate ...
    function _getAmountsForInitLP(uint256 _usdAmntLP, uint256 _resultOptionCnt, uint32 _tokPerUsd) external pure returns(uint64, uint256);
    function _genTokenNameSymbol(address _maker, uint256 _markNum, uint16 _resultNum, string calldata _nameSeed, string calldata _symbSeed) external returns(string memory, string memory);
    function _isAddressInArray(address _addr, address[] memory _addrArr) external pure returns(bool);
    
}