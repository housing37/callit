# .sol function hash mappings

## CallitLib.sol
#----------------------------------------------------------------#
FORMAT: readable ... CallitLib => 10887 bytes _ limits: 24576 bytes & 49152 bytes
#----------------------------------------------------------------#
{
    "0xfa4a9870": "TOK_WPLS()" -> "['address']",
    "0xa8850d39": "_addAddressToArraySafe(address,address[],bool)" -> "['address[]']",
    "0x08d3a5ff": "_addressIsMarketMakerOrCaller(address,address,address[])" -> "['bool', 'bool']",
    "0xfebd642b": "_best_swap_v2_router_idx_quote(address[],uint256,address[])" -> "['uint8', 'uint256']",
    "0xc80bad13": "_calculateTokensToMint(address,uint256)" -> "['uint256']",
    "0x7403eac9": "_deductFeePerc(uint64,uint16,uint64)" -> "['uint64']",
    "0xc3a300a3": "_genTokenNameSymbol(address,uint256,uint16,string,string)" -> "['string', 'string']",
    "0x19d50305": "_generateAddressHash(address,string)" -> "['address']",
    "0x277d195d": "_getAmountsForInitLP(uint256,uint256,uint32)" -> "['uint64', 'uint256']",
    "0x895e0b50": "_getCallTicketUsdTargetPrice(tuple,uint16,uint64,uint8)" -> "['uint64']",
    "0xc3f4435e": "_getStableTokenHighMarketValue(address[],address[])" -> "['address']",
    "0xf56276b5": "_getStableTokenLowMarketValue(address[],address[])" -> "['address']",
    "0x9aa304b2": "_getWinningVoteIdxForMarket(uint64[])" -> "['uint16']",
    "0xa8509565": "_isAddressInArray(address,address[])" -> "['bool']",
    "0x19db68d9": "_normalizeStableAmnt(uint8,uint256,uint8)" -> "['uint256']",
    "0x3972a5a9": "_perc_of_uint64(uint16,uint64)" -> "['uint64']",
    "0xc8c25894": "_perc_of_uint64_unchecked(uint32,uint64)" -> "['uint64']",
    "0x2a9c544c": "_perc_total_supply_owned(address,address)" -> "['uint64']",
    "0x466816b3": "_remAddressFromArray(address,address[])" -> "['address[]']",
    "0xd39fdbb7": "_uint64_from_uint256(uint256)" -> "['uint64']",
    "0x2e440bcd": "_validNonWhiteSpaceString(string)" -> "['bool']",
    "0xf8c91e04": "debug_log_addess(address,address,address,address)" -> "[]",
    "0x5645884e": "debug_log_string(address,string,string,string)" -> "[]",
    "0x1307dd9c": "debug_log_uint(address,uint8,uint16,uint32,uint64,uint256)" -> "[]",
    "0x12d898ca": "genMarketResultReview(address,tuple,tuple[],bool)" -> "['tuple']",
    "0xe9b57944": "getValidVoteCount(uint64,uint32,uint64,uint256,uint256)" -> "['uint64']",
    "0xa67cd60c": "grossStableBalance(address[],address,uint8)" -> "['uint64']",
    "0x9a60f330": "tVERSION()" -> "['string']",
}


## CallitVault.sol
#----------------------------------------------------------------#
FORMAT: readable ... CallitVault => 24555 bytes _ limits: 24576 bytes & 49152 bytes
#----------------------------------------------------------------#
{
    "0x9032bcc8": "ACCOUNTS(uint256)" -> "['address']",
    "0xc67483dc": "ACCT_USD_BALANCES(address)" -> "['uint64']",
    "0x70c07591": "ADDR_CONFIG()" -> "['address']",
    "0x5abb3764": "CONF_setConfig(address)" -> "[]",
    "0x7c4b2b73": "KEEPER_collectiveStableBalances(uint256)" -> "['uint64', 'uint64', 'int64']",
    "0x72dc3b3f": "KEEPER_maintenance(address,uint256)" -> "[]",
    "0x05e278e5": "KEEPER_withdrawTicketLP(address)" -> "[]",
    "0x672c3531": "PROMO_USD_OWED(address)" -> "['uint64']",
    "0xfa4a9870": "TOK_WPLS()" -> "['address']",
    "0x9dea52b6": "_exePullLiquidityFromLP(address,address,address,address)" -> "['uint256']",
    "0x3b3b19fb": "_payPromotorDeductFeesBuyTicket(uint16,uint64,address,address,address,address,address)" -> "['uint64', 'uint256']",
    "0x09aba2a3": "_payUsdReward(address,uint64,address)" -> "[]",
    "0x17fd5397": "_usd_decimals()" -> "['uint8']",
    "0x03ff3ca2": "createDexLP(string[],uint256,uint16)" -> "['tuple']",
    "0xf340fa01": "deposit(address)" -> "[]",
    "0x958651fa": "edit_ACCT_USD_BALANCES(address,uint64,bool)" -> "[]",
    "0x4ed3c6a3": "exeArbPriceParityForTicket(tuple,uint16,address)" -> "['uint64', 'uint64', 'uint64', 'uint64', 'uint64']",
    "0x8a48ac03": "getAccounts()" -> "['address[]']",
    "0xc2525ad4": "payPromoUsdReward(address,address,uint64,address)" -> "['uint64']",
    "0x9a60f330": "tVERSION()" -> "['string']",
}

