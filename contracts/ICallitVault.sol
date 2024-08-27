// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./ICallitLib.sol";

interface ICallitVault {
    function exeArbPriceParityForTicket(ICallitLib.MARKET memory mark, uint16 tickIdx, uint64 _minUsdTargPrice, address _sender) external returns(uint64, uint64, uint64, uint64, uint64);


    // more migration from factory attempts
    // default all fees to 0 (KEEPER setter available)
    function PERC_MARKET_MAKER_FEE() external view returns(uint16);
    function PERC_PROMO_BUY_FEE() external view returns(uint16);
    function PERC_ARB_EXE_FEE() external view returns(uint16);
    function PERC_MARKET_CLOSE_FEE() external view returns(uint16);
    function PERC_PRIZEPOOL_VOTERS() external view returns(uint16);
    function PERC_VOTER_CLAIM_FEE() external view returns(uint16);
    function PERC_WINNER_CLAIM_FEE() external view returns(uint16);

    // call token mint rewards
    function RATIO_CALL_MINT_PER_ARB_EXE() external view returns(uint32);
    function RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS() external view returns(uint32);
    function RATIO_CALL_MINT_PER_VOTE() external view returns(uint32);
    function RATIO_CALL_MINT_PER_MARK_CLOSE() external view returns(uint32);
    function RATIO_CALL_MINT_PER_LOSER() external view returns(uint32);
    function PERC_OF_LOSER_SUPPLY_EARN_CALL() external view returns(uint16);
    function RATIO_PROMO_USD_PER_CALL_MINT() external view returns(uint64);
    function MIN_USD_PROMO_TARGET() external view returns(uint64);

    // lp settings
    function MIN_USD_MARK_LIQ() external view returns(uint64);
    function RATIO_LP_TOK_PER_USD() external view returns(uint16);
    function RATIO_LP_USD_PER_CALL_TOK() external view returns(uint64);

    function INIT_factory(address _delegate) external;
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
    // function _performTicketMint(ICallitLib.MARKET memory _mark, uint64 _tickIdx, uint64 ticketTargetPriceUSD, address _arbExecuter) external returns(uint64,uint64);
    // function _performTicketMintedDexSell(ICallitLib.MARKET memory _mark, uint64 _tickIdx, uint16 _percArbFee, uint64 tokensToMint, uint64 total_usd_cost, address _arbExecuter) external returns(uint64,uint64);
    // function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok, address _buyer) external returns(uint64, uint256);
    function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok, address _buyer) external returns(uint64, uint256);
    function _getCallTicketUsdTargetPrice(address[] memory _resultTickets, address[] memory _pairAddresses, address[] memory _resultStables, address _ticket, uint64 _usdMinTargetPrice) external view returns(uint64);

    function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) external returns (uint256);
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address);
}