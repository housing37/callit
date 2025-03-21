__fname = '_constants' # ported from 'defi-arb' (121023)
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

#------------------------------------------------------------#
#   GLOBALS
#------------------------------------------------------------#
## STATIC CONSTANTS
AMNT_MAX = 115792089237316195423570985008687907853269984665640564039457584007913129639935 # uint256.max

#------------------------------------------------------------#
#   DEX ROUTERS
#------------------------------------------------------------#
# ethereum mainnet dex router support
ROUTER_UNISWAP_V3 = '0xE592427A0AEce92De3Edee1F18E0157C05861564'
ROUTER_PANCAKESWAP_V3 = '0x13f4EA83D0bd40E75C8222255bc855a974568Dd4'
ROUTER_9INCH_EM = '0xFD8b9Ba4845fB38c779317eC134b298C064937a2'

# pulsechain dex router support
# this is what i've found for v1 and v2 routers (i don't see 0x98b ever used in my MM txs)
#   not sure what 0x98b is for ref: https://www.irccloud.com/pastebin/6ftmqWuk
ROUTER_pulsex_router02_v1='0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02' # PulseXRouter02 'v1' ref: https://www.irccloud.com/pastebin/6ftmqWuk
ROUTER_pulsex_router02_v2='0x165C3410fC91EF562C50559f7d2289fEbed552d9' # PulseXRouter02 'v2' ref: https://www.irccloud.com/pastebin/6ftmqWuk
ROUTER_pulsex_router02_vX='0xa619F23c632CA9f36CD4Dcea6272E1eA174aAC27' # PulseXSwapRouter 'v1' ref: MM tx
    # ref tx: https://scan.pulsechain.com/tx/0x3c3cceb53976f332f97e1345cd97488d01a33f81cee81d4f08d0aaad574e7735/
ROUTER_9INCH_PC = '0xeB45a3c4aedd0F47F345fB4c8A1802BB5740d725'

# pulsechain dex router factories
FACTORY_pulsex_router_02_v1='0x1715a3E4A142d8b698131108995174F37aEBA10D'
FACTORY_pulsex_router_02_v2='0x29eA7545DEf87022BAdc76323F373EA1e707C523'


#------------------------------------------------------------#
#   TOKEN ADDRESSES
#------------------------------------------------------------#
# ethereum mainnet
ADDR_rETH = '0xae78736Cd615f374D3085123A210448E74Fc6393'
ADDR_DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F'

ADDR_WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
ADDR_WBTC = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599'
ADDR_USDT = '0xdAC17F958D2ee523a2206206994597C13D831ec7'
ADDR_USDC = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'

ADDR_BBTC = '0x9BE89D2a4cd102D8Fecc6BF9dA793be995C22541'

# pulsechain
ADDR_ROB = '0x1c2766F5949A4aA5d4cf0439067051135ffc1b28'
ADDR_WPLS = '0xA1077a294dDE1B09bB078844df40758a5D0f9a27'
ADDR_ATROP = '0xCc78A0acDF847A2C1714D2A925bB4477df5d48a6'
ADDR_WHETH = '0xDe0220b69CE3e855a0124433A8E8D093f53A6bE4'
ADDR_PLSX = '0x95B303987A60C71504D99Aa1b13B4DA07b0790ab'
ADDR_WBTCp = '0xb17D901469B9208B17d916112988A3FeD19b5cA1'
ADDR_9INCH = '0x3ca80d83277e721171284667829c686527B8b3c5'
#------------------------------------------------------------#
print('getting keys and setting globals ...')
## SETTINGS ##
#abi_file = "../contracts/BalancerFLR.json"
#bin_file = "../contracts/BalancerFLR.bin"
abi_file = "../contracts/BalancerFLR_test.json"
bin_file = "../contracts/BalancerFLR_test.bin"
# abi_file = "../contracts/BalancerFLR_pc.json"
# bin_file = "../contracts/BalancerFLR_pc.bin"
LST_CONTR_ARB_ADDR = [
    "0x59012124c297757639e4ab9b9e875ec80a5c51da", # deployed eth main 102823_1550
    "0x48af7d501bca526171b322ac2d8387a8cf085850", # deployed eth main 102823_2140
    "0x0B3f73687A5F78ACbdEccF860cEd0d8A5630F806", # deployed pc main 103023_2128
    "0xc2fa6dF341b18AE3c283CE3E7C0f1b4F5F6cabBb", # deployed pc main 110123_1953
    "0x42b2dDF6cd1C4c269785a228D40307a1e0441c77", # deployed pc main 110323_1649
    "0xF02e6E28E250073583766D77e161f67C21aEe388", # deployed pc main 110323_1715
    "0xc3B031914Ef19E32859fbe72b52e1240335B60da", # deployed pc main 110323_1759
    "0x4e24f4814306fd8cA4e63f342E8AF1675893c002", # deployed pc main 110323_1902 (TEST-LOAN)
    "0x8cC1fa4FA6aB21D25f07a69f8bBbCbEAE7AD150d", # deployed pc main 110323_1937 (TEST-LOAN)
    "0x5605ca222d290dFf31C4174AbCDFadc7DED90915", # deployed pc main 110323_2301 (TEST-LOAN)
    "0x102761aEe47Be429ac397E70c5454ea8dedCfeeD", # deployed pc main 110623_0130 (TEST-ARB)
    "0xBaE8F85bddA86E09b1555a2eFe031e80DF8b6de1", # deployed pc main 110623_0203 (TEST-ARB)
    "0xD0283328BC73E624Ccac40f138bb620287c0EC76", # deployed pc main 110623_1006 (TEST-ARB)
    "0x302CC7e8ffc8361c84b21450bAB7e018E41359c3", # deployed pc main 110623_1025 (TEST-ARB)
    "0xEE123F711176E22Ebb98eD5951c640722703BEf7", # deployed pc main 110623_1122 (TEST-ARB)
]
#------------------------------------------------------------#

