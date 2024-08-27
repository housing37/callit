__fname = '_abi' # ported from 'defi-arb' (121023)
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

AtropaMV_FUNC_MAP_READ = {
	# READ
    "HASH_MV_MINT()": ["0e20d3ff", [], ['bytes4']],
    "TOK_MV()": ["1b6cef7e", [], ['address']],
    "KEEPER_tokenBalance(address)": ["cbbc7a01", ['address'], ['uint256']],
    
 	"#------------LEGACY------------#": ["xxxxxxxx", [], []], 
 	"KEEPER()": ["862a179e", [], ['address']],
    "TOK_WPLS()": ["fa4a9870", [], ['address']],
    "BURN_ADDR()": ["783028a9", [], ['address']],
    "tVERSION()": ["9a60f330", [], ['string']],
}
AtropaMV_FUNC_MAP_WRITE = {
	# WRITE
    "KEEPER_invokeMintMV(uint32)": ["51cacf4f", ['uint32'], []], 
    
	"#------------LEGACY------------#": ["xxxxxxxx", [], []], 
    "KEEPER_maintenance(address,uint256)": ["72dc3b3f", ["address","uint256"], []], # gas used: ?
    "KEEPER_withdraw(uint256)": ["cbf0d0d4", ["uint256"], []], 
    "KEEPER_setKeeper(address)": ["11851737", ["address"], []], 
}
UniswapFlashQuery_FUNC_MAP_READ = {
    # read functions     
	"getPairsByIndexRange(address,address,uint256,uint256)": ["6149de9c", ['address','address','uint256','uint256'], ['address[3][]','uint256[5][]']],
	"getPairsByIndexRange_OG(address,uint256,uint256)": ["a09bdbdc", ['address','uint256','uint256'], ['address[3][]']],   
    "getReservesByPairs(address[],address)": ["66cc1fbb", ['address[]','address'], ['uint256[5][]']],
    "getReservesByPairs_OG(address[])": ["99c31ae6", ['address[]'], ['uint256[3][]']],
    "getPair(address,address,address)": ["61e0b77f", ['address','address','address'], ['address','address','address']],
    
	# legacy
 	"#------------------------#": ["xxxxxxxx", [], []],  
 	"KEEPER()": ["862a179e", [], ['address']],    
    # "TOK_WPLS()": ["fa4a9870", [], ['address']],
    # "BURN_ADDR()": ["783028a9", [], ['address']],
    "tVERSION()": ["9a60f330", [], ['string']],
}
UniswapFlashQuery_FUNC_MAP_getRervesByPairs = "getReservesByPairs(address[],address)"
UniswapFlashQuery_FUNC_MAP_WRITE = {
    # "getPairsByIndexRange(address,address,uint256,uint256)": ["6149de9c", ['address','address','uint256','uint256'], ['address[][]','uint256[][]']],
	# "getPairsByIndexRange_OG(address,uint256,uint256)": ["a09bdbdc", ['address','uint256','uint256'], ['address[][]']],
    "getPair(address,address,address)": ["61e0b77f", ['address','address','address'], ['address','address','address']],
    UniswapFlashQuery_FUNC_MAP_getRervesByPairs: ["66cc1fbb", ['address[]','address'], ['uint256[5][]']],
	"#------------------------#": ["xxxxxxxx", [], []],  
}
    
LPCleaner_FUNC_MAP_READ = {
    # read functions        
	# legacy
 	"#------------------------#": ["xxxxxxxx", [], []],  
 	"KEEPER()": ["862a179e", [], ['address']],    
    "TOK_WPLS()": ["fa4a9870", [], ['address']],
    "BURN_ADDR()": ["783028a9", [], ['address']],
    "tVERSION()": ["9a60f330", [], ['string']],
}
LPCleaner_FUNC_MAP_WRITE = {
    # write functions    
	"cleanLiquidityPool()": ["566391ff", [], []], 
    "uniswapV2Call(address,uint256,uint256,bytes)": ["10d1e85c", ["address",'uint256','uint256','bytes'], []], 

	# legacy
 	"#------------------------#": ["xxxxxxxx", [], []],  
 	"KEEPER_setKeeper(address)": ["11851737", ["address"], []], 
    "KEEPER_maintenance(uint256,address)": ["4dd534c0", ["uint256","address"], []], # gas used: 62,434 
    "KEEPER_withdraw(uint256)": ["cbf0d0d4", ["uint256"], []], 
}

BALANCER_FLR_FUNC_MAP_READ = {
    # read functions        
    # "b2bdfa7b": "_owner()",
	"_owner()": ["b2bdfa7b", [], ['address']],
}

