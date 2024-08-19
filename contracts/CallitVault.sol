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
// import "@openzeppelin/contracts/utils/Strings.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // deploy
// import "@openzeppelin/contracts/access/Ownable.sol"; // deploy
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; // deploy
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// local _ $ npm install @openzeppelin/contracts
// import "./node_modules/@openzeppelin/contracts/utils/Strings.sol";
// import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
// import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./ICallitLib.sol";

contract CallitVaultDelegate {
    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    /* _ ADMIN SUPPORT (legacy) _ */
    address public KEEPER;
    address public CALLIT_FACT_ADDR;
    address public CALLIT_LIB_ADDR;
    ICallitLib private CALLIT_LIB;

    /* _ ACCOUNT SUPPORT (legacy) _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    // NOTE: legacy public
    mapping(address => uint64) public ACCT_USD_BALANCES; 
    mapping(address => uint8) public USD_STABLE_DECIMALS;
    address[] public USWAP_V2_ROUTERS;

    // NOTE: legacy private (was more secure; consider external KEEPER getter instead)
    address[] public ACCOUNTS; 
    address[] public WHITELIST_USD_STABLES; // NOTE: private is more secure (legacy) consider KEEPER getter
    address[] public USD_STABLES_HISTORY; // NOTE: private is more secure (legacy) consider KEEPER getter

    function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) external onlyFactory() {
        // NOTE: _usdAmnt must be in _usd_decimals() precision
        require(_acct != address(0) && _usdAmnt > 0, ' invalid _acct | _usdAmnt :p ');
        if (_add) ACCT_USD_BALANCES[_acct] += _usdAmnt;
        else ACCT_USD_BALANCES[_acct] -= _usdAmnt;
    }
    function set_ACCOUNTS(address[] calldata _accts) external onlyFactory() {
        ACCOUNTS = _accts;
    }
    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // callit
    event AlertZeroReward(address _sender, uint64 _usdReward, address _receiver);

    constructor(address _callit_lib) {
        CALLIT_LIB_ADDR = _callit_lib;
        CALLIT_LIB = ICallitLib(_callit_lib);
        KEEPER = msg.sender;
    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == KEEPER, "!keeper :p");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == CALLIT_FACT_ADDR, " !keeper & !contr :p");
        _;
    }
    modifier onlyKeeperOrFactory() {
        require(msg.sender == KEEPER || msg.sender == CALLIT_FACT_ADDR, " !keeper & !contr :p");
        _;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
    /* -------------------------------------------------------- */
    function KEEPER_setCallitFactory(address _contr) external onlyKeeper {
        CALLIT_FACT_ADDR = _contr;
    }
    function KEEPER_setCallitLib(address _callit_lib) external onlyKeeper {
        CALLIT_LIB_ADDR = _callit_lib;
        CALLIT_LIB = ICallitLib(_callit_lib);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - SUPPORTING
    /* -------------------------------------------------------- */
    function _usd_decimals() public pure returns (uint8) {
        return 6; // (6 decimals) 
            // * min USD = 0.000001 (6 decimals) 
            // uint16 max USD: ~0.06 -> 0.065535 (6 decimals)
            // uint32 max USD: ~4K -> 4,294.967295 USD (6 decimals)
            // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    }
    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (legacy) _ // note: migrate to CallitBank (ALL)
    /* -------------------------------------------------------- */
    function _grossStableBalance(address[] memory _stables) private view returns (uint64) {
        uint64 gross_bal = 0;
        for (uint8 i = 0; i < _stables.length;) {
            // NOTE: more efficient algorithm taking up less stack space with local vars
            require(USD_STABLE_DECIMALS[_stables[i]] > 0, ' found stable with invalid decimals :/ ');
            gross_bal += CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_stables[i]], IERC20(_stables[i]).balanceOf(address(this)), _usd_decimals()));
            unchecked {i++;}
        }
        return gross_bal;
    }
    function _owedStableBalance() private view returns (uint64) {
        uint64 owed_bal = 0;
        for (uint256 i = 0; i < ACCOUNTS.length;) {
            owed_bal += ACCT_USD_BALANCES[ACCOUNTS[i]];
            unchecked {i++;}
        }
        return owed_bal;
    }
    function _collectiveStableBalances(address[] memory _stables) external view onlyFactory returns (uint64, uint64, int64, uint256) {
        uint64 gross_bal = _grossStableBalance(_stables);
        uint64 owed_bal = _owedStableBalance();
        int64 net_bal = int64(gross_bal) - int64(owed_bal);
        // return (gross_bal, owed_bal, net_bal, totalSupply());
        return (gross_bal, owed_bal, net_bal, IERC20(CALLIT_FACT_ADDR).totalSupply());
        
    }
    function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) external onlyFactory() { // allows duplicates
        if (_add) {
            WHITELIST_USD_STABLES = CALLIT_LIB._addAddressToArraySafe(_usdStable, WHITELIST_USD_STABLES, true); // true = no dups
            USD_STABLES_HISTORY = CALLIT_LIB._addAddressToArraySafe(_usdStable, USD_STABLES_HISTORY, true); // true = no dups
            USD_STABLE_DECIMALS[_usdStable] = _decimals;
        } else {
            WHITELIST_USD_STABLES = CALLIT_LIB._remAddressFromArray(_usdStable, WHITELIST_USD_STABLES);
        }
    }
    function _editDexRouters(address _router, bool _add) external onlyFactory() {
        require(_router != address(0x0), "0 address");
        if (_add) {
            USWAP_V2_ROUTERS = CALLIT_LIB._addAddressToArraySafe(_router, USWAP_V2_ROUTERS, true); // true = no dups
        } else {
            USWAP_V2_ROUTERS = CALLIT_LIB._remAddressFromArray(_router, USWAP_V2_ROUTERS); // removes only one & order NOT maintained
        }
    }
    function _getStableHeldHighMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {

        address[] memory _stablesHeld;
        for (uint8 i=0; i < _stables.length;) {
            if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
                _stablesHeld = CALLIT_LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

            unchecked {
                i++;
            }
        }
        return CALLIT_LIB._getStableTokenHighMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    }
    function _getStableHeldLowMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers) private view returns (address) {
        // NOTE: if nothing in _stables can cover _usdAmntReq, then returns address(0x0)
        address[] memory _stablesHeld;
        for (uint8 i=0; i < _stables.length;) {
            if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
                _stablesHeld = CALLIT_LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

            unchecked {
                i++;
            }
        }
        return CALLIT_LIB._getStableTokenLowMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    }
    function _stableHoldingsCovered(uint64 _usdAmnt, address _usdStable) private view returns (bool) {
        if (_usdStable == address(0x0)) 
            return false;
        uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
        return IERC20(_usdStable).balanceOf(address(this)) >= usdAmnt_;
    }
    function _getTokMarketValueForUsdAmnt(uint256 _usdAmnt, address _usdStable, address[] memory _stab_tok_path) private view returns (uint256) {
        uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
        (, uint256 tok_amnt) = CALLIT_LIB._best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);
        return tok_amnt; 
    }
    function _exeSwapPlsForStable(uint256 _plsAmnt, address _usdStable) external onlyFactory() returns (uint256) {
        address[] memory pls_stab_path = new address[](2);
        pls_stab_path[0] = TOK_WPLS;
        pls_stab_path[1] = _usdStable;
        (uint8 rtrIdx,) = CALLIT_LIB._best_swap_v2_router_idx_quote(pls_stab_path, _plsAmnt, USWAP_V2_ROUTERS);
        uint256 stab_amnt_out = CALLIT_LIB._swap_v2_wrap(pls_stab_path, USWAP_V2_ROUTERS[rtrIdx], _plsAmnt, address(this), true); // true = fromETH
        stab_amnt_out = CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_usdStable], stab_amnt_out, _usd_decimals());
        return stab_amnt_out;
    }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapTokForStable(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        
        (uint8 rtrIdx,) = CALLIT_LIB._best_swap_v2_router_idx_quote(_tok_stab_path, _tokAmnt, USWAP_V2_ROUTERS);
        uint256 stable_amnt_out = CALLIT_LIB._swap_v2_wrap(_tok_stab_path, USWAP_V2_ROUTERS[rtrIdx], _tokAmnt, _receiver, false); // true = fromETH        
        return stable_amnt_out;
    }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) external onlyFactory() returns (uint256) {
        address usdStable = _stab_tok_path[0]; // required: _stab_tok_path[0] must be a stable
        uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[usdStable]);
        (uint8 rtrIdx,) = CALLIT_LIB._best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);

        // NOTE: algo to account for contracts unable to be a receiver of its own token in UniswapV2Pool.sol
        // if out token in _stab_tok_path is BST, then swap w/ SWAP_DELEGATE as reciever,
        //   and then get tok_amnt_out from delegate (USER_maintenance)
        // else, swap with BST address(this) as receiver 
        // if (_stab_tok_path[_stab_tok_path.length-1] == address(this) && _receiver == address(this))  {
        //     uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, SWAP_DELEGATE, false); // true = fromETH
        //     SWAPD.USER_maintenance(tok_amnt_out, _stab_tok_path[_stab_tok_path.length-1]);
        //     return tok_amnt_out;
        // } else {
        //     uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
        //     return tok_amnt_out;
        // }

        uint256 tok_amnt_out = CALLIT_LIB._swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
        return tok_amnt_out;
    }
    // note: migrate to CallitBank
    function _payUsdReward(uint64 _usdReward, address _receiver) external onlyFactory() {
        if (_usdReward == 0) {
            emit AlertZeroReward(msg.sender, _usdReward, _receiver);
            return;
        }
        // Get stable to work with ... (any stable that covers 'usdReward' is fine)
        //  NOTE: if no single stable can cover 'usdReward', lowStableHeld == 0x0, 
        address lowStableHeld = _getStableHeldLowMarketValue(_usdReward, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        require(lowStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // pay _receiver their usdReward w/ lowStableHeld (any stable thats covered)
        IERC20(lowStableHeld).transfer(_receiver, CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdReward, USD_STABLE_DECIMALS[lowStableHeld]));
    }
    // note: migrate to CallitBank
    function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) external onlyFactory() returns(uint256, address){
        // Get stable to work with ... (any stable that covers '_usdAmnt' is fine)
        //  NOTE: if no single stable can cover '_usdAmnt', highStableHeld == 0x0, 
        address highStableHeld = _getStableHeldHighMarketValue(_usdAmnt, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        require(highStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // create path and perform stable-to-stable swap
        // address[2] memory stab_stab_path = [highStableHeld, _tickStable];
        address[] memory stab_stab_path = new address[](3);
        stab_stab_path[0] = highStableHeld;
        stab_stab_path[1] = _tickStable;
        uint256 stab_amnt_out = _exeSwapTokForStable(_usdAmnt, stab_stab_path, address(this)); // no tick: use best from USWAP_V2_ROUTERS
        return (stab_amnt_out,highStableHeld);
    }
    // note: migrate to CallitBank at least, and maybe CallitLib as well
    // Assumed helper functions (implementations not shown)
    function _createDexLP(address _uswapV2Router, address _uswapv2Factory, address _token, address _usdStable, uint256 _tokenAmount, uint256 _usdAmount) external onlyFactory returns (address) {
        // declare factory & router
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(_uswapV2Router);
        IUniswapV2Factory uniswapFactory = IUniswapV2Factory(_uswapv2Factory);

        // normalize decimals _usdStable token requirements
        _usdAmount = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmount, USD_STABLE_DECIMALS[_usdStable]);

        // Approve tokens for Uniswap Router
        IERC20(_token).approve(_uswapV2Router, _tokenAmount);
        // Assuming you have a way to convert USD to ETH or a stablecoin in the contract
            
        // Add liquidity to the pool
        // (uint256 amountToken, uint256 amountETH, uint256 liquidity) = uniswapRouter.addLiquidity(
        uniswapRouter.addLiquidity(
            _token,                // Token address
            _usdStable,           // Assuming ETH as the second asset (or replace with another token address)
            _tokenAmount,          // Desired _token amount
            _usdAmount,            // Desired ETH amount (converted from USD or directly provided)
            0,                    // Min amount of _token (slippage tolerance)
            0,                    // Min amount of ETH (slippage tolerance)
            address(this),        // Recipient of liquidity tokens
            block.timestamp + 300 // Deadline (5 minutes from now)
        );

        // Return the address of the liquidity pool
        // For Uniswap V2, the LP address is not directly returned but you can obtain it by querying the factory.
        // This example assumes you store or use the liquidity tokens or LP in your contract directly.

        // The actual LP address retrieval would require interaction with Uniswap V2 Factory.
        // For simplicity, we're returning a placeholder.
        // Retrieve the LP address
        address lpAddress = uniswapFactory.getPair(_token, _usdStable);
        return lpAddress;

        // NOTE: LEFT OFF HERE ... may need external support functions for LP & LP token maintence, etc.
        //      similar to accessors that retrieve native and ERC20 tokens held by contract
        //      maybe a function to trasnfer LP to an EOA
        //      maybe a function to manually pull all LP into this contract (or a specific receiver)
    }
}