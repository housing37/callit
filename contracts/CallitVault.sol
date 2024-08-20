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
    uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'
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
        _edit_ACCT_USD_BALANCES(_acct, _usdAmnt, _add);
    }
    function set_ACCOUNTS(address[] calldata _accts) external onlyFactory() {
        ACCOUNTS = _accts;
    }
    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // legacy
    event KeeperTransfer(address _prev, address _new);
    event WhitelistStableUpdated(address _usdStable, uint8 _decimals, bool _add);
    event DexRouterUpdated(address _router, bool _add);
    event DepositReceived(address _account, uint256 _plsDeposit, uint64 _stableConvert);
    // callit
    event AlertStableSwap(uint256 _tickStableReq, uint256 _contrStableBal, address _swapFromStab, address _swapToTickStab, uint256 _tickStabAmntNeeded, uint256 _swapAmountOut);
    event AlertZeroReward(address _sender, uint64 _usdReward, address _receiver);
    event PromoRewardPaid(address _promoCodeHash, uint64 _usdRewardPaid, address _promotor, address _buyer, address _ticket);
    event PromoBuyPerformed(address _buyer, address _promoCodeHash, address _usdStable, address _ticket, uint64 _grossUsdAmnt, uint64 _netUsdAmnt, uint256  _tickAmntOut);

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
    // legacy
    function KEEPER_maintenance(address _tokAddr, uint256 _tokAmnt) external onlyKeeper() {
        //  NOTE: _tokAmnt must be in uint precision to _tokAddr.decimals()
        require(IERC20(_tokAddr).balanceOf(address(this)) >= _tokAmnt, ' not enough amount for token :O ');
        IERC20(_tokAddr).transfer(KEEPER, _tokAmnt);
        // emit KeeperMaintenance(_tokAddr, _tokAmnt);
    }
    function KEEPER_withdraw(uint256 _natAmnt) external onlyKeeper {
        require(address(this).balance >= _natAmnt, " Insufficient native PLS balance :[ ");
        payable(KEEPER).transfer(_natAmnt); // cast to a 'payable' address to receive ETH
        // emit KeeperWithdrawel(_natAmnt);
    }
    function KEEPER_setKeeper(address _newKeeper) external onlyKeeper {
        require(_newKeeper != address(0), 'err: 0 address');
        address prev = address(KEEPER);
        KEEPER = _newKeeper;
        emit KeeperTransfer(prev, KEEPER);
    }
    function KEEPER_setKeeperCheck(uint256 _keeperCheck) external onlyKeeper {
        KEEPER_CHECK = _keeperCheck;
    }
    function KEEPER_collectiveStableBalances(bool _history, uint256 _keeperCheck) external view onlyKeeper() returns (uint64, uint64, int64, uint256) {
        require(_keeperCheck == KEEPER_CHECK, ' KEEPER_CHECK failed :( ');
        if (_history)
            return _collectiveStableBalances(USD_STABLES_HISTORY);
        return _collectiveStableBalances(WHITELIST_USD_STABLES);
    }
    function KEEPER_editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) external onlyKeeper {
        require(_usdStable != address(0), 'err: 0 address');
        _editWhitelistStables(_usdStable, _decimals, _add);
        emit WhitelistStableUpdated(_usdStable, _decimals, _add);
    }
    function KEEPER_editDexRouters(address _router, bool _add) external onlyKeeper {
        require(_router != address(0x0), "0 address");
        _editDexRouters(_router, _add);
        emit DexRouterUpdated(_router, _add);
    }
    // callit
    function KEEPER_withdrawTicketLP(address _ticket, bool _all) external view onlyKeeper {
        require(_ticket != address(0), ' !_ticket indy :) ' );
        if (_all) { // LEFT OFF HERE ...
            // loop through market for _ticket and withdraw all LP
        } else {
            // withdraw LP from just _ticket (this might not be logical)
        }
    }
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
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    // legacy
    function getAccounts() external view returns (address[] memory) {
        return ACCOUNTS;
    }
    function getUsdStablesHistory() external view returns (address[] memory) {
        return USD_STABLES_HISTORY;
    }    
    function getWhitelistStables() external view returns (address[] memory) {
        return WHITELIST_USD_STABLES;
    }
    function getDexRouters() external view returns (address[] memory) {
        return USWAP_V2_ROUTERS;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - SUPPORTING (CALLIT market management) _ // note: migrate to CallitVault (ALL)
    /* -------------------------------------------------------- */
    // handle contract USD value deposits (convert PLS to USD stable)
    receive() external payable {
        // extract PLS value sent
        uint256 amntIn = msg.value; 

        // get whitelisted stable with lowest market value (ie. receive most stable for swap)
        address usdStable = _getStableTokenLowMarketValue(WHITELIST_USD_STABLES, USWAP_V2_ROUTERS);

        // perform swap from PLS to stable & send to vault
        uint256 stableAmntOut = _exeSwapPlsForStable(amntIn, usdStable); // _normalizeStableAmnt

        // convert and set/update balance for this sender, ACCT_USD_BALANCES stores uint precision to 6 decimals
        uint64 usdAmntConvert = CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[usdStable], stableAmntOut, _usd_decimals()));

        // use VAULT remote
        _edit_ACCT_USD_BALANCES(msg.sender, usdAmntConvert, true); // true = add
        ACCOUNTS = CALLIT_LIB._addAddressToArraySafe(msg.sender, ACCOUNTS, true); // true = no dups

        emit DepositReceived(msg.sender, amntIn, usdAmntConvert);

        // NOTE: at this point, the vault has the deposited stable and the vault has stored account balances
    }
    function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok, uint16 _percPromoBuyFee) external onlyFactory {
        // calc influencer reward from _usdAmnt to send to promo.promotor
        uint64 usdReward = CALLIT_LIB._perc_of_uint64(_percReward, _usdAmnt);
        _payUsdReward(usdReward, _promotor); // pay w/ lowest value whitelist stable held (returns on 0 reward)
        emit PromoRewardPaid(_promoCodeHash, usdReward, _promotor, msg.sender, _ticket);

        // deduct usdReward & promo buy fee _usdAmnt
        uint64 net_usdAmnt = _usdAmnt - usdReward;
        net_usdAmnt = CALLIT_LIB._deductFeePerc(net_usdAmnt, _percPromoBuyFee, _usdAmnt);

        // verifiy contract holds enough tick_stable_tok for DEX buy
        //  if not, swap another contract held stable that can indeed cover
        // address tick_stable_tok = mark.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
        // address tick_stable_tok = mark.marketResults.resultTokenUsdStables[tickIdx]; // get _ticket assigned stable (DEX trade amountsIn)
        uint256 contr_stab_bal = IERC20(_tick_stable_tok).balanceOf(address(this)); 
        if (contr_stab_bal < net_usdAmnt) { // not enough tick_stable_tok to cover 'net_usdAmnt' buy
            uint64 net_usdAmnt_needed = net_usdAmnt - CALLIT_LIB._uint64_from_uint256(contr_stab_bal);
            (uint256 stab_amnt_out, address stab_swap_from)  = _swapBestStableForTickStable(net_usdAmnt_needed, _tick_stable_tok);
            emit AlertStableSwap(net_usdAmnt, contr_stab_bal, stab_swap_from, _tick_stable_tok, net_usdAmnt_needed, stab_amnt_out);

            // verify
            require(IERC20(_tick_stable_tok).balanceOf(address(this)) >= net_usdAmnt, ' tick-stable swap failed :[] ' );
        }

        // swap remaining net_usdAmnt of tick_stable_tok for _ticket on DEX (_ticket receiver = msg.sender)
        // address[] memory usd_tick_path = [tick_stable_tok, _ticket]; // ref: https://ethereum.stackexchange.com/a/28048
        address[] memory usd_tick_path = new address[](2);
        usd_tick_path[0] = _tick_stable_tok;
        usd_tick_path[1] = _ticket; // NOTE: not swapping for 'this' contract
        uint256 tick_amnt_out = _exeSwapStableForTok(net_usdAmnt, usd_tick_path, msg.sender); // msg.sender = _receiver

        // deduct full OG input _usdAmnt from account balance
        // CALLIT_VAULT.ACCT_USD_BALANCES[msg.sender] -= _usdAmnt;
        _edit_ACCT_USD_BALANCES(msg.sender, _usdAmnt, false); // false = sub

        // emit log
        emit PromoBuyPerformed(msg.sender, _promoCodeHash, _tick_stable_tok, _ticket, _usdAmnt, net_usdAmnt, tick_amnt_out);
    }
    function _logMarketResultReview(address _maker, uint256 _markNum, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) external view onlyFactory returns(ICallitLib.MARKET_REVIEW memory, uint64, uint64) {
        uint64 agreeCnt = 0;
        uint64 disagreeCnt = 0;
        uint64 reviewCnt = CALLIT_LIB._uint64_from_uint256(_makerReviews.length);
        if (reviewCnt > 0) {
            agreeCnt = _makerReviews[reviewCnt-1].agreeCnt;
            disagreeCnt = _makerReviews[reviewCnt-1].disagreeCnt;
        }

        agreeCnt = _resultAgree ? agreeCnt+1 : agreeCnt;
        disagreeCnt = !_resultAgree ? disagreeCnt+1 : disagreeCnt;
        return (ICallitLib.MARKET_REVIEW(msg.sender, _resultAgree, _maker, _markNum, agreeCnt, disagreeCnt), agreeCnt, disagreeCnt);
    }
    function _validVoteCount(uint256 _voterCallBal, uint64 _votesEarned, uint256 _voterLockTime, uint256 _markCreateTime) external view onlyFactory() returns(uint64) {
        // if indeed locked && locked before _mark start time, calc & return active vote count
        if (_voterLockTime > 0 && _voterLockTime <= _markCreateTime) {
            uint64 votes_earned = _votesEarned; // note: EARNED_CALL_VOTES stores uint64 type
            uint64 votes_held = CALLIT_LIB._uint64_from_uint256(_voterCallBal);
            uint64 votes_active = votes_held >= votes_earned ? votes_earned : votes_held;
            return votes_active;
        }
        else
            return 0; // return no valid votes
    }
    function _getWinningVoteIdxForMarket(uint64[] memory _resultTokenVotes) external view onlyFactory returns(uint16) {
        // travers mark.resultTokenVotes for winning idx
        //  NOTE: default winning index is 0 & ties will settle on lower index
        uint16 idxCurrHigh = 0;
        // for (uint16 i = 0; i < _mark.marketResults.resultTokenVotes.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
        //     if (_mark.marketResults.resultTokenVotes[i] > _mark.marketResults.resultTokenVotes[idxCurrHigh])
        //         idxCurrHigh = i;
        //     unchecked {i++;}
        // }
        for (uint16 i = 0; i < _resultTokenVotes.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            if (_resultTokenVotes[i] > _resultTokenVotes[idxCurrHigh])
                idxCurrHigh = i;
            unchecked {i++;}
        }
        return idxCurrHigh;
    }
    function _addressIsMarketMakerOrCaller(address _addr, address _markMaker, address[] memory _resultOptionTokens) external view onlyFactory returns(bool, bool) {
        // bool is_maker = _mark.maker == msg.sender; // true = found maker
        // bool is_caller = false;
        // for (uint16 i = 0; i < _mark.marketResults.resultOptionTokens.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
        //     is_caller = IERC20(_mark.marketResults.resultOptionTokens[i]).balanceOf(_addr) > 0; // true = found caller
        //     unchecked {i++;}
        // }

        bool is_maker = _markMaker == msg.sender; // true = found maker
        bool is_caller = false;
        for (uint16 i = 0; i < _resultOptionTokens.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            is_caller = IERC20(_resultOptionTokens[i]).balanceOf(_addr) > 0; // true = found caller
            unchecked {i++;}
        }

        return (is_maker, is_caller);
    }
    function _getCallTicketUsdTargetPrice(address[] memory _resultTickets, address[] memory _pairAddresses, address[] memory _resultStables, address _ticket, uint64 _usdMinTargetPrice) external view onlyFactory returns(uint64) {
        require(_resultTickets.length == _pairAddresses.length, ' tick/pair arr length mismatch :o ');
        // algorithmic logic ...
        //  calc sum of usd value dex prices for all addresses in '_mark.resultOptionTokens' (except _ticket)
        //   -> input _ticket target price = 1 - SUM(all prices except _ticket)
        //   -> if result target price <= 0, then set/return input _ticket target price = $0.01

        // address[] memory tickets = _mark.marketResults.resultOptionTokens;
        address[] memory tickets = _resultTickets;
        uint64 alt_sum = 0;
        for(uint16 i=0; i < tickets.length;) { // MAX_RESULTS is uint16
            if (tickets[i] != _ticket) {
                // address pairAddress = _mark.marketResults.resultTokenLPs[i];
                address pairAddress = _pairAddresses[i];
                
                // uint256 usdAmountsOut = _estimateLastPriceForTCK(pairAddress, _mark.marketResults.resultTokenUsdStables[i]); // invokes _normalizeStableAmnt
                // alt_sum += usdAmountsOut;

                uint256 usdAmountsOut = CALLIT_LIB._estimateLastPriceForTCK(pairAddress); // invokes _normalizeStableAmnt
                alt_sum += CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_resultStables[i]], usdAmountsOut, _usd_decimals()));
            }
            
            unchecked {i++;}
        }

        // NOTE: returns negative if alt_sum is greater than 1
        //  edge case should be handle in caller
        int64 target_price = 1 - int64(alt_sum);
        return target_price > 0 ? uint64(target_price) : _usdMinTargetPrice; // note: min is likely 10000 (ie. $0.010000 w/ _usd_decimals() = 6)
    }


    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (legacy) _ // note: migrate to CallitBank (ALL)
    /* -------------------------------------------------------- */
    function _edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) private {
        if (_add) ACCT_USD_BALANCES[_acct] += _usdAmnt;
        else {
            require(ACCT_USD_BALANCES[_acct] >= _usdAmnt, ' !deduct low balance :{} ');
            ACCT_USD_BALANCES[_acct] -= _usdAmnt;    
        }
    }
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
    function _collectiveStableBalances(address[] memory _stables) private view returns (uint64, uint64, int64, uint256) {
        uint64 gross_bal = _grossStableBalance(_stables);
        uint64 owed_bal = _owedStableBalance();
        int64 net_bal = int64(gross_bal) - int64(owed_bal);
        // return (gross_bal, owed_bal, net_bal, totalSupply());
        return (gross_bal, owed_bal, net_bal, IERC20(CALLIT_FACT_ADDR).totalSupply());
        
    }
    function _editWhitelistStables(address _usdStable, uint8 _decimals, bool _add) private { // allows duplicates
        if (_add) {
            WHITELIST_USD_STABLES = CALLIT_LIB._addAddressToArraySafe(_usdStable, WHITELIST_USD_STABLES, true); // true = no dups
            USD_STABLES_HISTORY = CALLIT_LIB._addAddressToArraySafe(_usdStable, USD_STABLES_HISTORY, true); // true = no dups
            USD_STABLE_DECIMALS[_usdStable] = _decimals;
        } else {
            WHITELIST_USD_STABLES = CALLIT_LIB._remAddressFromArray(_usdStable, WHITELIST_USD_STABLES);
        }
    }
    function _editDexRouters(address _router, bool _add) private {
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
        return _getStableTokenHighMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
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
        return _getStableTokenLowMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    }
    function _stableHoldingsCovered(uint64 _usdAmnt, address _usdStable) private view returns (bool) {
        if (_usdStable == address(0x0)) 
            return false;
        uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
        return IERC20(_usdStable).balanceOf(address(this)) >= usdAmnt_;
    }
    function _getTokMarketValueForUsdAmnt(uint256 _usdAmnt, address _usdStable, address[] memory _stab_tok_path) private view returns (uint256) {
        uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[_usdStable]);
        (, uint256 tok_amnt) = _best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);
        return tok_amnt; 
    }
    function _exeSwapPlsForStable(uint256 _plsAmnt, address _usdStable) private returns (uint256) {
        address[] memory pls_stab_path = new address[](2);
        pls_stab_path[0] = TOK_WPLS;
        pls_stab_path[1] = _usdStable;
        (uint8 rtrIdx,) = _best_swap_v2_router_idx_quote(pls_stab_path, _plsAmnt, USWAP_V2_ROUTERS);
        uint256 stab_amnt_out = _swap_v2_wrap(pls_stab_path, USWAP_V2_ROUTERS[rtrIdx], _plsAmnt, address(this), true); // true = fromETH
        stab_amnt_out = CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_usdStable], stab_amnt_out, _usd_decimals());
        return stab_amnt_out;
    }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapTokForStable(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        
        (uint8 rtrIdx,) = _best_swap_v2_router_idx_quote(_tok_stab_path, _tokAmnt, USWAP_V2_ROUTERS);
        uint256 stable_amnt_out = _swap_v2_wrap(_tok_stab_path, USWAP_V2_ROUTERS[rtrIdx], _tokAmnt, _receiver, false); // true = fromETH        
        return stable_amnt_out;
    }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapStableForTok(uint256 _usdAmnt, address[] memory _stab_tok_path, address _receiver) private returns (uint256) {
        address usdStable = _stab_tok_path[0]; // required: _stab_tok_path[0] must be a stable
        uint256 usdAmnt_ = CALLIT_LIB._normalizeStableAmnt(_usd_decimals(), _usdAmnt, USD_STABLE_DECIMALS[usdStable]);
        (uint8 rtrIdx,) = _best_swap_v2_router_idx_quote(_stab_tok_path, usdAmnt_, USWAP_V2_ROUTERS);

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

        uint256 tok_amnt_out = _swap_v2_wrap(_stab_tok_path, USWAP_V2_ROUTERS[rtrIdx], usdAmnt_, _receiver, false); // true = fromETH
        return tok_amnt_out;
    }
    // note: migrate to CallitBank
    function _payUsdReward(uint64 _usdReward, address _receiver) public onlyFactory() {
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
    function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) private returns(uint256, address){
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
        IERC20(_usdStable).approve(_uswapV2Router, _usdAmount);
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

    /* -------------------------------------------------------- */
    /* PRIVATE - DEX QUOTE SUPPORT                                    
    /* -------------------------------------------------------- */
    // specify router to use
    function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        uint256 tok_amnt_out = _swap_v2_wrap(_tok_stab_path, _router, _tokAmnt, _receiver, false); // true = fromETH
        return tok_amnt_out;
    }
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) private view returns (address) {
        // traverse _stables & select stable w/ the lowest market value
        uint256 curr_high_tok_val = 0;
        address curr_low_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the most when swapped 'from' WPLS
            //  the more USD stable received for 1 WPLS ~= the less overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_high_tok_val) {
                curr_high_tok_val = tok_val;
                curr_low_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_low_val_stable;
    }
    
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) private view returns (address) {
        // traverse _stables & select stable w/ the highest market value
        uint256 curr_low_tok_val = 0;
        address curr_high_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the least when swapped 'from' WPLS
            //  the less USD stable received for 1 WPLS ~= the more overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_low_tok_val) {
                curr_low_tok_val = tok_val;
                curr_high_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_high_val_stable;
    }

    // uniswap v2 protocol based: get router w/ best quote in 'uswapV2routers'
    function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) private view returns (uint8, uint256) {
        uint8 currHighIdx = 37;
        uint256 currHigh = 0;
        for (uint8 i = 0; i < _routers.length;) {
            uint256[] memory amountsOut = IUniswapV2Router02(_routers[i]).getAmountsOut(amount, path); // quote swap
            if (amountsOut[amountsOut.length-1] > currHigh) {
                currHigh = amountsOut[amountsOut.length-1];
                currHighIdx = i;
            }

            // NOTE: unchecked, never more than 255 (_routers)
            unchecked {
                i++;
            }
        }

        return (currHighIdx, currHigh);
    }
    // uniwswap v2 protocol based: get quote and execute swap
    function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) private returns (uint256) {
        require(path.length >= 2, 'err: path.length :/');
        uint256 amntOutQuote = _swap_v2_quote(path, router, amntIn);
        uint256 amntOut = _swap_v2(router, path, amntIn, amntOutQuote, outReceiver, fromETH); // approve & execute swap
                
        // verifiy new balance of token received
        uint256 new_bal = IERC20(path[path.length -1]).balanceOf(outReceiver);
        require(new_bal >= amntOut, " _swap: receiver bal too low :{ ");
        
        return amntOut;
    }
    function _swap_v2_quote(address[] memory _path, address _dexRouter, uint256 _amntIn) private view returns (uint256) {
        uint256[] memory amountsOut = IUniswapV2Router02(_dexRouter).getAmountsOut(_amntIn, _path); // quote swap
        return amountsOut[amountsOut.length -1];
    }
    // v2: solidlycom, kyberswap, pancakeswap, sushiswap, uniswap v2, pulsex v1|v2, 9inch
    function _swap_v2(address router, address[] memory path, uint256 amntIn, uint256 amntOutMin, address outReceiver, bool fromETH) private returns (uint256) {
        IUniswapV2Router02 swapRouter = IUniswapV2Router02(router);
        
        IERC20(address(path[0])).approve(address(swapRouter), amntIn);
        uint deadline = block.timestamp + 300;
        uint[] memory amntOut;
        if (fromETH) {
            amntOut = swapRouter.swapExactETHForTokens{value: amntIn}(
                            amntOutMin,
                            path, //address[] calldata path,
                            outReceiver, // to
                            deadline
                        );
        } else {
            amntOut = swapRouter.swapExactTokensForTokens(
                            amntIn,
                            amntOutMin,
                            path, //address[] calldata path,
                            outReceiver, //  The address that will receive the output tokens after the swap. 
                            deadline
                        );
        }
        return uint256(amntOut[amntOut.length - 1]); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
    }
}