BALANCER_FLR_FUNC_MAP_WRITE = {
    # remix compiled...
	# 	"c9a69562": "makeFlashLoan(address[],uint256[],bytes)",
	# 	"f04f2707": "receiveFlashLoan(address[],uint256[],uint256[],bytes)",
	# 	"a64b6e5f": "transferTokens(address,address,uint256)",
	# 	"2e1a7d4d": "withdraw(uint256)"

	# > [0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] [114983659000000000000000000] -37x
 	# > [0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2] [194103941428399548827251766] -37x
	"makeFlashLoan(address[],uint256[],bytes)": ["c9a69562", ["address[]","uint256[]","bytes"], []], # fee: 43.97 pls
    "receiveFlashLoan(address[],uint256[],uint256[],bytes)": ["f04f2707", ["address[]","uint256[]","uint256[]","bytes"], []], # shouldn't need to use (for flashload provider only)
		# "makeFlashLoan(IERC20[],uint256[],bytes)": ["c9a69562", ["address[]","uint256[]","bytes"], []], # fee: ? pls
		# "receiveFlashLoan(IERC20[],uint256[],uint256[],bytes)": ["f04f2707", ["address[]","uint256[]","uint256[]","bytes"], []], # shouldn't need to use (for flashload provider only)
    "transferTokens(address,address,uint256)": ["a64b6e5f", ["address","address","uint256"], []], # fee: ? pls
    "withdraw(uint256)": ["2e1a7d4d", ["uint256"], []], # fee: ? pls
}
USWAPv2_PAIR_FUNC_MAP_READ = {
    "token0()": ["0dfe1681", [], ['address']],
    "token1()": ["d21220a7", [], ['address']],
    "getReserves()": ["0902f1ac", [], ['uint112','uint112','uint32']],
}
USWAPv2_PAIR_FUNC_MAP_WRITE = {
    "NO_WRITE_FUNC_MAPPED()": ["0xNone", [], []],
}

USWAPv2_ROUTER_FUNC_MAP_READ = {
    "getAmountIn(uint256,uint256,uint256)": ["85f8c259", ["uint256","uint256","uint256"], ['uint256']],
    "getAmountOut(uint256,uint256,uint256)": ["054d50d4", ["uint256","uint256","uint256"], ['uint256']],
	"getAmountsIn(uint256,address[])": ["1f00ca74", ["uint256","address[]"], ['uint256[]']],
	"getAmountsOut(uint256,address[])": ["d06ca61f", ["uint256","address[]"], ['uint256[]']],
}
ROUTERv2_FUNC_ADD_LIQ_ETH = "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)"
ROUTERv2_FUNC_MAP_WRITE = {
    
	# "e8e33700": "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
    # "f305d719": "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)",
    
	# function addLiquidity(tokenA,tokenB,amountADesired,amountBDesired,amountAMin,amountBMin,to,deadline)
	"addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)": [
        "e8e33700",
        ["address","address","uint256","uint256","uint256","uint256","address","uint256"],
        ['uint','uint','uint']
	],
    # function addLiquidityETH(token,amountTokenDesired,amountTokenMin,amountETHMin,to,deadline)
    # 	ref: https://otter.pulsechain.com/tx/0x42983dc90a69f026629ccc237546ec9e6d4bc9352797141890e8f53fcd528327/trace
	ROUTERv2_FUNC_ADD_LIQ_ETH: [
        "f305d719",
        ["address","uint256","uint256","uint256","address","uint256"],
        ['uint','uint','uint']
	],

	# function removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline)
	# function removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline)
	# function removeLiquidityWithPermit(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline, approveMax, v, r, s)
	# function removeLiquidityETHWithPermit(token, liquidity, amountTokenMin, amountETHMin, to, deadline, approveMax, v, r, s)
	# function removeLiquidityETHSupportingFeeOnTransferTokens(token, liquidity, amountTokenMin, amountETHMin, to, deadline)
	# function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(token, liquidity, amountTokenMin, amountETHMin, to, deadline, approveMax, v, r, s)
    # "removeLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)": [
    #     "b09e4282",
    #     ["address", "address", "uint256", "uint256", "uint256", "uint256", "address", "uint256"],
    #     ["uint", "uint"]
    # ],
    # "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)": [
    #     "4b2cd332",
    #     ["address", "uint256", "uint256", "uint256", "address", "uint256"],
    #     ["uint", "uint"]
    # ],
    # "removeLiquidityWithPermit(address,address,uint256,uint256,uint256,uint256,address,uint8,uint256,bytes32,bytes32)": [
    #     "bfbdd843",
    #     ["address", "address", "uint256", "uint256", "uint256", "uint256", "address", "uint8", "uint256", "bytes32", "bytes32"],
    #     ["uint", "uint"]
    # ],
    # "removeLiquidityETHWithPermit(address,uint256,uint256,uint256,address,uint256,uint8,uint256,bytes32,bytes32)": [
    #     "544c5e91",
    #     ["address", "uint256", "uint256", "uint256", "address", "uint256", "uint8", "uint256", "bytes32", "bytes32"],
    #     ["uint", "uint"]
    # ],
    # "removeLiquidityETHSupportingFeeOnTransferTokens(address,uint256,uint256,uint256,address,uint256)": [
    #     "2d3a5f97",
    #     ["address", "uint256", "uint256", "uint256", "address", "uint256"],
    #     ["uint"]
    # ],
    # "removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(address,uint256,uint256,uint256,address,uint256,uint8,uint256,bytes32,bytes32)": [
    #     "e8d4907f",
    #     ["address", "uint256", "uint256", "uint256", "address", "uint256", "uint8", "uint256", "bytes32", "bytes32"],
    #     ["uint"]
    # ]
}

