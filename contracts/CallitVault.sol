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
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; // deploy
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// import "./CallitTicket.sol"; // imports ERC20.sol // declares ICallitVault.deposit
import "./ICallitLib.sol";
import "./ICallitConfig.sol";

interface IERC20x {
    function decimals() external pure returns (uint8);
    function approve(address spender, uint256 value) external returns (bool);
}

interface ICallitTicket { 
    function mintForPriceParity(address _receiver, uint256 _amount) external;
    function balanceOf(address account) external returns(uint256);
}

contract CallitVault {
    /* _ ADMIN SUPPORT (legacy) _ */
    bool private FIRST_ = true;
    string public constant tVERSION = '0.49';  
    address public ADDR_CONFIG; // set via CONF_setConfig
    ICallitConfig private CONF; // set via CONF_setConfig
    ICallitLib private LIB;     // set via CONF_setConfig

    /* -------------------------------------------------------- */
    /* GLOBALS (STORAGE)
    /* -------------------------------------------------------- */
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    // address public constant BURN_ADDR = address(0x0000000000000000000000000000000000000369);

    // note: makeNewMarket
    // temp-arrays for 'makeNewMarket' support
    address[] private resultOptionTokens;
    address[] private resultTokenLPs;
    address[] private resultTokenRouters;
    address[] private resultTokenUsdStables;
    uint64 [] private resultTokenVotes;   

    /* _ ACCOUNT SUPPORT (legacy) _ */
    // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    // NOTE: all USD bals & payouts stores uint precision to 6 decimals
    // NOTE: legacy public
    mapping(address => uint64) public ACCT_USD_BALANCES; 
    address[] public ACCOUNTS; // NOTE: private is more secure; consider external KEEPER getter instead
    mapping(address => address) private TICK_PAIR_ADDR; // used for lp maintence KEEPER withdrawel
    mapping(address => uint64) public PROMO_USD_OWED; // maps promo code HASH to usd owed for that hash

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    event DepositReceived(address _account, uint256 _plsDeposit, uint64 _stableConvert);
    // event AlertStableSwap(uint256 _tickStableReq, uint256 _contrStableBal, address _swapFromStab, address _swapToTickStab, uint256 _tickStabAmntNeeded, uint256 _swapAmountOut);
    // event AlertZeroReward(address _sender, uint64 _usdReward, address _receiver);
    event PromoRewardLogged(address _promoCodeHash, uint64 _usdRewardPaid, address _promotor, address _buyer, address _ticket);

    constructor() {

    }

    /* -------------------------------------------------------- */
    /* MODIFIERS
    /* -------------------------------------------------------- */
    modifier onlyKeeper() {
        require(msg.sender == CONF.KEEPER(), " !keeper :[ ");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == CONF.ADDR_FACT() || msg.sender == CONF.ADDR_DELEGATE() || 
                msg.sender == CONF.KEEPER() || msg.sender == address(this), 
                " !keeper & !fact :p ");
        _;
    }
    modifier onlyConfig() { 
        // allows 1st onlyConfig attempt to freely pass
        //  NOTE: don't waste this on anything but CONF_setConfig
        if (!FIRST_) 
            require(msg.sender == address(CONF), ' !CONF :p ');
        FIRST_ = false;
        _;
    }
    function CONF_setConfig(address _conf) external onlyConfig() {
        require(_conf != address(0), ' !addy :< ');
        ADDR_CONFIG = _conf;
        CONF = ICallitConfig(_conf);
        LIB = ICallitLib(CONF.ADDR_LIB());
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
    /* -------------------------------------------------------- */
    // legacy
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(CONF.KEEPER()).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _tokAmnt must be in uint precision to _tokAddr.decimals()
            require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(CONF.KEEPER(), _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }
    // function KEEPER_collectiveStableBalances(bool _history, uint256 _keeperCheck) external view onlyKeeper() returns (uint64, uint64, int64) {
    function KEEPER_collectiveStableBalances(uint256 _keeperCheck) external view returns (uint64, uint64, int64) {
        require(CONF.keeperCheck(_keeperCheck), ' !_keeperCheck :( ');
        // if (_history)
        //     return _collectiveStableBalances(USD_STABLES_HISTORY);
        // return _collectiveStableBalances(WHITELIST_USD_STABLES);

        // (address[] memory stables,,) = CONF.getDexAddies();
        uint64 gross_bal = _grossStableBalance(CONF.get_WHITELIST_USD_STABLES());
        uint64 owed_bal = _owedStableBalance();
        int64 net_bal = int64(gross_bal) - int64(owed_bal);
        return (gross_bal, owed_bal, net_bal);
    }
    // callit
    function KEEPER_withdrawTicketLP(address _ticket) external onlyKeeper {
        // NOTE: can only withdraw LP from one _ticket at a time
        //  bc no current way to get market for _ticket (from FACTORY)
        IERC20(TICK_PAIR_ADDR[_ticket]).transfer(CONF.KEEPER(), IERC20(TICK_PAIR_ADDR[_ticket]).balanceOf(address(this)));
    }
    // function KEEPER_logTicketPair(address _ticket, address _pair) external onlyFactory() {
    //     require(_ticket != address(0) && _pair != address(0), ' 0 address :[ ');
    //     TICK_PAIR_ADDR[_ticket] = _pair;
    // }

    /* -------------------------------------------------------- */
    /* PUBLIC - ACCESSORS
    /* -------------------------------------------------------- */
    // NOTE: attempts to refactor this function into a global, 
    //  results in increased compilation file size (despite being invoked 11 or 12)
    function _usd_decimals() public pure returns (uint8) {
        return 6; // (6 decimals) 
            // * min USD = 0.000001 (6 decimals) 
            // uint16 max USD: ~0.06 -> 0.065535 (6 decimals)
            // uint32 max USD: ~4K -> 4,294.967295 USD (6 decimals)
            // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)
    }
    function getAccounts() external view returns (address[] memory) {
        return ACCOUNTS;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - SUPPORTING (CALLIT market management)
    /* -------------------------------------------------------- */
    // Fallback function to handle Ether and address from msg.data
    //  Encoding the address and sending it along with Ether
    //      (address(myContract).call{value: 1 ether}(abi.encodeWithSignature("functionWithAddress(address)", targetAddress)));

    /* ref: https://docs.soliditylang.org/en/latest/contracts.html#fallback-function
        The fallback function is executed on a call to the contract if none of the other 
        functions match the given function signature, 
        or if no data was supplied at all and there is no receive Ether function. 
        The fallback function always receives data, but in order to also receive Ether it must be marked payable.
    */
    // invoked if function invoked doesn't exist OR no receive() implemented & ETH received w/o data
    fallback() external payable {
        deposit(msg.sender); // emit DepositReceived
        // NOTE: at this point, the vault has the deposited stable and the vault has stored account balances
    }
    
    /** ref: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
         The receive function is executed on a call to the contract with empty calldata. 
         This is the function that is executed on plain Ether transfers (e.g. via .send() or .transfer()). 
         If no such function exists, but a payable fallback function exists, 
          the fallback function will be called on a plain Ether transfer. 
         If neither a receive Ether nor a payable fallback function is present, 
          the contract cannot receive Ether through a transaction that does not represent 
          a payable function call and throws an exception.
     */
    // handle contract USD value deposits (convert PLS to USD stable)
    // receive() external payable {
    //     // extract PLS value sent
    //     uint256 amntIn = msg.value;
    // }
    function deposit(address _depositor) public payable {
        // address _depositor = msg.sender;
        uint256 msgValue = msg.value;

        // perform swap from PLS to stable & send to vault
        // address[2] memory pls_stab_path_x = [TOK_WPLS, CONF.DEPOSIT_USD_STABLE()];
        address[] memory pls_stab_path = new address[](2);
        pls_stab_path[0] = TOK_WPLS; // note: WPLS required for 'swapExactETHForTokens'
        pls_stab_path[1] = CONF.DEPOSIT_USD_STABLE();
        IUniswapV2Router02 swapRouter = IUniswapV2Router02(CONF.DEPOSIT_ROUTER());
        uint256[] memory amountsOut = swapRouter.getAmountsOut(msgValue, pls_stab_path); // quote swap
        IERC20(address(pls_stab_path[0])).approve(address(swapRouter), msgValue);
        uint[] memory amntOut = swapRouter.swapExactETHForTokens{value: msgValue}(
                                    amountsOut[amountsOut.length -1],
                                    pls_stab_path, //address[] calldata path,
                                    address(this), // to (receiver)
                                    block.timestamp + 300
                                );
        // uint64 stableAmntOut = _uint64_from_uint256(amntOut[amntOut.length - 1]); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
        uint64 stableAmntOut = _uint64_from_uint256(_normalizeStableAmnt(IERC20x(pls_stab_path[1]).decimals(), amntOut[amntOut.length - 1], _usd_decimals())); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
        
        // update account balance
        ACCT_USD_BALANCES[_depositor] += stableAmntOut;
        ACCOUNTS = LIB._addAddressToArraySafe(_depositor, ACCOUNTS, true); // true = no dups

        emit DepositReceived(_depositor, msgValue, stableAmntOut);

        // NOTE: at this point, the vault has the deposited stable and the vault has stored account balances
    }
    // function exeArbPriceParityForTicket(ICallitLib.MARKET memory mark, uint16 tickIdx, uint64 _minUsdTargPrice, address _sender) external onlyFactory returns(uint64, uint64, uint64, uint64, uint64) { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
    function exeArbPriceParityForTicket(ICallitLib.MARKET memory mark, uint16 tickIdx, address _sender) external onlyFactory returns(uint64, uint64, uint64, uint64, uint64) { // _deductFeePerc PERC_ARB_EXE_FEE from arb profits
        // calc target usd price for _ticket (in order to bring this market to price parity)
        //  note: indeed accounts for sum of alt result ticket prices in market >= $1.00
        //      ie. simply returns: _ticket target price = $0.01 (MIN_USD_CALL_TICK_TARGET_PRICE default)
        uint64 ticketTargetPriceUSD = LIB._getCallTicketUsdTargetPrice(mark, tickIdx, CONF.MIN_USD_CALL_TICK_TARGET_PRICE(), _usd_decimals());
        
        // calc # of _ticket tokens to mint for DEX sell (to bring _ticket to price parity w/ target price)
        //  mint tokensToMint count to this VAULT and sell on DEX on behalf of _arbExecuter
        //  deduct fees and pay _arbExecuter (_sender)
        (uint64 tokensToMint, uint64 total_usd_cost) = _performTicketMint(mark, tickIdx, ticketTargetPriceUSD, _sender);
        (uint64 gross_stab_amnt_out, uint64 net_usd_profits) = _performTicketMintedDexSell(mark, tickIdx, tokensToMint, total_usd_cost, _sender);
        return (ticketTargetPriceUSD, tokensToMint, total_usd_cost, gross_stab_amnt_out, net_usd_profits);
    }
    function _payPromotorDeductFeesBuyTicket(uint16 _percReward, uint64 _usdAmnt, address _promotor, address _promoCodeHash, address _ticket, address _tick_stable_tok, address _sender) external onlyFactory returns(uint64, uint256) {
        // NOTE: *WARNING* if this require fails ... 
        //  then this promo code cannot be used until PERC_PROMO_BUY_FEE is lowered accordingly
        require(_percReward + CONF.PERC_PROMO_BUY_FEE() < 10000, ' buy promo fee perc mismatch :o ');

        // calc influencer reward from _usdAmnt to send to promo.promotor
        //  and update amount owed for this _promoCodeHash
        uint64 usdReward = LIB._perc_of_uint64(_percReward, _usdAmnt);
        PROMO_USD_OWED[_promoCodeHash] += usdReward;
        emit PromoRewardLogged(_promoCodeHash, usdReward, _promotor, _sender, _ticket);

        // deduct usdReward & promo buy fee _usdAmnt
        uint64 net_usdAmnt = _usdAmnt - usdReward;
        net_usdAmnt = LIB._deductFeePerc(net_usdAmnt, CONF.PERC_PROMO_BUY_FEE(), _usdAmnt);

        // verifiy this VAULT contract holds enough tick_stable_tok for DEX buy
        //  if not, swap another contract held stable that can indeed cover
        uint256 contr_stab_bal = IERC20(_tick_stable_tok).balanceOf(address(this)); 
        if (contr_stab_bal < net_usdAmnt) { // not enough tick_stable_tok to cover 'net_usdAmnt' buy
            uint64 net_usdAmnt_needed = net_usdAmnt - _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_tick_stable_tok).decimals(), contr_stab_bal, _usd_decimals()));
            // (uint256 stab_amnt_out, address stab_swap_from)  = _swapBestStableForTickStable(net_usdAmnt_needed, _tick_stable_tok);
            _swapBestStableForTickStable(net_usdAmnt_needed, _tick_stable_tok);
            // emit AlertStableSwap(net_usdAmnt, contr_stab_bal, stab_swap_from, _tick_stable_tok, net_usdAmnt_needed, stab_amnt_out);

            // verify
            require(IERC20(_tick_stable_tok).balanceOf(address(this)) >= net_usdAmnt, ' tick-stable swap failed :[] ' );
        }

        // swap remaining net_usdAmnt of tick_stable_tok for _ticket on DEX (_ticket receiver = _sender)
        // address[] memory usd_tick_path = [tick_stable_tok, _ticket]; // ref: https://ethereum.stackexchange.com/a/28048
        address[] memory usd_tick_path = new address[](2);
        usd_tick_path[0] = _tick_stable_tok;
        usd_tick_path[1] = _ticket; // NOTE: not swapping for 'this' contract
        uint256 tick_amnt_out = _exeSwapTokForTok(net_usdAmnt, usd_tick_path, _sender, true); // buyer = _receiver // true = _fromUsdAcctBal

        // deduct full OG input _usdAmnt from account balance
        edit_ACCT_USD_BALANCES(_sender, _usdAmnt, false); // false = sub

        return (net_usdAmnt, tick_amnt_out);
    }
    function payPromoUsdReward(address _sender, address _promoCodeHash, uint64 _usdReward, address _receiver) external onlyFactory returns(uint64) {
        uint64 usdOwed = PROMO_USD_OWED[_promoCodeHash];
        require(_promoCodeHash != address(0) && usdOwed > 0 && _usdReward <= usdOwed, ' not enough owed ;[ ');
        uint64 net_usdReward = LIB._deductFeePerc(usdOwed, CONF.PERC_PROMO_CLAIM_FEE(), usdOwed);
        _payUsdReward(_sender, net_usdReward, _receiver); // pay w/ lowest value whitelist stable held (returns on 0 reward)
        PROMO_USD_OWED[_promoCodeHash] = usdOwed - _usdReward; // deduct entire _usdReward from owed (not just net)
        return net_usdReward; // return what was actually paid (ie. net)
    }
    // note: migrate to CallitBank
    function _payUsdReward(address _sender, uint64 _usdReward, address _receiver) public onlyFactory() {
        if (_usdReward == 0) {
            // emit AlertZeroReward(_sender, _usdReward, _receiver);
            return;
        }
        // Get stable to work with ... (any stable that covers 'usdReward' is fine)
        //  NOTE: if no single stable can cover 'usdReward', lowStableHeld == 0x0, 
        // address lowStableHeld = _getStableHeldLowMarketValue(_usdReward, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        (address[] memory stables, address[] memory routers) = CONF.getDexAddies();
        address lowStableHeld = _getStableHeldHighLowMarketValue(_usdReward, stables, routers, false); // 3 loops embedded // false = low mark val
        
        require(lowStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // pay _receiver their usdReward w/ lowStableHeld (any stable thats covered)
        IERC20(lowStableHeld).transfer(_receiver, _normalizeStableAmnt(_usd_decimals(), _usdReward, IERC20x(lowStableHeld).decimals()));
    }

    function createDexLP(string[] calldata _resultLabels, uint256 _net_usdAmntLP, uint16 _ratioLpTokPerUsd) external onlyFactory() returns(ICallitLib.MARKET_RESULTS memory){

        // // note: makeNewMarket
        // // temp-arrays for 'makeNewMarket' support
        // address[] memory resultOptionTokens = new address[](_resultLabels.length);
        // address[] memory resultTokenLPs = new address[](_resultLabels.length);
        // address[] memory resultTokenRouters = new address[](_resultLabels.length);
        // address[] memory resultTokenFactories = new address[](_resultLabels.length);

        // address[] memory resultTokenUsdStables = new address[](_resultLabels.length);
        // uint64 [] memory resultTokenVotes = new uint64[](_resultLabels.length);

        // note: makeNewMarket
        // temp-arrays for 'makeNewMarket' support
        resultOptionTokens = new address[](_resultLabels.length);
        resultTokenLPs = new address[](_resultLabels.length);
        resultTokenRouters = new address[](_resultLabels.length);
        resultTokenUsdStables = new address[](_resultLabels.length);
        resultTokenVotes = new uint64[](_resultLabels.length);

        // Get/calc amounts for each initial LP (usd and token amounts)
        (uint256 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultLabels.length, _ratioLpTokPerUsd);

        // get router & stable to be used for each initial LP
        address router_addr = CONF.NEW_TICK_UNISWAP_V2_ROUTER();
        address stable_addr = CONF.NEW_TICK_USD_STABLE();
        IERC20x stable = IERC20x(stable_addr);
        uint8 stable_decs = stable.decimals();

        // normalize internal tracking decimals to match stable contract's decimals
        usdAmount = _normalizeStableAmnt(_usd_decimals(), usdAmount, stable_decs);
        _net_usdAmntLP = _normalizeStableAmnt(_usd_decimals(), _net_usdAmntLP, stable_decs);

        // approve router to spend this vault's total 'stable' needed
        //  note: approving '_net_usdAmntLP' for total liquidity needed
        //        not just 'usdAmount' for each individual LP created
        stable.approve(router_addr, _net_usdAmntLP);

        // Loop through _resultLabels and deploy ERC20s for each (and generate LP)
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
        // for (uint16 i = 0; i < _resultCnt;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // // Get/calc amounts for initial LP (usd and token amounts)
            // (uint256 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultLabels.length, _ratioLpTokPerUsd);
            // (uint256 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultLabels.length, RATIO_LP_TOK_PER_USD);
            // (uint64 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(_net_usdAmntLP, _resultCnt, RATIO_LP_TOK_PER_USD);

            // Deploy a new ERC20 token for each result label (init supply = tokenAmount; transfered to VAULT to create LP)
            // (string memory tok_name, string memory tok_symb) = LIB._genTokenNameSymbol(_sender, _mark_num, i, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
            // address new_tick_tok = address (new CallitTicket(tokenAmount, address(this), tok_name, tok_symb));
            // address new_tick_tok = address (new CallitTicket(tokenAmount, address(VAULT), ADDR_FACT, "tTICKET_0", "tTCK0"));
            // address new_tick_tok = address (new CallitTicket(tokenAmount, address(this), ADDR_FACT, "tTICKET_0", "tTCK0"));
            address new_tick_tok = CONF.VAULT_deployTicket(tokenAmount, "tTICKET_0", "tTCK0");
                // LEFT OFF HERE ... needs to add 'LIB._genTokenNameSymbol' integration
            
            // Create DEX LP for new ticket token (from VAULT, using VAULT's stables, and VAULT's minted new tick init supply)
            // address pairAddr = _createDexLP(NEW_TICK_UNISWAP_V2_ROUTER, NEW_TICK_UNISWAP_V2_FACTORY, new_tick_tok, NEW_TICK_USD_STABLE, tokenAmount, usdAmount);

            /** FROM VAULT */
            // address router_addr = CONF.NEW_TICK_UNISWAP_V2_ROUTER();
            // address stable_addr = CONF.NEW_TICK_USD_STABLE();
            // IERC20x stable = IERC20x(stable_addr);

            // // normalize internal tracking decimals to stable contract decimals
            // usdAmount = _normalizeStableAmnt(_usd_decimals(), usdAmount, stable.decimals());

            // // approve router to spend this vault's tokens needed
            // stable.approve(router_addr, usdAmount);

            // approve router to spend this vault's new ticket tokens needed
            IERC20(new_tick_tok).approve(router_addr, tokenAmount);

            // add liquidity (internally used factory to create pair address)
            IUniswapV2Router02 router = IUniswapV2Router02(router_addr);
            router.addLiquidity(
                new_tick_tok,                // Token address
                stable_addr,           // Assuming ETH as the second asset (or replace with another token address)
                tokenAmount,          // Desired _token amount
                usdAmount,            // Desired ETH amount (converted from USD or directly provided)
                0,                    // Min amount of _token (slippage tolerance)
                0,                    // Min amount of ETH (slippage tolerance)
                address(this),        // Recipient of liquidity tokens
                block.timestamp + 300 // Deadline (5 minutes from now)
            );

            // retreive pair address from router's factory
            address pairAddr = IUniswapV2Factory(router.factory()).getPair(new_tick_tok, stable_addr);
                // address pairAddr = address(0x3700000000000000000000000000000000000037);
            
            // map new ticket created to its pair address created
            TICK_PAIR_ADDR[new_tick_tok] = pairAddr;
            /** _FROM VAULT_ */

            // verify ERC20 & LP was created
            require(new_tick_tok != address(0) && pairAddr != address(0), ' err: gen tick tok | lp :( ');

            // set this ticket option's settings to index 'i' in storage temp results array
            //  temp array will be added to MARKET struct and returned (then deleted on function return)
            resultOptionTokens[i] = new_tick_tok;
            resultTokenLPs[i] = pairAddr;
            resultTokenRouters[i] = router_addr;
            resultTokenUsdStables[i] = stable_addr;
            resultTokenVotes[i] = 0;

            // NOTE: set ticket to maker mapping, handled from factory

            unchecked {i++;}
        }

        // deduct full OG usd input from account balance
        // edit_ACCT_USD_BALANCES(_sender, _usdAmntLP, false); // false = sub

        ICallitLib.MARKET_RESULTS memory mark_results = ICallitLib.MARKET_RESULTS(_resultLabels, new string[](_resultLabels.length), resultOptionTokens, resultTokenLPs, resultTokenRouters, resultTokenUsdStables, resultTokenVotes);
        delete resultOptionTokens;
        delete resultTokenLPs;
        delete resultTokenRouters;
        delete resultTokenUsdStables;
        delete resultTokenVotes;
        return mark_results;
    }
    
    function _exePullLiquidityFromLP(address _tokenRouter, address _pairAddress, address _token, address _usdStable) external onlyFactory returns(uint256) {
        // IUniswapV2Factory uniswapFactory = IUniswapV2Factory(mark.resultTokenFactories[i]);
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(_tokenRouter);
        
        // pull liquidity from pairAddress
        IERC20 pairToken = IERC20(_pairAddress);
        uint256 liquidity = pairToken.balanceOf(address(this));  // Get the contract's balance of the LP tokens
        
        // Approve the router to spend the LP tokens
        pairToken.approve(address(uniswapRouter), liquidity);
        
        // Retrieve the token pair
        address token0 = IUniswapV2Pair(_pairAddress).token0();
        address token1 = IUniswapV2Pair(_pairAddress).token1();

        // check to make sure that token0 is the 'ticket' & token1 is the 'stable'
        require(_token == token0 && _usdStable == token1, ' pair token mismatch w/ MARKET tck:usd :*() ');

        // get OG stable balance, so we can verify later
        uint256 OG_stable_bal = IERC20(_usdStable).balanceOf(address(this));

        // Remove liquidity
        // NOTE: amountToken1 = usd stable amount received (which is all we care about)
        (, uint256 amountToken1) = uniswapRouter.removeLiquidity(
            token0,
            token1,
            liquidity,
            0, // Min amount of token0, to prevent slippage (adjust based on your needs)
            0, // Min amount of token1, to prevent slippage (adjust based on your needs)
            address(this), // Send tokens to the contract itself or a specified recipient
            block.timestamp + 300 // Deadline (5 minutes from now)
        );

        // verify correct ticket token stable was pulled and recieved
        require(IERC20(_usdStable).balanceOf(address(this)) >= OG_stable_bal, ' stab bal mismatch after liq pull :+( ');
        return amountToken1;
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (VAULT)
    /* -------------------------------------------------------- */
    function _performTicketMint(ICallitLib.MARKET memory _mark, uint64 _tickIdx, uint64 _ticketTargetPriceUSD, address _arbExecuter) private returns(uint64,uint64) {
        // calc # of _ticket tokens to mint for DEX sell (to bring _ticket to price parity w/ target price)
        uint256 _usdTickTargPrice_18 = _normalizeStableAmnt(_usd_decimals(), _ticketTargetPriceUSD, 18);
        uint64 tokensToMint = _uint64_from_uint256(_normalizeStableAmnt(18, LIB._calculateTokensToMint(_mark.marketResults.resultTokenLPs[_tickIdx], _usdTickTargPrice_18), _usd_decimals()));

        // calc price to charge _arbExecuter for minting tokensToMint
        //  then deduct that amount from their account balance
        uint64 total_usd_cost = _ticketTargetPriceUSD * tokensToMint;
        if (_arbExecuter != CONF.KEEPER()) { // free for KEEPER
            // verify _arbExecuter usd balance covers contract sale of minted discounted tokens
            //  NOTE: _arbExecuter is buying 'tokensToMint' amount @ price = '_ticketTargetPriceUSD', from this contract
            require(ACCT_USD_BALANCES[_arbExecuter] >= total_usd_cost, ' low balance :( ');

            // deduce that sale amount from their account balance
            // CALLIT_VAULT.ACCT_USD_BALANCES[_arbExecuter] -= total_usd_cost; 
            edit_ACCT_USD_BALANCES(_arbExecuter, total_usd_cost, false); // false = sub
        }
        
        // mint tokensToMint count to this VAULT and sell on DEX on behalf of _arbExecuter
        //  NOTE: receiver == address(this), NOT _arbExecuter (need to deduct fees before paying _arbExecuter)
        //  NOTE: deduct fees and pay _arbExecuter in '_performTicketMintedDexSell'
        // ICallitTicket cTicket = ICallitTicket(_ticket);
        ICallitTicket cTicket = ICallitTicket(_mark.marketResults.resultOptionTokens[_tickIdx]);
        // CallitTicket cTicket = CallitTicket(_mark.marketResults.resultOptionTokens[_tickIdx]);
        cTicket.mintForPriceParity(address(this), tokensToMint);
        require(cTicket.balanceOf(address(this)) >= tokensToMint, ' err: cTicket mint :<> ');
        return (tokensToMint, total_usd_cost);
    }
    function _performTicketMintedDexSell(ICallitLib.MARKET memory _mark, uint64 _tickIdx, uint64 tokensToMint, uint64 total_usd_cost, address _arbExecuter) private returns(uint64,uint64) {
        // mint tokensToMint count to this VAULT and sell on DEX on behalf of _arbExecuter
        //  NOTE: receiver == address(this), NOT _arbExecuter (need to deduct fees before paying _arbExecuter)
        //  NOTE: deduct fees and pay _arbExecuter in '_performTicketMintedDexSell'
        address[] memory tok_stab_path = new address[](2);
        // tok_stab_path[0] = _ticket;
        tok_stab_path[0] = _mark.marketResults.resultOptionTokens[_tickIdx];
        tok_stab_path[1] = _mark.marketResults.resultTokenUsdStables[_tickIdx];
        uint256 usdAmntOut = _exeSwapTokForStable_router(tokensToMint, tok_stab_path, address(this), _mark.marketResults.resultTokenRouters[_tickIdx]); // swap tick: use specific router tck:tick-stable
        uint64 gross_stab_amnt_out = _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_mark.marketResults.resultTokenUsdStables[_tickIdx]).decimals(), usdAmntOut, _usd_decimals()));

        // calc & send net profits to _arbExecuter
        //  NOTE: _arbExecuter gets all of 'gross_stab_amnt_out' (since the contract keeps total_usd_cost)
        //  NOTE: 'net_usd_profits' is _arbExecuter's profit (after additional fees)
        uint64 net_usd_profits = LIB._deductFeePerc(gross_stab_amnt_out, CONF.PERC_ARB_EXE_FEE(), gross_stab_amnt_out);
        require(net_usd_profits > total_usd_cost, ' no profit from arb attempt :( '); // verify _arbExecuter profits would occur
        IERC20(_mark.marketResults.resultTokenUsdStables[_tickIdx]).transfer(_arbExecuter, net_usd_profits);
        return (gross_stab_amnt_out, net_usd_profits);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - SUPPORTING (legacy)
    /* -------------------------------------------------------- */
    function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) private pure returns (uint256) {
        require(_fromDecimals > 0 && _toDecimals > 0, 'err: invalid _from|toDecimals');
        if (_usdAmnt == 0) return _usdAmnt; // fix to allow 0 _usdAmnt (ie. no need to normalize)
        if (_fromDecimals == _toDecimals) {
            return _usdAmnt;
        } else {
            if (_fromDecimals > _toDecimals) { // _fromDecimals has more 0's
                uint256 scalingFactor = 10 ** (_fromDecimals - _toDecimals); // get the diff
                return _usdAmnt / scalingFactor; // decrease # of 0's in _usdAmnt
            }
            else { // _fromDecimals has less 0's
                uint256 scalingFactor = 10 ** (_toDecimals - _fromDecimals); // get the diff
                return _usdAmnt * scalingFactor; // increase # of 0's in _usdAmnt
            }
        }
    }
    function _uint64_from_uint256(uint256 value) private pure returns (uint64) {
        require(value <= type(uint64).max, "Value exceeds uint64 range");
        uint64 convertedValue = uint64(value);
        return convertedValue;
    }
    // function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) private {
    function edit_ACCT_USD_BALANCES(address _acct, uint64 _usdAmnt, bool _add) public onlyFactory() {
        if (_add) {
            require(_usdAmnt > 0, ' !add 0 :/ ' );
            ACCT_USD_BALANCES[_acct] += _usdAmnt;
        } else {
            require(ACCT_USD_BALANCES[_acct] >= _usdAmnt, ' !deduct low balance :{} ');
            ACCT_USD_BALANCES[_acct] -= _usdAmnt;    
        }
    }
    function _grossStableBalance(address[] memory _stables) private view returns (uint64) {
        uint64 gross_bal = 0;
        for (uint8 i = 0; i < _stables.length;) {
            // NOTE: more efficient algorithm taking up less stack space with local vars
            require(IERC20x(_stables[i]).decimals() > 0, ' found stable with invalid decimals :/ ');
            gross_bal += _uint64_from_uint256(_normalizeStableAmnt(IERC20x(_stables[i]).decimals(), IERC20(_stables[i]).balanceOf(address(this)), _usd_decimals()));
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
    function _stableHoldingsCovered(uint64 _usdAmnt, address _usdStable) private view returns (bool) {
        if (_usdStable == address(0x0)) 
            return false;
        uint256 usdAmnt_ = _normalizeStableAmnt(_usd_decimals(), _usdAmnt, IERC20x(_usdStable).decimals());
        return IERC20(_usdStable).balanceOf(address(this)) >= usdAmnt_;
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - DEX SWAP SUPPORT                                    
    /* -------------------------------------------------------- */
    function _getStableHeldHighLowMarketValue(uint64 _usdAmntReq, address[] memory _stables, address[] memory _routers, bool _getHigh) private view returns (address) {

        address[] memory _stablesHeld;
        for (uint8 i=0; i < _stables.length;) {
            if (_stableHoldingsCovered(_usdAmntReq, _stables[i]))
                _stablesHeld = LIB._addAddressToArraySafe(_stables[i], _stablesHeld, true); // true = no dups

            unchecked {
                i++;
            }
        }
        if (_getHigh) return LIB._getStableTokenHighMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
        else return LIB._getStableTokenLowMarketValue(_stablesHeld, _routers); // returns 0x0 if empty _stablesHeld
    }
    function _swapBestStableForTickStable(uint64 _usdAmnt, address _tickStable) private returns(uint256, address){
        // Get stable to work with ... (any stable that covers '_usdAmnt' is fine)
        //  NOTE: if no single stable can cover '_usdAmnt', highStableHeld == 0x0, 
        // address highStableHeld = _getStableHeldHighMarketValue(_usdAmnt, WHITELIST_USD_STABLES, USWAP_V2_ROUTERS); // 3 loops embedded
        (address[] memory stables, address[] memory routers) = CONF.getDexAddies();
        address highStableHeld = _getStableHeldHighLowMarketValue(_usdAmnt, stables, routers, true); // 3 loops embedded // true = high mark val
        
        require(highStableHeld != address(0x0), ' !stable holdings can cover :-{=} ' );

        // create path and perform stable-to-stable swap
        // address[2] memory stab_stab_path = [highStableHeld, _tickStable];
        address[] memory stab_stab_path = new address[](2);
        stab_stab_path[0] = highStableHeld;
        stab_stab_path[1] = _tickStable;
        uint256 stab_amnt_out = _exeSwapTokForTok(_usdAmnt, stab_stab_path, address(this), true); // no tick: use best from USWAP_V2_ROUTERS
        return (stab_amnt_out,highStableHeld);
    }
    // generic: gets best from USWAP_V2_ROUTERS to perform trade
    function _exeSwapTokForTok(uint256 _tokAmntIn, address[] memory _swap_path, address _receiver, bool _fromUsdAcctBal) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_swap_path[1] != address(this), ' !swap for this :p ');
        
        if (_fromUsdAcctBal) { // required: _swap_path[0] must be a stable
            _tokAmntIn = _normalizeStableAmnt(_usd_decimals(), _tokAmntIn, IERC20x(_swap_path[0]).decimals());
        }
        // (,, address[] memory routers) = CONF.getDexAddies();
        (uint8 rtrIdx,) = LIB._best_swap_v2_router_idx_quote(_swap_path, _tokAmntIn, CONF.get_USWAP_V2_ROUTERS());
        uint256 stable_amnt_out = _swap_v2_wrap(_swap_path, CONF.USWAP_V2_ROUTERS(rtrIdx), _tokAmntIn, _receiver, false); // true = fromETH        
        return stable_amnt_out;
    }
    // specify router to use
    function _exeSwapTokForStable_router(uint256 _tokAmnt, address[] memory _tok_stab_path, address _receiver, address _router) private returns (uint256) {
        // NOTE: this contract is not a stable, so it can indeed be _receiver with no issues (ie. will never _receive itself)
        require(_tok_stab_path[1] != address(this), ' this contract not a stable :p ');
        uint256 tok_amnt_out = _swap_v2_wrap(_tok_stab_path, _router, _tokAmnt, _receiver, false); // true = fromETH
        return tok_amnt_out;
    }    
    // uniwswap v2 protocol based: get quote and execute swap
    function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) private returns (uint256) {
        require(path.length >= 2, 'err: path.length :/');
        uint256[] memory amountsOut = IUniswapV2Router02(router).getAmountsOut(amntIn, path); // quote swap
        uint256 amntOutQuote = amountsOut[amountsOut.length -1];
        // uint256 amntOutQuote = _swap_v2_quote(path, router, amntIn);
        uint256 amntOut = _swap_v2(router, path, amntIn, amntOutQuote, outReceiver, fromETH); // approve & execute swap
                
        // verifiy new balance of token received
        uint256 new_bal = IERC20(path[path.length -1]).balanceOf(outReceiver);
        require(new_bal >= amntOut, " _swap: receiver bal too low :{ ");
        
        return amntOut;
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