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

import "./CallitTicket.sol";
import "./ICallitLib.sol";
import "./ICallitVault.sol";

contract CallitDelegate {
    string public constant tVERSION = '0.2';
    
    address public KEEPER;
    uint256 private KEEPER_CHECK; // misc key, set to help ensure no-one else calls 'KEEPER_collectiveStableBalances'

    // note: makeNewMarket
    // call ticket token settings (note: init supply -> RATIO_LP_TOK_PER_USD)
    address public NEW_TICK_UNISWAP_V2_ROUTER;
    address public NEW_TICK_UNISWAP_V2_FACTORY;
    address public NEW_TICK_USD_STABLE;
    string  public TOK_TICK_NAME_SEED = "TCK#";
    string  public TOK_TICK_SYMB_SEED = "CALL-TICKET";
    uint16 public RATIO_LP_TOK_PER_USD = 10000; // # of ticket tokens per usd, minted for LP deploy

    // note: makeNewMarket
    // temp-arrays for 'makeNewMarket' support
    address[] private resultOptionTokens;
    address[] private resultTokenLPs;
    address[] private resultTokenRouters;
    address[] private resultTokenFactories;

    address[] private resultTokenUsdStables;
    uint64 [] private resultTokenVotes;
    address[] private newTickMaker;

    /* GLOBALS (CALLIT) */
    bool private ONCE_ = true;
    address public FACT_ADDR;
    address public LIB_ADDR = address(0x657428d6E3159D4a706C00264BD0DdFaf7EFaB7e); // CallitLib v1.0
    address public VAULT_ADDR = address(0xa8667527F00da10cadE9533952e069f5209273c2); // CallitVault v0.4
    ICallitLib   private LIB = ICallitLib(LIB_ADDR);
    ICallitVault private VAULT = ICallitVault(VAULT_ADDR);

    uint16 public PERC_MARKET_MAKER_FEE; // note: no other % fee

    mapping(address => ICallitLib.PROMO) public PROMO_CODE_HASHES; // store promo code hashes to their PROMO mapping

    /* -------------------------------------------------------- */
    /* EVENTS
    /* -------------------------------------------------------- */
    // legacy
    event KeeperTransfer(address _prev, address _new);

    constructor() {
        KEEPER = msg.sender;
    }
    modifier onlyKeeper() {
        require(msg.sender == KEEPER, "!keeper :p");
        _;
    }
    modifier onlyFactory() {
        require(msg.sender == FACT_ADDR || msg.sender == KEEPER, " !keeper & !fact :p");
        _;
    }
    modifier onlyOnce() {
        require(ONCE_, ' never again :/ ' );
        ONCE_ = false;
        _;
    }
    function INIT_factory() external onlyOnce {
        require(FACT_ADDR == address(0), ' factor already set :) ');
        FACT_ADDR == msg.sender;
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - KEEPER
    /* -------------------------------------------------------- */
    // legacy
    function KEEPER_maintenance(address _erc20, uint256 _amount) external onlyKeeper() {
        if (_erc20 == address(0)) { // _erc20 not found: tranfer native PLS instead
            require(address(this).balance >= _amount, " Insufficient native PLS balance :[ ");
            payable(KEEPER).transfer(_amount); // cast to a 'payable' address to receive ETH
            // emit KeeperWithdrawel(_amount);
        } else { // found _erc20: transfer ERC20
            //  NOTE: _tokAmnt must be in uint precision to _tokAddr.decimals()
            require(IERC20(_erc20).balanceOf(address(this)) >= _amount, ' not enough amount for token :O ');
            IERC20(_erc20).transfer(KEEPER, _amount);
            // emit KeeperMaintenance(_erc20, _amount);
        }
    }
    function KEEPER_setKeeper(address _newKeeper, uint16 _keeperCheck) external onlyKeeper {
        require(_newKeeper != address(0), 'err: 0 address');
        address prev = address(KEEPER);
        KEEPER = _newKeeper;
        if (_keeperCheck > 0)
            KEEPER_CHECK = _keeperCheck;
        emit KeeperTransfer(prev, KEEPER);
    }

    /* -------------------------------------------------------- */
    /* PUBLIC - FACTORY SUPPORT
    /* -------------------------------------------------------- */
    function makeNewMarket( string calldata _name, // _deductFeePerc PERC_MARKET_MAKER_FEE from _usdAmntLP
                            uint64 _usdAmntLP, 
                            uint256 _dtCallDeadline, 
                            uint256 _dtResultVoteStart, 
                            uint256 _dtResultVoteEnd, 
                            string[] calldata _resultLabels, 
                            string[] calldata _resultDescrs,
                            uint256 _mark_num
                            ) external onlyFactory returns(ICallitLib.MARKET memory) { 
        // deduct 'market maker fees' from _usdAmntLP
        uint64 net_usdAmntLP = LIB._deductFeePerc(_usdAmntLP, PERC_MARKET_MAKER_FEE, _usdAmntLP);

        // Loop through _resultLabels and deploy ERC20s for each (and generate LP)
        for (uint16 i = 0; i < _resultLabels.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535            
            // Get/calc amounts for initial LP (usd and token amounts)
            (uint64 usdAmount, uint256 tokenAmount) = LIB._getAmountsForInitLP(net_usdAmntLP, _resultLabels.length, RATIO_LP_TOK_PER_USD);            

            // Deploy a new ERC20 token for each result label (init supply = tokenAmount; transfered to VAULT to create LP)
            (string memory tok_name, string memory tok_symb) = LIB._genTokenNameSymbol(msg.sender, _mark_num, i, TOK_TICK_NAME_SEED, TOK_TICK_SYMB_SEED);
            address new_tick_tok = address (new CallitTicket(tokenAmount, address(this), tok_name, tok_symb));
            
            // Create DEX LP for new ticket token (from VAULT, using VAULT's stables, and VAULT's minted new tick init supply)
            address pairAddr = VAULT._createDexLP(NEW_TICK_UNISWAP_V2_ROUTER, NEW_TICK_UNISWAP_V2_FACTORY, new_tick_tok, NEW_TICK_USD_STABLE, tokenAmount, usdAmount);

            // verify ERC20 & LP was created
            require(new_tick_tok != address(0) && pairAddr != address(0), ' err: gen tick tok | lp :( ');

            // set this ticket option's settings to index 'i' in storage temp results array
            //  temp array will be added to MARKET struct and returned (then deleted on function return)
            resultOptionTokens[i] = new_tick_tok;
            resultTokenLPs[i] = pairAddr;

            resultTokenRouters[i] = NEW_TICK_UNISWAP_V2_ROUTER;
            resultTokenFactories[i] = NEW_TICK_UNISWAP_V2_FACTORY;
            resultTokenUsdStables[i] = NEW_TICK_USD_STABLE;
            resultTokenVotes[i] = 0;

            // NOTE: set ticket to maker mapping, handled from factory

            unchecked {i++;}
        }

        // deduct full OG usd input from account balance
        VAULT.edit_ACCT_USD_BALANCES(msg.sender, _usdAmntLP, false); // false = sub

        // save this market and emit log
        ICallitLib.MARKET memory mark = ICallitLib.MARKET({maker:msg.sender, 
                                                marketNum:_mark_num, 
                                                name:_name,

                                                // marketInfo:MARKET_INFO("", "", ""),
                                                category:"",
                                                rules:"", 
                                                imgUrl:"", 

                                                marketUsdAmnts:ICallitLib.MARKET_USD_AMNTS(_usdAmntLP, 0, 0, 0, 0), 
                                                marketDatetimes:ICallitLib.MARKET_DATETIMES(_dtCallDeadline, _dtResultVoteStart, _dtResultVoteEnd), 
                                                marketResults:ICallitLib.MARKET_RESULTS(_resultLabels, _resultDescrs, resultOptionTokens, resultTokenLPs, resultTokenRouters, resultTokenFactories, resultTokenUsdStables, resultTokenVotes), 
                                                winningVoteResultIdx:0, 
                                                blockTimestamp:block.timestamp, 
                                                blockNumber:block.number, 
                                                live:true}); // true = live
        
        // Step 4: Clear tempArray (optional)
        // delete tempArray; // This will NOT effect whats stored in ACCT_MARKETS
        delete resultOptionTokens;
        delete resultTokenLPs;
        delete resultTokenRouters;
        delete resultTokenFactories;
        delete resultTokenUsdStables;
        delete resultTokenVotes;

        return mark;

        // NOTE: market maker is minted $CALL in 'closeMarketForTicket'
    }
    function initPromoForWallet(address _promotor, string calldata _promoCode, uint64 _usdTarget, uint8 _percReward, address _sender) external onlyFactory {
        // no 2 percs taken out of promo buy
        require(VAULT.PERC_PROMO_BUY_FEE() + _percReward < 10000, ' invalid promo buy _perc :(=) ');
        require(_promotor != address(0) && LIB._validNonWhiteSpaceString(_promoCode) && _usdTarget >= VAULT.MIN_USD_PROMO_TARGET(), ' !param(s) :={ ');
        address promoCodeHash = LIB._generateAddressHash(_promotor, _promoCode);
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[promoCodeHash];
        require(promo.promotor == address(0), ' promo already exists :-O ');
        PROMO_CODE_HASHES[promoCodeHash] = ICallitLib.PROMO(_promotor, _promoCode, _usdTarget, 0, _percReward, _sender, block.number);
    }
    function checkPromoBalance(address _promoCodeHash) external view onlyFactory returns(uint64) {
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0), ' invalid promo :-O ');
        return promo.usdTarget - promo.usdUsed;
    }
    function buyCallTicketWithPromoCode(address _usdStableResult, address _ticket, address _promoCodeHash, uint64 _usdAmnt, address _sender) external onlyFactory returns(uint64, uint256) { // _deductFeePerc PERC_PROMO_BUY_FEE from _usdAmnt
        ICallitLib.PROMO storage promo = PROMO_CODE_HASHES[_promoCodeHash];
        require(promo.promotor != address(0) && promo.usdTarget - promo.usdUsed >= _usdAmnt && promo.promotor != _sender, ' invalid promo :-O ');

        // NOTE: algorithmic logic...
        //  - admins initialize promo codes for EOAs (generates promoCodeHash and stores in PROMO struct for EOA influencer)
        //  - influencer gives out promoCodeHash for callers to use w/ this function to purchase any _ticket they want
        // NOTE: potential exploitation preventions (in current callstack 'require' checks)
        //  promotor can't earn both $CALL & USD reward w/ their own promo
        //  maker can't earn $CALL twice on same market (from both "promo buy" & "making market")

        // update promo.usdUsed (add full OG input _usdAmnt)
        promo.usdUsed += _usdAmnt;

        // pay promotor usd reward & purchase _sender's tickets from DEX
        //  NOTE: indeed verifies "_percReward + PERC_PROMO_BUY_FEE < 10000"
        // NOTE: *WARNING* if this require fails ... 
        //  then this promo code cannot be used until PERC_PROMO_BUY_FEE is lowered accordingly
        return VAULT._payPromotorDeductFeesBuyTicket(promo.percReward, _usdAmnt, promo.promotor, _promoCodeHash, _ticket, _usdStableResult, _sender);
    }
    function closeMarketCallsForTicket(ICallitLib.MARKET memory mark) external onlyFactory returns(uint64) { // NOTE: !_deductFeePerc; reward mint
        // algorithmic logic...
        //  get market for _ticket
        //  verify mark.marketDatetimes.dtCallDeadline has indeed passed
        //  loop through _ticket LP addresses and pull all liquidity

        // loop through pair addresses and pull liquidity 
        address[] memory _ticketLPs = mark.marketResults.resultTokenLPs;
        uint64 usdAmntPrizePool = 0;
        for (uint16 i = 0; i < _ticketLPs.length;) { // MAX_RESULTS is uint16
            uint256 amountToken1 = VAULT._exePullLiquidityFromLP(mark.marketResults.resultTokenRouters[i], _ticketLPs[i], mark.marketResults.resultOptionTokens[i], mark.marketResults.resultTokenUsdStables[i]);

            // update market prize pool usd received from LP (usdAmntPrizePool: defualts to 0)
            usdAmntPrizePool += LIB._uint64_from_uint256(amountToken1); // NOTE: write to market

            unchecked {
                i++;
            }
        }

        return usdAmntPrizePool;
    }
}