TBF_FUNC_MAP_READ = {
    # read functions
    "getOpenBuySell()": ["8cead068", [], ['bool','bool']],
	"getWhitelistAddresses()": ["578cbd1f", [], ['address[]']],
    "getWhitelistAddressesLP()": ["2eccefeb", [], ['address[]']],
    "WHITELIST_ADDR_MAP(address)": ["0a3e9c60", ["address"], ['bool']],
    "WHITELIST_LP_MAP(address)": ["08428223", ["address"], ['bool']],
    "LAST_TRANSFER_AMNT()": ["09479f1a", [], ['uint256']],

	"#------------SWAPD------------#": ["xxxxxxxx", [], []],
    "USER()": ["81e167cf", [], ['address']],
    "USER_INIT()": ["a7c84824", [], ['bool']],
    "VERSION()": ["ffa1ad74", [], ['uint8']],
    
    # 0x3A4bA74B3a75D9adD2faF9EaE89A8197b6C828B1
    "#------------ROB-staking------------#": ["xxxxxxxx", [], []], 
    "poolLength()": ["081e3eda", [], ['uint256']],

    # 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
 	"#------------stETH------------#": ["xxxxxxxx", [], []], 
    "getOracle()": ["833b1fce", [], ['address']], 
    "isStakingPaused()": ["1ea7ca89", [], ['bool']], 
	
	"#------------LUSD_TROVE-MANAGER------------#": ["xxxxxxxx", [], []],
    "DECIMAL_PRECISION()": ["a20baee6", [], ['uint256']],
    "REDEMPTION_FEE_FLOOR()": ["28d28b5b", [], ['uint256']],
    
	# # 0x4c517D4e2C851CA76d7eC94B805269Df0f2201De
    "#------------LUSD_TELLOR_PRICEFEED------------#": ["xxxxxxxx", [], []],
	"fetchPrice()": ["0x0fdb11cf", [], ['uint256']], # both read & write
    
 	"#------------LUSD------------#": ["xxxxxxxx", [], []],
     "lastGoodPrice()": ["0490be83", [], ['uint256']],
	 "getOwners()": ["a0e67e2b", [], ['address[]']],
     "latestAnswer()": ["50d25bcd", [], ['uint256']],
     "maxAnswer()": ["70da2f67", [], ['uint256']],
     "minAnswer()": ["22adbc78", [], ['uint256']],
     "troveManagerAddress()": ["5a4d28bb", [], ['address']],

 	"#------------BST------------#": ["xxxxxxxx", [], []],  
    "tVERSION()": ["9a60f330", [], ['string']],
 	"KEEPER()": ["862a179e", [], ['address']],    
    "TOK_WPLS()": ["fa4a9870", [], ['address']],
    "BURN_ADDR()": ["783028a9", [], ['address']],
    
 	"#------------IERC20------------#": ["xxxxxxxx", [], []], 
    "balanceOf(address)": ["70a08231", ["address"], ['uint256']],
    "decimals()": ["313ce567", [], ['uint8']],
	"owner()": ["8da5cb5b", [], ['address']],
    "name()": ["06fdde03", [], ['string']],
    "symbol()": ["95d89b41", [], ['string']],
    "totalSupply()": ["18160ddd", [], ['uint256']],
}
TBF_FUNC_MAP_WRITE = {
    # write functions
    "KEEPER_setOpenBuySell(bool,bool)": ["c0585124", ["bool","bool"], []], # fee: 18.21297 pls
    "KEEPER_editWhitelistAddress(address,bool)": ["a83d30df", ["address","bool"], []],
    "KEEPER_editWhitelistAddressLP(address,bool)": ["663d4e42", ["address","bool"], []],
    
    "KEEPER_editWhitelistAddressMulti(bool,address[])": ["dfa01380", ["bool","address[]"], []],
    "KEEPER_editWhitelistAddressMultiLP(bool,address[])": ["127a8bf8", ["bool","address[]"], []],
    
	"KEEPER_mixAmntRand(address[])": ["359b5ba6", ['address[]'], []], # has failed at 937_000 max units (451.806+ pls)
    "KEEPER_distrAmntRandFrom(address,uint64,address[])": ["08d7b8df", ['address','uint64','address[]'], []],
    "distrAmntRand(uint64,address[])": ["d3692a0a", ['uint64','address[]'], []], # fee: 69.956423 pls
    
	"#------------SWAPD------------#": ["xxxxxxxx", [], []], 
    "USER_burnToken(address,uint256)": ["b2eee154", ['address','uint256'], []],
    "USER_maintenance(uint256,address)": ["e8d1eac1", ['uint256','address'], []],
    "USER_setUser(address)": ["0e2d844d", ['address'], []],
    
 	"#------------stETH------------#": ["xxxxxxxx", [], []], 
     "pauseStaking()": ["f999c506", [], []],
     "submit(address)": ["a1903eab", ['address'], ['uint256']],
     
	"#------------LUSD_TROVE-MANAGER------------#": ["xxxxxxxx", [], []],
    "redeemCollateral(uint256,address,address,address,uint256,uint256,uint256)": ["bcd37526", ['uint256','address','address','address','uint256','uint256','uint256'], []],
    
	# 0x4c517D4e2C851CA76d7eC94B805269Df0f2201De
    "#------------LUSD_TELLOR_PRICEFEED------------#": ["xxxxxxxx", [], []],
	"fetchPrice()": ["0x0fdb11cf", [], ['uint256']], # both read & write
    
 	"#------------BST------------#": ["xxxxxxxx", [], []],
 	"KEEPER_setKeeper(address)": ["11851737", ["address"], []], 
	"KEEPER_setTokNameSymb(string,string)": ["65c021bc", ["string","string"], []],
    "burn(uint64)": ["9dbead42", ["uint64"], []], 
    
 	"#------------IERC20------------#": ["xxxxxxxx", [], []],
    "allowance(address,address)": ["dd62ed3e", ["address","address"], []],
    "approve(address,uint256)": ["095ea7b3", ["address","uint256"], []],
    "transfer(address,uint256)": ["a9059cbb", ["address","uint256"], []],
    "transferFrom(address,address,uint256)": ["23b872dd", ["address","address","uint256"], []],
    "renounceOwnership()": ["715018a6", [], []],
    "transferOwnership(address)": ["f2fde38b", ["address"], []],
}

