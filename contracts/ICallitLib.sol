// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
interface ICallitLib {
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
        MARKET_DATETIMES marketDatetimes;
        MARKET_RESULTS marketResults;
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
    // note: only these used in CallitFactory ... (maybe less after CallitDelegate integration)
    function _logMarketResultReview(address _maker, uint256 _markNum, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) external view returns(ICallitLib.MARKET_REVIEW memory, uint64, uint64);
    function _validVoteCount(uint64 votes_held, uint64 _votesEarned, uint256 _voterLockTime, uint256 _markCreateTime) external pure returns(uint64);
    function _addressIsMarketMakerOrCaller(address _addr, address _markMaker, address[] memory _resultOptionTokens) external view returns(bool, bool);
    function _validNonWhiteSpaceString(string calldata _s) external pure returns(bool);
    function _generateAddressHash(address host, string memory uid) external pure returns (address);
    function _getWinningVoteIdxForMarket(uint64[] memory _resultTokenVotes) external view returns(uint16);
    function _perc_of_uint64(uint32 _perc, uint64 _num) external pure returns (uint64);
    function _deductFeePerc(uint64 _net_usdAmnt, uint16 _feePerc, uint64 _usdAmnt) external pure returns(uint64);
    function _uint64_from_uint256(uint256 value) external pure returns (uint64);
    function _perc_total_supply_owned(address _token, address _account) external view returns (uint64);

    // note: only these used in CallitVault ...
    function _addAddressToArraySafe(address _addr, address[] memory _arr, bool _safe) external pure returns (address[] memory);
    function _calculateTokensToMint(address _pairAddr, uint256 _usdTargetPrice) external view returns (uint256);
    function _estimateLastPriceForTCK(address _pairAddress) external view returns (uint256);
    function _remAddressFromArray(address _addr, address[] memory _arr) external pure returns (address[] memory);

    // note: only these used in CallitDelegate ...
    function _getAmountsForInitLP(uint256 _usdAmntLP, uint256 _resultOptionCnt, uint32 _tokPerUsd) external view returns(uint64, uint256);
    function _genTokenNameSymbol(address _maker, uint256 _markNum, uint16 _resultNum, string calldata _nameSeed, string calldata _symbSeed) external pure returns(string memory, string memory);

    // more than factory & vault needs (maybe not used anywhere else)
    // function _isAddressInArray(address _addr, address[] memory _addrArr) external pure returns(bool);
    // function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) external pure returns (uint256);
}