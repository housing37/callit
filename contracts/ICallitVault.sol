// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./ICallitLib.sol";

interface ICallitVault {
    // NOTE: legacy public globals
    function ACCT_USD_BALANCES(address _key) external view returns(uint64); // public
    function USD_STABLE_DECIMALS(address _key) external view returns(uint8); // public
    function USWAP_V2_ROUTERS() external view returns(address[] memory); // public
    function ACCOUNTS() external view returns(address[] memory); // private w/ public getter
    function WHITELIST_USD_STABLES() external view returns(address[] memory); // private w/ public getter
    function USD_STABLES_HISTORY() external view returns(address[] memory); // private w/ public getter

    // NOTE: new public helpers for legacy public globals
    function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) external;
    function set_ACCOUNTS(address[] calldata _accts) external;
    
    // NOTE: legacy private (now public)
    function _collectiveStableBalances(address[] memory _stables) external view returns (uint64, uint64, int64, uint256);
    function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) external;
    function _editDexRouters(address _router, bool _add) external;
    // function _exeSwapPlsForStable(uint256 _plsAmnt, address _usdStable) external returns (uint256);
    function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) external returns (uint256);
    function _usd_decimals() external pure returns (uint8);
    function _payUsdReward(uint64 _usdReward, address _receiver) external;
    function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) external returns(uint256, address);
    function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) external returns (address);

    // NOTE: callit market management
    function _logMarketResultReview(address _maker, uint256 _markNum, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) external view returns(ICallitLib.MARKET_REVIEW memory, uint64, uint64);
    function _validVoteCount(uint256 _voterCallBal, uint64 _votesEarned, uint256 _voterLockTime, uint256 _markCreateTime) external view returns(uint64);
    function _getWinningVoteIdxForMarket(uint64[] memory _resultTokenVotes) external view returns(uint16);
    function _addressIsMarketMakerOrCaller(address _addr, address _markMaker, address[] memory _resultOptionTokens) external view returns(bool, bool);
    function _getCallTicketUsdTargetPrice(address[] memory _resultTickets, address[] memory _pairAddresses, address[] memory _resultStables, address _ticket, uint64 _usdMinTargetPrice) external view returns(uint64);

    function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) external returns (uint256);
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
    // function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) external view returns (uint8, uint256);
    // function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) external returns (uint256);

}