LUSDst_GET_ACCT_PAYOUTS_FUNC_HASH = "d08e6c88"
LUSDst_FUNC_MAP_READ = {
	# read functions (lusdst additions)
    "ENABLE_TOK_BURN_LOCK()": ["51026e20", [], ['bool']],
    "TOK_BURN_LOCK()": ["ff35c2df", [], ['address']],
    
	"#------------COMMON_ADDRESSES------------#": ["xxxxxxxx", [], []],
    "TOK_pLUSD()": ["c28d25f4", [], ['address']],
    "TOK_WPLS()": ["fa4a9870", [], ['address']],
    "BURN_ADDR()": ["783028a9", [], ['address']],
    
    # read functions (bst legacy)
    "#------------BST-legacy------------#": ["xxxxxxxx", [], []],
    "KEEPER()": ["862a179e", [], ['address']],
    "KEEPER_collectiveStableBalances(bool,uint256)": ["cf0c8683", ['bool','uint256'], ['uint64','uint64','int64','uint256']],
    # "KEEPER_getRatios(uint256)": ["ffa21500", ['uint256'], ['uint32','uint32']],
    
    "ACCT_USD_BALANCES(address)": ["c67483dc", ["address"], ['uint64']],
    "ACCT_USD_PAYOUTS(address,uint256)": ["8b47da26", ["address","uint256"], ['address', 'uint64', 'uint64', 'uint64', 'uint64', 'uint64', 'uint64', 'uint256', 'address']],

    "USD_STABLE_DECIMALS(address)": ["7f8754f4", ["address"], ['uint8']],
    "USWAP_V2_ROUTERS(uint256)": ["ee80b054", ["uint256"], ['address']],
    
    "getAccounts()": ["8a48ac03", [], ['address[]']],
    "getAccountPayouts(address)": [LUSDst_GET_ACCT_PAYOUTS_FUNC_HASH, ["address"], ['address', 'uint64', 'uint64', 'uint64', 'uint64', 'uint64', 'uint256', 'address']],

    "getDexOptions()": ["3685f08b", [], ['bool','bool','bool']],
    "getPayoutPercs()": ["2edef8a4", [], ['uint32','uint32','uint32','uint32']],
    
    "getUsdStablesHistory()": ["d4155f07", [], ['address[]']],
    "getWhitelistStables()": ["00f403e8", [], ['address[]']],
    "getDexRouters()": ["ba41debb", [], ['address[]']],
    "getSwapDelegateInfo()": ["4bae2eef", [], ['address','uint8','address']],
    "getUsdBstPath(address)": ["260e5df9", ['address'], ['address[]']],

	"#------------IERC20------------#": ["xxxxxxxx", [], []],
    "balanceOf(address)": ["70a08231", ["address"], ['uint256']],
    "decimals()": ["313ce567", [], ['uint8']],
	"owner()": ["8da5cb5b", [], ['address']],
    "name()": ["06fdde03", [], ['string']],
    "symbol()": ["95d89b41", [], ['string']],
    "tVERSION()": ["9a60f330", [], ['string']],
    "totalSupply()": ["18160ddd", [], ['uint256']],
}