## CallitDelegate.sol
#----------------------------------------------------------------#
FORMAT: readable ... CallitDelegate => 24535 bytes _ limits: 24576 bytes & 49152 bytes
#----------------------------------------------------------------#
{
    "0xb018221f": "ACCT_MARKET_HASHES(address,uint256)" -> "['address']",
    "0x927270cb": "ACCT_MARKET_VOTES_PAID(address,uint256)" -> "['address', 'address', 'uint16', 'uint64', 'address', 'uint256', 'bool']",
    "0x70c07591": "ADDR_CONFIG()" -> "['address']",
    "0xfc9c85a2": "ADMINS(address)" -> "['bool']",
    "0xc0394d1f": "ADMIN_initPromoForWallet(address,string,uint64,uint8)" -> "[]",
    "0x059c9878": "CATEGORY_MARK_HASHES(string,uint256)" -> "['address']",
    "0x5abb3764": "CONF_setConfig(address)" -> "[]",
    "0x5d07ef7f": "HASH_MARKET(address)" -> "['address', 'uint256', 'string', 'string', 'string', 'string', 'tuple', 'tuple', 'tuple', 'uint16', 'uint256', 'uint256', 'bool']",
    "0x577eab5b": "KEEPER_editAdmin(address,bool)" -> "[]",
    "0x72dc3b3f": "KEEPER_maintenance(address,uint256)" -> "[]",
    "0xe1dcf8f0": "PROMO_CODE_HASHES(address)" -> "['address', 'string', 'uint64', 'uint64', 'uint8', 'address', 'uint256']",
    "0xd39c3300": "_getMarketForTicket(address,address)" -> "['tuple', 'uint16', 'address']",
    "0x0283ad53": "buyCallTicketWithPromoCode(address,address,address,uint64,address)" -> "['uint64', 'uint256']",
    "0x0d8bcf08": "checkPromoBalance(address)" -> "['uint64']",
    "0x41799c3d": "claimPromotorRewards(address)" -> "[]",
    "0xbba29136": "claimVoterRewards(address)" -> "[]",
    "0x981fd888": "closeMarketCalls(tuple)" -> "['uint64']",
    "0x1a4713ee": "getMarketCntForMaker(address)" -> "['uint256']",
    "0x66c2a7cc": "getMarketForHash(address)" -> "['tuple']",
    "0xe8f47f2a": "getMarketHashesForMakerOrCategory(address,string)" -> "['address[]']",
    "0x37eca5e9": "makeNewMarket(string,uint64,uint256,uint256,uint256,string[],uint256,address)" -> "['tuple']",
    "0x28bc0594": "pushAcctMarketVote(address,tuple)" -> "[]",
    "0x7acf70b6": "setHashMarket(address,tuple,string)" -> "[]",
    "0x1fc530bb": "storeNewMarket(tuple,address,address)" -> "[]",
    "0x9a60f330": "tVERSION()" -> "['string']",
}

## CallitToken.sol
#----------------------------------------------------------------#
FORMAT: readable ... CallitToken => 6631 bytes _ limits: 24576 bytes & 49152 bytes
#----------------------------------------------------------------#
{
    "0xf27c2fc8": "ACCT_CALL_VOTE_LOCK_TIME(address)" -> "['uint256']",
    "0xfd695121": "ACCT_HANDLES(address)" -> "['string']",
    "0x70c07591": "ADDR_CONFIG()" -> "['address']",
    "0x5abb3764": "CONF_setConfig(address)" -> "[]",
    "0xcad8b94d": "EARNED_CALL_VOTES(address)" -> "['uint64']",
    "0xdd62ed3e": "allowance(address,address)" -> "['uint256']",
    "0x095ea7b3": "approve(address,uint256)" -> "['bool']",
    "0x70a08231": "balanceOf(address)" -> "['uint256']",
    "0x61d0c3d0": "balanceOf_voteCnt(address)" -> "['uint64']",
    "0x42966c68": "burn(uint256)" -> "[]",
    "0x313ce567": "decimals()" -> "['uint8']",
    "0x8e836ed2": "mintCallToksEarned(address,uint256,uint64,address)" -> "[]",
    "0x06fdde03": "name()" -> "['string']",
    "0x8da5cb5b": "owner()" -> "['address']",
    "0x715018a6": "renounceOwnership()" -> "[]",
    "0x4a9d2f0a": "setAcctHandle(string)" -> "[]",
    "0x4805d092": "setCallTokenVoteLock(bool)" -> "[]",
    "0x95d89b41": "symbol()" -> "['string']",
    "0x9a60f330": "tVERSION()" -> "['string']",
    "0x18160ddd": "totalSupply()" -> "['uint256']",
    "0xa9059cbb": "transfer(address,uint256)" -> "['bool']",
    "0x23b872dd": "transferFrom(address,address,uint256)" -> "['bool']",
    "0xf2fde38b": "transferOwnership(address)" -> "[]",
}

