// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./ICallitLib.sol";

interface ICallitVault {
    function deposit(address _depositor) external payable;

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
    function _usd_decimals() external pure returns (uint8);
    function _payUsdReward(address _sender, uint64 _usdReward, address _receiver) external;
    function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) external returns (address);
    function _exePullLiquidityFromLP(address _tokenRouter, address _pairAddress, address _token, address _usdStable) external returns(uint256);

    // NOTE: callit market management
    function _performTicketMint(ICallitLib.MARKET memory _mark, uint64 _tickIdx, uint64 ticketTargetPriceUSD, address _ticket, address _arbExecuter) external returns(uint64,uint64);
    function _performTicketMintedDexSell(ICallitLib.MARKET memory _mark, uint64 _tickIdx, address _ticket, uint16 _percArbFee, uint64 tokensToMint, uint64 total_usd_cost, address _arbExecuter) external returns(uint64,uint64);
    function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok, uint16 _percPromoBuyFee, address _buyer) external returns(uint64, uint256);
    function _getCallTicketUsdTargetPrice(address[] memory _resultTickets, address[] memory _pairAddresses, address[] memory _resultStables, address _ticket, uint64 _usdMinTargetPrice) external view returns(uint64);

    function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) external returns (uint256);
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
}