LUSDst_PAYOUT_FUNC_SIGN = "payOutBST(uint64,address,address,bool)"
LUSDst_PAYOUT_FUNC_HASH = '5c1b4b51'
LUSDst_FUNC_MAP_WRITE = {
    # write functions (lusdst additions)
    "KEEPER_setTokenBurnLock(address,bool)": ["f5d22c46", ["address","bool"], []], # gas used: ?
    "KEEPER_withdraw(uint256)": ["cbf0d0d4", ["uint256"], []], # gas used: ?
    
	# write functions (bst legacy)
    "#------------BST-legacy------------#": ["xxxxxxxx", [], []],
    "KEEPER_maintenance(address,uint256)": ["72dc3b3f", ["address","uint256"], []], # gas used: ?
    # "KEEPER_setRatios(uint32,uint32)": ["3dcff192", ["uint32","uint32"], []], 

    "KEEPER_setKeeper(address)": ["11851737", ["address"], []], 
    "KEEPER_setKeeperCheck(uint256)": ["9d7c9834", ["uint256"], []],
    "KEEPER_setSwapDelegate(address)": ["c1533a53", ["address"], []],
	"KEEPER_setSwapDelegateUser(address)": ["126d4301", ['address'], []],

    "KEEPER_editDexRouters(address,bool)": ["bceeba33", ["address","bool"], []], # gas used: 36,601 (rem), 55,723 (add)
    "KEEPER_editWhitelistStables(address,uint8,bool)": ["b290b9bf", ["address","uint8","bool"], []],
    "KEEPER_setUsdBstPath(address,address[])": ["4f51d029", ['address','address[]'], []], # gas used: 38,852
    "KEEPER_setDexOptions(bool,bool,bool)": ["80143a0d", ["bool","bool","bool"], []], # gas used: 7.731

    "KEEPER_setPayoutPercs(uint32,uint32,uint32)": ["c0e202fa", ["uint32","uint32","uint32"], []], # gas used: 30,082
    # "KEEPER_setBuyBackFeePerc(uint32)": ["57e8a5a5", ["uint32"], []], # gas used: 28,887
    "KEEPER_setTokNameSymb(string,string)": ["65c021bc", ["string","string"], []],

    LUSDst_PAYOUT_FUNC_SIGN: [LUSDst_PAYOUT_FUNC_HASH, ["uint64","address","address","bool"], []], # gas used: 837,000+
    # BST_TRADEIN_FUNC_SIGN: [BST_TRADEIN_FUNC_HASH, ["uint64"], []], # gas used: 126,956+

	"#------------IERC20------------#": ["xxxxxxxx", [], []],
    "burn(uint64)": ["9dbead42", ["uint64"], []], 
    "allowance(address,address)": ["dd62ed3e", ["address","address"], []],
    "approve(address,uint256)": ["095ea7b3", ["address","uint256"], []],
    "transfer(address,uint256)": ["a9059cbb", ["address","uint256"], []],
    "transferFrom(address,address,uint256)": ["23b872dd", ["address","address","uint256"], []],
    "renounceOwnership()": ["715018a6", [], []],
    "transferOwnership(address)": ["f2fde38b", ["address"], []],
}