## CallitFactory.sol
#----------------------------------------------------------------#
FORMAT: readable ... CallitFactory => 20831 bytes _ limits: 24576 bytes & 49152 bytes
#----------------------------------------------------------------#
{
    "0x70c07591": "ADDR_CONFIG()" -> "['address']",
    "0x5abb3764": "CONF_setConfig(address)" -> "[]",
    "0x72dc3b3f": "KEEPER_maintenance(address,uint256)" -> "[]",
    "0x5a505989": "buyCallTicketWithPromoCode(address,address,uint64)" -> "[]",
    "0x36ed4673": "castVoteForMarketTicket(address,address)" -> "[]",
    "0xd16aca12": "claimTicketRewards(address,bool)" -> "[]",
    "0xe41356f3": "claimVoterRewards()" -> "[]",
    "0x00fa1b81": "closeMarketCallsForTicket(address)" -> "[]",
    "0x8be58395": "closeMarketForTicket(address)" -> "[]",
    "0xb12524d6": "exeArbPriceParityForTicket(address)" -> "[]",
    "0xde1bc55f": "getMarketCntForMakerOrCategory(address,string)" -> "['uint256']",
    "0x66c2a7cc": "getMarketForHash(address)" -> "['tuple']",
    "0x7b668032": "getMarketForTicket(address)" -> "['tuple']",
    "0x72a77e1a": "getMarketHashesForMakerOrCategory(string,address,bool,bool,uint8,uint8)" -> "['address[]']",
    "0xd8ddf058": "getMarketsForMakerOrCategory(string,address,bool,bool,uint8,uint8)" -> "['tuple[]']",
    "0xd09d1d06": "getPromosForAcct(address)" -> "['tuple[]']",
    "0xce448595": "makeNewMarket(string,uint64,uint256,uint256,uint256,string[],string[])" -> "[]",
    "0x4a9d2f0a": "setAcctHandle(string)" -> "[]",
    "0xcb73f3ee": "setMarketInfo(address,string,string,string)" -> "[]",
    "0x9a60f330": "tVERSION()" -> "['string']",
}

