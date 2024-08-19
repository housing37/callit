// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
interface ICallitVault {
    // NOTE: legacy public
    function ACCT_USD_BALANCES(address _key) external view returns(uint64); // global mapping(address => uint64)
    function USD_STABLE_DECIMALS(address _key) external view returns(uint8); // global mapping(address => uint8)
    function USWAP_V2_ROUTERS() external view returns(address[] memory); // global address[]
    
    // NOTE: new legacy public helpers
    function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) external;
    function set_ACCOUNTS(address[] calldata _accts) external;
    
    // NOTE: legacy private (was more secure; consider external KEEPER getter instead)
    function ACCOUNTS() external view returns(address[] memory); // global address[]
    function WHITELIST_USD_STABLES() external view returns(address[] memory); // global address[]
    function USD_STABLES_HISTORY() external view returns(address[] memory); // global address[]
    
    // NOTE: legacy private
    function _collectiveStableBalances(address[] memory _stables) external view returns (uint64, uint64, int64, uint256);
    function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) external;
    function _editDexRouters(address _router, bool _add) external;
    function _exeSwapPlsForStable(uint256 _plsAmnt, address _usdStable) external returns (uint256);
    function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) external returns (uint256);
    function _usd_decimals() external pure returns (uint8);
    function _payUsdReward(uint64 _usdReward, address _receiver) external;
    function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) external returns(uint256, address);
    function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) external returns (address);
}