BST_GET_ACCT_PAYOUTS_FUNC_HASH = "d08e6c88"
BST_FUNC_MAP_READ = {
    # read functions
    "KEEPER()": ["862a179e", [], ['address']],
    "KEEPER_collectiveStableBalances(bool,uint256)": ["cf0c8683", ['bool','uint256'], ['uint64','uint64','uint64','int64']],
    "KEEPER_getRatios(uint256)": ["ffa21500", ['uint256'], ['uint32','uint32']],
    
    "ACCT_USD_BALANCES(address)": ["c67483dc", ["address"], ['uint64']],
    "ACCT_USD_PAYOUTS(address,uint256)": ["8b47da26", ["address","uint256"], ['address', 'uint64', 'uint64', 'uint64', 'uint64', 'uint64', 'uint64', 'uint256', 'address']],

    "USD_STABLE_DECIMALS(address)": ["7f8754f4", ["address"], ['uint8']],
    "USWAP_V2_ROUTERS(uint256)": ["ee80b054", ["uint256"], ['address']],
    
    "balanceOf(address)": ["70a08231", ["address"], ['uint256']],
    "decimals()": ["313ce567", [], ['uint8']],
    "getAccounts()": ["8a48ac03", [], ['address[]']],
    "getAccountPayouts(address)": [BST_GET_ACCT_PAYOUTS_FUNC_HASH, ["address"], ['address', 'uint64', 'uint64', 'uint64', 'uint64', 'uint64', 'uint256', 'address']],

    "getDexOptions()": ["3685f08b", [], ['bool','bool','bool']],
    "getPayoutPercs()": ["2edef8a4", [], ['uint32','uint32','uint32','uint32']],
    
    "getUsdStablesHistory()": ["d4155f07", [], ['address[]']],
    "getWhitelistStables()": ["00f403e8", [], ['address[]']],
    "getDexRouters()": ["ba41debb", [], ['address[]']],
    "getSwapDelegateInfo()": ["4bae2eef", [], ['address','uint8','address']],
    "getUsdBstPath(address)": ["260e5df9", ['address'], ['address[]']],

    "TOK_WPLS()": ["fa4a9870", [], ['address']],
    "BURN_ADDR()": ["783028a9", [], ['address']],

	"owner()": ["8da5cb5b", [], ['address']],
    "name()": ["06fdde03", [], ['string']],
    "symbol()": ["95d89b41", [], ['string']],
    "tVERSION()": ["9a60f330", [], ['string']],
    "totalSupply()": ["18160ddd", [], ['uint256']],
}
BST_PAYOUT_FUNC_SIGN = "payOutBST(uint64,address,address,bool)"
BST_PAYOUT_FUNC_HASH = '5c1b4b51'
BST_TRADEIN_FUNC_SIGN = "tradeInBST(uint64)"
BST_TRADEIN_FUNC_HASH = "d8785767"
BST_FUNC_MAP_WRITE = {
    # write functions
    "KEEPER_maintenance(uint256,address)": ["4dd534c0", ["uint256","address"], []], # gas used: 62,434
    "KEEPER_setRatios(uint32,uint32)": ["3dcff192", ["uint32","uint32"], []], 

    "KEEPER_setKeeper(address)": ["11851737", ["address"], []], 
    "KEEPER_setKeeperCheck(uint256)": ["9d7c9834", ["uint256"], []],
    "KEEPER_setSwapDelegate(address)": ["c1533a53", ["address"], []],
	"KEEPER_setSwapDelegateUser(address)": ["126d4301", ['address'], []],

    "KEEPER_editDexRouters(address,bool)": ["bceeba33", ["address","bool"], []], # gas used: 36,601 (rem), 55,723 (add)
    "KEEPER_editWhitelistStables(address,uint8,bool)": ["b290b9bf", ["address","uint8","bool"], []],
    "KEEPER_setUsdBstPath(address,address[])": ["4f51d029", ['address','address[]'], []], # gas used: 38,852
    "KEEPER_setDexOptions(bool,bool,bool)": ["80143a0d", ["bool","bool","bool"], []], # gas used: 7.731

    "KEEPER_setPayoutPercs(uint32,uint32,uint32)": ["c0e202fa", ["uint32","uint32","uint32"], []], # gas used: 30,082
    "KEEPER_setBuyBackFeePerc(uint32)": ["57e8a5a5", ["uint32"], []], # gas used: 28,887
    "KEEPER_setTokNameSymb(string,string)": ["65c021bc", ["string","string"], []],

    BST_PAYOUT_FUNC_SIGN: [BST_PAYOUT_FUNC_HASH, ["uint64","address","address","bool"], []], # gas used: 837,000+
    BST_TRADEIN_FUNC_SIGN: [BST_TRADEIN_FUNC_HASH, ["uint64"], []], # gas used: 126,956+

    "burn(uint64)": ["9dbead42", ["uint64"], []], 
    "allowance(address,address)": ["dd62ed3e", ["address","address"], []],
    "approve(address,uint256)": ["095ea7b3", ["address","uint256"], []],
    "transfer(address,uint256)": ["a9059cbb", ["address","uint256"], []],
    "transferFrom(address,address,uint256)": ["23b872dd", ["address","address","uint256"], []],
    "renounceOwnership()": ["715018a6", [], []],
    "transferOwnership(address)": ["f2fde38b", ["address"], []],
}