## CallitConfig.sol
#----------------------------------------------------------------#
FORMAT: readable ... CallitConfig => 16764 bytes _ limits: 24576 bytes & 49152 bytes
#----------------------------------------------------------------#
{
    "0xce300513": "ADDR_CALL()" -> "['address']",
    "0x432d150d": "ADDR_DELEGATE()" -> "['address']",
    "0x81ede161": "ADDR_FACT()" -> "['address']",
    "0x0051fa16": "ADDR_LIB()" -> "['address']",
    "0x04d08e1c": "ADDR_VAULT()" -> "['address']",
    "0xf67703a4": "DEPOSIT_ROUTER()" -> "['address']",
    "0x4d9a767e": "DEPOSIT_USD_STABLE()" -> "['address']",
    "0x862a179e": "KEEPER()" -> "['address']",
    "0xbceeba33": "KEEPER_editDexRouters(address,bool)" -> "[]",
    "0xd39a89d6": "KEEPER_editWhitelistStables(address,bool)" -> "[]",
    "0x72dc3b3f": "KEEPER_maintenance(address,uint256)" -> "[]",
    "0xc5a84916": "KEEPER_setContracts(address,address,address,address,address,address)" -> "[]",
    "0xd446008b": "KEEPER_setDepositUsdStable(address,address)" -> "[]",
    "0x6d77185c": "KEEPER_setKeeper(address,uint16)" -> "[]",
    "0x23dd0518": "KEEPER_setLpSettings(uint64,uint16,uint64)" -> "[]",
    "0x98adab94": "KEEPER_setMarketActionMints(uint32,uint32,uint32,uint32,uint64,uint64)" -> "[]",
    "0x6f946c67": "KEEPER_setMarketConfig(uint16,uint64,uint64,uint256,bool)" -> "[]",
    "0x0353a04c": "KEEPER_setMarketLoserMints(uint8,uint8)" -> "[]",
    "0xd65e611c": "KEEPER_setNewTicketEnv(address,address)" -> "[]",
    "0xed98b031": "KEEPER_setPercFees(uint16,uint16,uint16,uint16,uint16,uint16,uint16,uint16)" -> "[]",
    "0x41f95417": "KEEPER_setTicketNameSymbSeeds(string,string)" -> "[]",
    "0x485d44c5": "MAX_EOA_MARKETS()" -> "['uint64']",
    "0x0c806736": "MAX_RESULTS()" -> "['uint16']",
    "0x5799ebb7": "MIN_USD_CALL_TICK_TARGET_PRICE()" -> "['uint64']",
    "0x8da4fb23": "MIN_USD_MARK_LIQ()" -> "['uint64']",
    "0x71b241b5": "MIN_USD_PROMO_TARGET()" -> "['uint64']",
    "0x7d673fe5": "NEW_TICK_UNISWAP_V2_ROUTER()" -> "['address']",
    "0x3aec5a15": "NEW_TICK_USD_STABLE()" -> "['address']",
    "0x7c377464": "PERC_ARB_EXE_FEE()" -> "['uint16']",
    "0x7b4baeea": "PERC_MARKET_CLOSE_FEE()" -> "['uint16']",
    "0x9d35b21b": "PERC_MARKET_MAKER_FEE()" -> "['uint16']",
    "0x76fbe7ad": "PERC_OF_LOSER_SUPPLY_EARN_CALL()" -> "['uint16']",
    "0x50f20850": "PERC_PRIZEPOOL_VOTERS()" -> "['uint16']",
    "0x4bfdf502": "PERC_PROMO_BUY_FEE()" -> "['uint16']",
    "0x8e68119c": "PERC_PROMO_CLAIM_FEE()" -> "['uint16']",
    "0x04a59785": "PERC_REQ_CLAIM_PROMO_REWARD()" -> "['uint16']",
    "0xd19cc4e9": "PERC_VOTER_CLAIM_FEE()" -> "['uint16']",
    "0xef62ede3": "PERC_WINNER_CLAIM_FEE()" -> "['uint16']",
    "0x2dc20055": "RATIO_CALL_MINT_PER_ARB_EXE()" -> "['uint32']",
    "0x236eceaf": "RATIO_CALL_MINT_PER_LOSER()" -> "['uint32']",
    "0xa38e4579": "RATIO_CALL_MINT_PER_MARK_CLOSE()" -> "['uint32']",
    "0xc3309160": "RATIO_CALL_MINT_PER_MARK_CLOSE_CALLS()" -> "['uint32']",
    "0x66e7630c": "RATIO_CALL_MINT_PER_VOTE()" -> "['uint32']",
    "0xf32d8933": "RATIO_LP_TOK_PER_USD()" -> "['uint16']",
    "0x1e9a20bf": "RATIO_LP_USD_PER_CALL_TOK()" -> "['uint64']",
    "0x59964b89": "RATIO_PROMO_USD_PER_CALL_MINT()" -> "['uint64']",
    "0x2dda1682": "SEC_DEFAULT_VOTE_TIME()" -> "['uint256']",
    "0xd340a4e5": "TOK_TICK_NAME_SEED()" -> "['string']",
    "0x420fe5d6": "TOK_TICK_SYMB_SEED()" -> "['string']",
    "0xcd196d89": "USD_STABLES_HISTORY(uint256)" -> "['address']",
    "0xfb5e54f8": "USE_SEC_DEFAULT_VOTE_TIME()" -> "['bool']",
    "0xee80b054": "USWAP_V2_ROUTERS(uint256)" -> "['address']",
    "0x988b93f3": "VAULT_deployTicket(uint256,string,string)" -> "['address']",
    "0xd302dffc": "VAULT_getStableTokenLowMarketValue()" -> "['address']",
    "0x593d1bf7": "WHITELIST_USD_STABLES(uint256)" -> "['address']",
    "0xea877d6a": "getDexAddies()" -> "['address[]', 'address[]']",
    "0xd26fcdf4": "get_USWAP_V2_ROUTERS()" -> "['address[]']",
    "0xb67653cb": "get_WHITELIST_USD_STABLES()" -> "['address[]']",
    "0x29bdf322": "keeperCheck(uint256)" -> "['bool']",
    "0x9a60f330": "tVERSION()" -> "['string']",
}