BST_ABI = [
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "_initSupply",
				"type": "uint256"
			}
		],
		"stateMutability": "nonpayable",
		"type": "constructor"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "allowance",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "needed",
				"type": "uint256"
			}
		],
		"name": "ERC20InsufficientAllowance",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "sender",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "balance",
				"type": "uint256"
			},
			{
				"internalType": "uint256",
				"name": "needed",
				"type": "uint256"
			}
		],
		"name": "ERC20InsufficientBalance",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "approver",
				"type": "address"
			}
		],
		"name": "ERC20InvalidApprover",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "receiver",
				"type": "address"
			}
		],
		"name": "ERC20InvalidReceiver",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "sender",
				"type": "address"
			}
		],
		"name": "ERC20InvalidSender",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			}
		],
		"name": "ERC20InvalidSpender",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "owner",
				"type": "address"
			}
		],
		"name": "OwnableInvalidOwner",
		"type": "error"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "OwnableUnauthorizedAccount",
		"type": "error"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": True,
				"internalType": "address",
				"name": "owner",
				"type": "address"
			},
			{
				"indexed": True,
				"internalType": "address",
				"name": "spender",
				"type": "address"
			},
			{
				"indexed": False,
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "Approval",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "address",
				"name": "_account",
				"type": "address"
			},
			{
				"indexed": False,
				"internalType": "uint256",
				"name": "_plsDeposit",
				"type": "uint256"
			},
			{
				"indexed": False,
				"internalType": "uint64",
				"name": "_stableConvert",
				"type": "uint64"
			}
		],
		"name": "DepositReceived",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "address",
				"name": "_prev",
				"type": "address"
			},
			{
				"indexed": False,
				"internalType": "address",
				"name": "_new",
				"type": "address"
			}
		],
		"name": "KeeperTransfer",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "bool",
				"name": "_prev",
				"type": "bool"
			},
			{
				"indexed": False,
				"internalType": "bool",
				"name": "_new",
				"type": "bool"
			}
		],
		"name": "MarketBuyEnabled",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "bool",
				"name": "_prev",
				"type": "bool"
			},
			{
				"indexed": False,
				"internalType": "bool",
				"name": "_new",
				"type": "bool"
			}
		],
		"name": "MarketQuoteEnabled",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": True,
				"internalType": "address",
				"name": "previousOwner",
				"type": "address"
			},
			{
				"indexed": True,
				"internalType": "address",
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "OwnershipTransferred",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "address",
				"name": "_from",
				"type": "address"
			},
			{
				"indexed": False,
				"internalType": "address",
				"name": "_to",
				"type": "address"
			},
			{
				"indexed": False,
				"internalType": "uint64",
				"name": "_usdAmnt",
				"type": "uint64"
			}
		],
		"name": "PayOutProcessed",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "uint8",
				"name": "_prev",
				"type": "uint8"
			},
			{
				"indexed": False,
				"internalType": "uint8",
				"name": "_new",
				"type": "uint8"
			}
		],
		"name": "ServiceBurnUpdate",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "uint8",
				"name": "_prev",
				"type": "uint8"
			},
			{
				"indexed": False,
				"internalType": "uint8",
				"name": "_new",
				"type": "uint8"
			}
		],
		"name": "ServiceFeeUpdate",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "uint8",
				"name": "_prev",
				"type": "uint8"
			},
			{
				"indexed": False,
				"internalType": "uint8",
				"name": "_new",
				"type": "uint8"
			}
		],
		"name": "TradeInFeeUpdate",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": False,
				"internalType": "address",
				"name": "_trader",
				"type": "address"
			},
			{
				"indexed": False,
				"internalType": "uint64",
				"name": "_bstAmnt",
				"type": "uint64"
			},
			{
				"indexed": False,
				"internalType": "uint64",
				"name": "_usdTradeVal",
				"type": "uint64"
			}
		],
		"name": "TradeInProcessed",
		"type": "event"
	},
	{
		"anonymous": False,
		"inputs": [
			{
				"indexed": True,
				"internalType": "address",
				"name": "from",
				"type": "address"
			},
			{
				"indexed": True,
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"indexed": False,
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "Transfer",
		"type": "event"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"name": "ACCT_USD_BALANCES",
		"outputs": [
			{
				"internalType": "uint64",
				"name": "",
				"type": "uint64"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"name": "ACCT_USD_PAYOUTS",
		"outputs": [
			{
				"internalType": "address",
				"name": "receiver",
				"type": "address"
			},
			{
				"internalType": "uint64",
				"name": "usdAmnt",
				"type": "uint64"
			},
			{
				"internalType": "uint64",
				"name": "usdFee",
				"type": "uint64"
			},
			{
				"internalType": "uint64",
				"name": "usdBurn",
				"type": "uint64"
			},
			{
				"internalType": "uint64",
				"name": "usdPayout",
				"type": "uint64"
			},
			{
				"internalType": "uint64",
				"name": "bstBurn",
				"type": "uint64"
			},
			{
				"internalType": "uint64",
				"name": "bstPayout",
				"type": "uint64"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "BUY_BACK_FEE_PERC",
		"outputs": [
			{
				"internalType": "uint8",
				"name": "",
				"type": "uint8"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "ENABLE_MARKET_BUY",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "ENABLE_MARKET_QUOTE",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "KEEPER",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_router",
				"type": "address"
			},
			{
				"internalType": "bool",
				"name": "_add",
				"type": "bool"
			}
		],
		"name": "KEEPER_editDexRouters",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_usdStable",
				"type": "address"
			},
			{
				"internalType": "uint8",
				"name": "_decimals",
				"type": "uint8"
			},
			{
				"internalType": "bool",
				"name": "_add",
				"type": "bool"
			}
		],
		"name": "KEEPER_editWhitelistStables",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "bool",
				"name": "_enable",
				"type": "bool"
			}
		],
		"name": "KEEPER_enableMarketBuy",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "bool",
				"name": "_enable",
				"type": "bool"
			}
		],
		"name": "KEEPER_enableMarketQuote",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint64",
				"name": "_usdAmnt",
				"type": "uint64"
			},
			{
				"internalType": "address",
				"name": "_usdStable",
				"type": "address"
			}
		],
		"name": "KEEPER_maintenance",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint8",
				"name": "_perc",
				"type": "uint8"
			}
		],
		"name": "KEEPER_setBuyBackFeePerc",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "_newKeeper",
				"type": "address"
			}
		],
		"name": "KEEPER_setKeeper",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint8",
				"name": "_perc",
				"type": "uint8"
			}
		],
		"name": "KEEPER_setServiceBurnPerc",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint8",
				"name": "_perc",
				"type": "uint8"
			}
		],
		"name": "KEEPER_setServiceFeePerc",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "SERVICE_BURN_PERC",
		"outputs": [
			{
				"internalType": "uint8",
				"name": "",
				"type": "uint8"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "SERVICE_FEE_PERC",
		"outputs": [
			{
				"internalType": "uint8",
				"name": "",
				"type": "uint8"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "TOK_WPLS",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"name": "USD_STABLE_DECIMALS",
		"outputs": [
			{
				"internalType": "uint8",
				"name": "",
				"type": "uint8"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"name": "USWAP_V2_ROUTERS",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"name": "WHITELIST_USD_STABLES",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "owner",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			}
		],
		"name": "allowance",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "spender",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "approve",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "account",
				"type": "address"
			}
		],
		"name": "balanceOf",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "decimals",
		"outputs": [
			{
				"internalType": "uint8",
				"name": "",
				"type": "uint8"
			}
		],
		"stateMutability": "pure",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getSwapRouters",
		"outputs": [
			{
				"internalType": "address[]",
				"name": "",
				"type": "address[]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "getWhitelistStables",
		"outputs": [
			{
				"internalType": "address[]",
				"name": "",
				"type": "address[]"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "name",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "owner",
		"outputs": [
			{
				"internalType": "address",
				"name": "",
				"type": "address"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint64",
				"name": "_usdValue",
				"type": "uint64"
			},
			{
				"internalType": "address",
				"name": "_payTo",
				"type": "address"
			}
		],
		"name": "payOutBST",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "renounceOwnership",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "symbol",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "tVERSION",
		"outputs": [
			{
				"internalType": "string",
				"name": "",
				"type": "string"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [],
		"name": "totalSupply",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "uint64",
				"name": "_bstAmnt",
				"type": "uint64"
			}
		],
		"name": "tradeInBST",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "transfer",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "from",
				"type": "address"
			},
			{
				"internalType": "address",
				"name": "to",
				"type": "address"
			},
			{
				"internalType": "uint256",
				"name": "value",
				"type": "uint256"
			}
		],
		"name": "transferFrom",
		"outputs": [
			{
				"internalType": "bool",
				"name": "",
				"type": "bool"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{
				"internalType": "address",
				"name": "newOwner",
				"type": "address"
			}
		],
		"name": "transferOwnership",
		"outputs": [],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"stateMutability": "payable",
		"type": "receive"
	}
]