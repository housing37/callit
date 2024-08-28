__fname = '_keeper' # ported from 'defi-arb' (121023)
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

#------------------------------------------------------------#
#   IMPORTS                                                  #
#------------------------------------------------------------#
import sys, os, traceback, time, pprint, json
from datetime import datetime
from _env import env
import pprint
from attributedict.collections import AttributeDict # tx_receipt requirement
import _web3 # from web3 import Account, Web3, HTTPProvider
import _abi, _gen_pls_key
from ethereum.abi import encode_abi, decode_abi # pip install ethereum

DEBUG_LEVEL = 0
# LST_CONTR_ABI_BIN = [
#     "../bin/contracts/CallitLib",
#     "../bin/contracts/CallitVault",
#     "../bin/contracts/CallitDelegate",
#     "../bin/contracts/CallitToken",
#     "../bin/contracts/CallitFactory",
# ]

W3_ = None
ABI_FILE = None
BIN_FILE = None
CONTRACT = None
CONTRACT_ABI = None

# note: params checked/set in priority order; 'def|max_params' uses 'mpf_ratio'
#   if all params == False, falls back to 'min_params=True' (ie. just use 'gas_limit')
def get_gas_params_lst(rpc_url, min_params=False, max_params=False, def_params=True, _w3:_web3.myWEB3=None):
    global W3_
    if _w3 == None: _w3 = W3_
    # Estimate the gas cost for the transaction
    gas_limit = _w3.GAS_LIMIT # max gas units to use for tx (required)
    gas_price = _w3.GAS_PRICE # price to pay for each unit of gas (optional?)
    max_fee = _w3.MAX_FEE # max fee per gas unit to pay (optional?)
    max_prior_fee = _w3.MAX_PRIOR_FEE # max fee per gas unit to pay for priority (faster) (optional)
    #max_priority_fee = W3.to_wei('0.000000003', 'ether')

    if min_params:
        return [{'gas':gas_limit}]
    elif max_params:
        #return [{'gas':gas_limit}, {'gasPrice': gas_price}, {'maxFeePerGas': max_fee}, {'maxPriorityFeePerGas': max_prior_fee}]
        return [{'gas':gas_limit}, {'maxFeePerGas': max_fee}, {'maxPriorityFeePerGas': max_prior_fee}]
    elif def_params:
        return [{'gas':gas_limit}, {'maxPriorityFeePerGas': max_prior_fee}]
    else:
        return [{'gas':gas_limit}]

def generate_contructor():
    constr_args = []
    print()
    while True:
        arg = input(' Add constructor arg (use -1 to end):\n  > ')
        if arg == '-1': break
        if arg.isdigit(): arg = int(arg)
        constr_args.append(arg)
    return constr_args

def write_with_hash(_contr_addr, _func_hash, _lst_param_types, _lst_params, _lst_ret_types, _value_in_wei=0, _w3:_web3.myWEB3=None, _tx_wait_sec=300):
    global W3_
    if _w3 == None: _w3 = W3_

    print('preparing function signature w/ func hash & params lists ...')
    func_sign = _func_hash
    if len(_lst_param_types) > 0:
        func_sign = _func_hash + encode_abi(_lst_param_types, _lst_params).hex()

    print(f'building tx_data w/ ...\n _contr_addr: {_contr_addr}\n _func_hash: 0x{_func_hash}\n _lst_params: {_lst_params}')
    tx_data = {
        "to": _contr_addr,
        "data": func_sign,
        "value":_value_in_wei,
    }

    print('setting tx_params ...')
    tx_nonce = _w3.W3.eth.get_transaction_count(_w3.SENDER_ADDRESS)
    tx_params = {
        'chainId': _w3.CHAIN_ID,
        'nonce': tx_nonce,
    }
    print('setting gas params in tx_params ...')
    lst_gas_params = get_gas_params_lst(_w3.RPC_URL, min_params=False, max_params=True, def_params=True, _w3=_w3)
    for d in lst_gas_params: tx_params.update(d) # append gas params

    print('update tx_data w/ tx_params')
    tx_data.update(tx_params)

    print(f'signing and sending tx w/ NONCE: {tx_nonce} ... {get_time_now()}')
    tx_signed = _w3.W3.eth.account.sign_transaction(tx_data, private_key=_w3.SENDER_SECRET)
    tx_hash = _w3.W3.eth.send_raw_transaction(tx_signed.rawTransaction)

    print(cStrDivider_1, f'waiting for receipt ... {get_time_now()}', sep='\n')
    print(f'    tx_hash: {tx_hash.hex()}')

    # Wait for the transaction to be mined
    # wait_time = 300 # sec
    wait_time = _tx_wait_sec # sec
    try:
        tx_receipt = _w3.W3.eth.wait_for_transaction_receipt(tx_hash, timeout=wait_time)
        print("Transaction confirmed in block:", tx_receipt.blockNumber, f' ... {get_time_now()}')
    except Exception as e:
        print(f"\n{get_time_now()}\n Transaction not confirmed within the specified timeout... wait_time: {wait_time}")
        print_except(e, debugLvl=DEBUG_LEVEL)
        return -1, tx_hash.hex(), {}
        # exit(1)

    # print incoming tx receipt (requires pprint & AttributeDict)
    tx_receipt = AttributeDict(tx_receipt) # import required
    tx_rc_print = pprint.PrettyPrinter().pformat(tx_receipt)
    print(cStrDivider_1, f'RECEIPT:\n {tx_rc_print}', sep='\n')
    print("\nTransaction mined!")
    print(f" return status={tx_receipt['status']}")
    # tx_status = tx_receipt['status']
    # tx_hash = tx_receipt['logs'][0]['transactionHash']
    
    # Get the logs from the transaction receipt
    d_ret_log = parse_logs_for_func_hash(tx_receipt, _func_hash, _w3)
    print('returning from "write_with_hash"')
    return tx_receipt, tx_hash.hex(), d_ret_log

def parse_logs_for_func_hash(_tx_receipt, _func_hash, _w3:_web3.myWEB3=None):
    # Get the logs from the transaction receipt
    logs = _tx_receipt['logs']
    d_ret_log = {'err':'no logs found'}
    if _w3 == None: return d_ret_log
    print(f' event logs (for func_hash: 0x{_func_hash}) ...')
    if _func_hash == _abi.BST_FUNC_MAP_WRITE[_abi.BST_PAYOUT_FUNC_SIGN][0]:
        # Define & filter logs based on the event signature
        # event PayOutProcessed(address _from, address _to, uint64 _usdAmnt, uint64 _usdAmntPaid, uint64 _bstPayout, uint64 _usdFee, uint64 _usdBurnValTot, uint64 _usdBurnVal, uint64 _usdAuxBurnVal, address _auxToken, uint32 _ratioBstPay, uint256 _blockNumber);
        # event_signature = _w3.W3.keccak(text="PayOutProcessed(address,address,uint64,uint64,uint64,uint64,uint64,uint64,uint64,address,uint32,uint256)").hex()
        # pay_out_logs = [log for log in logs if log['topics'][0].hex() == event_signature]

        evt_sign_0 = _w3.W3.keccak(text="PayOutProcessed(address,address,uint64,uint64,uint64,uint64,uint64,uint64,uint64,address,uint32,uint256)").hex()
        evt_sign_1 = _w3.W3.keccak(text="BuyAndBurnExecuted(address,uint256)").hex()
        pay_out_logs = [log for log in logs if log['topics'][0].hex() in evt_sign_0]
        
        d_ret_log = {}
        # Parse the event logs
        for log in pay_out_logs:
            lst_evt_params = ['address','address','uint64','uint64','uint64','uint64','uint64','uint64','uint64','address','uint32','uint256']
            decoded_data = decode_abi(lst_evt_params, log['data'])
            d_ret_log.update({'_from':decoded_data[0],
                         '_to':decoded_data[1],
                         '_usdAmnt':decoded_data[2],
                         '_usdAmntPaid':decoded_data[3],
                         '_bstPayout':decoded_data[4],
                         '_usdFee':decoded_data[5],
                         '_usdBurnValTot':decoded_data[6],
                         '_usdBurnVal':decoded_data[7],
                         '_usdAuxBurnVal':decoded_data[8],
                         '_auxToken':decoded_data[9],
                         '_ratioBstPay':decoded_data[10],
                         '_blockNumber':decoded_data[11]})
        
            # [print(f'   {key}: {val}') for key,val in d_ret_log.items()]
            # print()
        
        pay_out_logs = [log for log in logs if log['topics'][0].hex() in evt_sign_1]
        # Parse the event logs
        for log in pay_out_logs:
            lst_evt_params = ['address','uint256']
            decoded_data = decode_abi(lst_evt_params, log['data'])
            d_ret_log.update({'_burnTok':decoded_data[0],
                            '_burnAmnt':decoded_data[1]})
        [print(f'   {key}: {val}') for key,val in d_ret_log.items()]
        print()
        print(decoded_data)

    if _func_hash == _abi.BST_FUNC_MAP_WRITE[_abi.BST_TRADEIN_FUNC_SIGN][0]:
        # Define & filter logs based on the event signature
        # event TradeInProcessed(address _trader, uint64 _bstAmnt, uint64 _usdTradeVal, uint64 _usdBuyBackVal, uint32 _ratioUsdPay, uint256 _blockNumber);
        event_signature = _w3.W3.keccak(text="TradeInProcessed(address,uint64,uint64,uint64,uint32,uint256)").hex()
        pay_out_logs = [log for log in logs if log['topics'][0].hex() == event_signature]
        
        # Parse the event logs
        for log in pay_out_logs:
            lst_evt_params = ['address', 'uint64', 'uint64', 'uint64', 'uint32','uint256']
            evt_data = log['data']
            decoded_data = decode_abi(lst_evt_params, evt_data)
            d_ret_log = {'_trader':decoded_data[0],
                         '_bstAmnt':decoded_data[1],
                         '_usdTradeVal':decoded_data[2],
                         '_usdBuyBackVal':decoded_data[3],
                         '_ratioBstTrade':decoded_data[4],
                         '_blockNumber':decoded_data[5]}
        
            [print(f'   {key}: {val}') for key,val in d_ret_log.items()]
            print()

    if _func_hash == _abi.ROUTERv2_FUNC_MAP_WRITE[_abi.ROUTERv2_FUNC_ADD_LIQ_ETH][0]:
        # Define & filter logs based on the event signature
        # PairCreated(address indexed token0, address indexed token1, address pair, uint256)
        event_signature = _w3.W3.keccak(text="PairCreated(address,address,address,uint256)").hex()
        pay_out_logs = [log for log in logs if log['topics'][0].hex() == event_signature]
        
        # Parse the event logs
        for log in pay_out_logs:
            lst_evt_params = ['address', 'address', 'address','uint256']
            evt_data = log['data']
            decoded_data = decode_abi(lst_evt_params, evt_data)
            d_ret_log = {'_token0':decoded_data[0],
                         '_token1':decoded_data[1],
                         '_pair':decoded_data[2],
                         '_param_3':decoded_data[3]}
        
            [print(f'   {key}: {val}') for key,val in d_ret_log.items()]
            print()

    if _func_hash == _abi.UniswapFlashQuery_FUNC_MAP_WRITE[_abi.UniswapFlashQuery_FUNC_MAP_getRervesByPairs][0]:
        # Define & filter logs based on the event signature
        # PairCreated(address indexed token0, address indexed token1, address pair, uint256)
        event_signature = _w3.W3.keccak(text="ReservesData(address,address,address,uint256,uint256,uint256,uint256,uint256)").hex()
        pay_out_logs = [log for log in logs if log['topics'][0].hex() == event_signature]
        
        # Parse the event logs
        for log in pay_out_logs:
            lst_evt_params = ['address','address','address','uint256','uint256','uint256','uint256','uint256']
            evt_data = log['data']
            decoded_data = decode_abi(lst_evt_params, evt_data)
            d_ret_log = {'_token0':decoded_data[0],
                         '_token1':decoded_data[1],
                         '_pair':decoded_data[2],
                         '_reserve0':decoded_data[3],
                         '_reserve1':decoded_data[4],
                         '_token0_in':decoded_data[5],
                         '_token1_in':decoded_data[6],
                         '_blocktimestamp':decoded_data[7]}
        
            [print(f'   {key}: {val}') for key,val in d_ret_log.items()]
            print()
            
    return d_ret_log
            
def read_with_hash(_contr_addr, _func_hash, _lst_param_types, _lst_params, _lst_ret_types):
    global W3_

    print('preparing function signature params ...')
    func_sign = _func_hash
    if len(_lst_param_types) > 0:
        func_sign = _func_hash + encode_abi(_lst_param_types, _lst_params).hex()

    print(f'building tx_data w/ ...\n _contr_addr: {_contr_addr}\n _func_hash: 0x{_func_hash}')
    tx_data = {
        "to": _contr_addr,
        "data": func_sign,
        "from": W3_.SENDER_ADDRESS,
    }

    # Call contract function to retrieve the value of the KEEPER state variable
    print(f'calling contract function _ {get_time_now()}')
    return_val = W3_.W3.eth.call(tx_data)
    print(f'calling contract function _ {get_time_now()} ... DONE')
    print('\nparsing & printing response ...')
    # print(f'return_val: {return_val}')
    # print(f'return_val.hex(): {return_val.hex()}')

    decoded_value_return = decode_abi(_lst_ret_types, return_val)
    try:
        print(json.dumps(decoded_value_return, indent=2))
    except Exception as e:
        print_except(e, debugLvl=DEBUG_LEVEL)

    hex_bytes = decoded_value_return[0]
    decoded_string = hex_bytes
    # print(f'decoded_string: {decoded_string}')

    if isinstance(hex_bytes, bytes):
        print('found bytes')
        bytes_value = bytes(hex_bytes) # Convert hex bytes to bytes
        decoded_string = bytes_value.decode('utf-8') # Decode bytes to string
    
    print(f'pretty print... cnt: {len(decoded_value_return)}')
    for i in range(len(decoded_value_return)):
        # if isinstance(decoded_value_return[i], str):
        if isinstance(decoded_value_return[i], int):
            # check for BST prod contract address
            dec = 6 if _contr_addr=='0x7A580b7Cd9B48Ba729b48B8deb9F4D2cb216aEBC' else 18
            f_val = float(decoded_value_return[i]) / 10 ** dec
            # f_val = float(decoded_value_return[i]) / 10 ** 18
            print(f' {f_val:,.3f}')
        elif isinstance(decoded_value_return[i], list):
            print(json.dumps(decoded_value_return[i], indent=2))
        else:
            print(decoded_value_return[i])
    
    if isinstance(decoded_value_return, list) and isinstance(decoded_value_return[0], list) :
        print(f'pretty print... cnt[0]: {len(decoded_value_return[0])}')

    # print(f'decoded_value_return', *decoded_value_return, sep='\n ')
    return decoded_string

def read_with_abi(_contr_addr, _func_hash, _lst_params):
    if _func_hash == _abi.BST_GET_ACCT_PAYOUTS_FUNC_HASH or _func_hash == _abi.LUSDst_GET_ACCT_PAYOUTS_FUNC_HASH:
        is_lusdst = _func_hash == _abi.LUSDst_GET_ACCT_PAYOUTS_FUNC_HASH
        bstPayout_type = "uint64"
        if is_lusdst: bstPayout_type = "uint256"
        print(f'building contract_abi for func_hash: "{_func_hash}" ...')
        # struct ACCT_PAYOUT {
        #     address receiver;
        #     uint64 usdAmntDebit; // USD total ACCT deduction
        #     uint64 usdPayout; // USD payout value
        #     uint64 bstPayout; // BST payout amount
        #     uint64 usdFeeVal; // USD service fee amount
        #     uint64 usdBurnValTot; // to USD value burned (BST + aux token)
        #     uint64 usdBurnVal; // BST burned in USD value
        #     uint256 auxUsdBurnVal; // aux token burned in USD val during payout
        #     address auxTok; // aux token burned during payout
        #     uint32 ratioBstPay; // rate at which BST was paid (1<:1 USD)
        #     uint256 blockNumber; // current block number of this payout
        # }
        contract_abi = [
            {
                "inputs": [{"internalType": "address", "name": "_account", "type": "address"}],
                "name": "getAccountPayouts",
                "outputs": [{"components": [
                    {"internalType": "address", "name": "receiver", "type": "address"},
                    {"internalType": "uint64", "name": "usdAmntDebit", "type": "uint64"},
                    {"internalType": "uint64", "name": "usdPayout", "type": "uint64"},
                    # {"internalType": "uint64", "name": "bstPayout", "type": "uint64"},
                    {"internalType": "uint64", "name": "bstPayout", "type": bstPayout_type},
                    {"internalType": "uint64", "name": "usdFeeVal", "type": "uint64"},
                    {"internalType": "uint64", "name": "usdBurnValTot", "type": "uint64"},
                    {"internalType": "uint64", "name": "usdBurnVal", "type": "uint64"},
                    {"internalType": "uint256", "name": "auxUsdBurnVal", "type": "uint256"},
                    {"internalType": "address", "name": "auxTok", "type": "address"},
                    {"internalType": "uint32", "name": "ratioBstPay", "type": "uint32"},
                    {"internalType": "uint256", "name": "blockNumber", "type": "uint256"}
                ], "internalType": "struct MyContract.ACCT_PAYOUT[]", "name": "", "type": "tuple[]"}],
                "stateMutability": "view",
                "type": "function"
            }
        ]
        print(f'building web3 contract w/ abi &\n  _contr_addr: {_contr_addr}')
        contract = W3_.W3.eth.contract(address=_contr_addr, abi=contract_abi)

        print(f'calling contract function _ {get_time_now()}')
        payouts = contract.functions.getAccountPayouts(_lst_params[0]).call()
        print(f'calling contract function _ {get_time_now()} ... DONE')

        print('\nparsing & printing response ...')
        for payout in payouts:
            print(" receiver:", payout[0])
            print(" usdAmntDebit:", float(payout[1]) / 10 ** 6)
            print(" usdPayout:", float(payout[2]) / 10 ** 6)
            print(" bstPayout:", float(payout[3]) / 10 ** (18 if is_lusdst else 6))
            print(" usdFeeVal:", float(payout[4]) / 10 ** 6)
            print(" usdBurnValTot:", float(payout[5]) / 10 ** 6)
            print(" usdBurnVal:", float(payout[6]) / 10 ** 6)
            print(" auxUsdBurnVal:", float(payout[7]) / 10 ** 6)
            print(" auxTok:", payout[8])
            print()
        return payouts

def go_user_inputs(_set_gas=True):
    global W3_, CONTRACT_ABI # REQUIRED (using assignment)
    W3_ = _web3.myWEB3().init_inp(_set_gas)
    
    # ABI_FILE, BIN_FILE = W3_.inp_sel_abi_bin(LST_CONTR_ABI_BIN) # returns .abi|bin
    # CONTRACT_ABI = W3_.read_abi_file(ABI_FILE)
    # CONTRACT_ABI = _abi.BST_ABI
    # print(' using CONTRACT_ABI = _abi.BST_ABI')

def go_input_contr_addr(_symb='nil_symb', _contr_addr=None):
    while _contr_addr == None or _contr_addr == '':
        _contr_addr = input(f'\n Enter {_symb} contract address:\n > ')

    _contr_addr = W3_.W3.to_checksum_address(_contr_addr)
    print(f'  using {_symb}_ADDRESS: {_contr_addr}')
    return _contr_addr

def go_select_func(_bst_func_map=None):
    print(f'\n Select function to invoke ...')
    lst_keys = list(_bst_func_map.keys())
    for i,k in enumerate(lst_keys):
        print(f'  {i} = {k}')
    ans_idx = input('  > ')
    assert ans_idx.isdigit() and int(ans_idx) >= 0 and int(ans_idx) < len(lst_keys), f'failed ... invalid input {ans_idx}'
    func_select = list(_bst_func_map.keys())[int(ans_idx)]
    ans = input(f'\n  Confirm func [y/n]: {func_select}\n  > ')
    lst_ans_go = ['y','yes','']
    if str(ans).lower() not in lst_ans_go: func_select = go_select_func()
    return func_select

def go_enter_func_params(_func_select):
    lst_func_params = []
    value_in_wei = 0
    ans = input(f'\n  Enter params for: "{_func_select}"\n  > ')
    for v in list(ans.split()):
        if v.lower() == 'true': lst_func_params.append(True)
        elif v.lower() == 'false': lst_func_params.append(False)
        elif v.isdigit(): lst_func_params.append(int(v))
        elif v.startswith('['):
            lst_str = [i.strip() for i in v[1:-1].split(',')]
            if lst_str[0][1:3] == '0x':
                # appned list of addresses
                lst_func_params.append([W3_.W3.to_checksum_address(i) for i in lst_str])
            elif lst_str[0].isdigit():
                # append list of ints                
                lst_func_params.append([int(i) for i in lst_str])
            else:
                # fall back to appending list of strings
                lst_func_params.append(lst_str)
        else: lst_func_params.append(v)

    # handle edge case: uniswap 'addLiquidityETH'
    if _func_select == _abi.ROUTERv2_FUNC_ADD_LIQ_ETH:
        print(f'\n  found edge case in "{_func_select}"')
        print(f'   inserting & appending additional params to lst_func_params ...\n')
        # lst_func_params[0] = 'token' -> input OG (static idx)
        # lst_func_params[1] = 'amountTokenDesired' -> input OG (static idx)
        # lst_func_params[2] = 'amountETHMin' -> input OG (dynamic idx)
        lst_func_params.insert(2, int(lst_func_params[1])) # insert 'amountTokenMin' into idx #2 (push 'amountETHMin' to #3)
        lst_func_params[3] = W3_.Web3.to_wei(int(float(lst_func_params[3])), 'ether') # update idx #3 'amountETHMin'
        lst_func_params.append(W3_.SENDER_ADDRESS) # append idx #4 -> 'to' 
        lst_func_params.append(int(time.time()) + 3600) # append idx #5 -> 'deadline' == now + 3600 seconds = 1 hour from now

        value_in_wei = lst_func_params[3] # get return value in wei (for write_with_hash)

    print(f'  executing "{_func_select}" w/ params: {lst_func_params} ...\n')
    return lst_func_params, value_in_wei

# def gen_random_wallets(_wallet_cnt, _gen_new=True):
#     if not _gen_new:
#         # return env.RAND_WALLETS, env.RAND_WALLET_CLI_INPUT
#         # return env.RAND_WALLETS_20, env.RAND_WALLET_CLI_INPUT_20
#         return env.RAND_WALLETS_10, env.RAND_WALLET_CLI_INPUT_10
#     else:
#         lst_rand_wallets = []
#         lst_wallet_addr = []
#         for acct_num in range(0,_wallet_cnt): # generate '_wallet_cnt' number of wallets
#             d_wallet = _gen_pls_key.gen_pls_key(str("english"), int(256), acct_num, False) # language, entropyStrength, num, _plog
#             lst_rand_wallets.append(dict(d_wallet))
#             lst_wallet_addr.append(d_wallet['address'])

#         # pprint.pprint(lst_rand_wallets)
#         file_cnt = len(os.listdir('./_wallets'))
#         with open(f"./_wallets/wallets_{file_cnt}_{get_time_now()}.txt", "w") as file:
#             pprint.pprint(lst_rand_wallets, stream=file)
#             pprint.pprint(lst_rand_wallets)

#         # generate formatted string for CLI input
#         str_rand_wallet_cli_input = '[' + ','.join(map(str, lst_wallet_addr)) + ']'
#         return lst_rand_wallets, str_rand_wallet_cli_input

def go_select_contract(_is_write=False):
    # list contract abi's from _abi.py
    lst_contr_select = ['CALLIT++']
    lst_abi_read = [_abi.CALLIT_FUNC_MAP_READ]
    lst_abi_write = [_abi.CALLIT_FUNC_MAP_WRITE]
    
    str_inp = "\n Select contract func list to use ..."
    for i,v in enumerate(lst_contr_select):
        str_inp += f"\n {i} = '{v}'"
    str_inp += f"\n > "
    ans = input(str_inp)
    assert int(ans) >= 0 and int(ans) < len(lst_contr_select), ' err: go_select_contract\n die ... \n\n'
    symb = lst_contr_select[int(ans)]
    contr_func_map = lst_abi_write[int(ans)] if _is_write else lst_abi_read[int(ans)]
    opt_sel_str = f"opt_sel={ans}"
    print(f' ans: "{ans}"; {opt_sel_str}, set contr_func_map')
    return symb, contr_func_map, opt_sel_str

# # _gen_new=False = use _abi.RAND_WALLETS & _abi.RAND_WALLET_CLI_INPUT
# def go_gen_addies(_enable=False, _gen_new=False): 
#     if not _enable: return

#     # check to show or generate new wallets
#     s = 'Generate new' if _gen_new else 'Show old'
#     ans = input(f"\n{s} random wallets? [y/n]\n > ")
#     if ans.lower()=='y' or ans == '1':
#         # NOTE: gen/fetch/print CLI input string needed to 
#         #   manually feed into 'KEEPER_mixAmntRand' & 'distrAmntRand'
#         wallet_cnt = 10
        
#         print(f' fetching {wallet_cnt} random wallets (_gen_new={_gen_new}) ...')
#         lst_rand_wallets, str_rand_wallet_cli_input = gen_random_wallets(wallet_cnt, _gen_new)
#         print(f' fetching {len(lst_rand_wallets)} random wallets (_gen_new={_gen_new}) ... DONE')
#         print(f' ... fetched wallets CLI input ...\n {str_rand_wallet_cli_input}')  # This will print the formatted string    

#         ## end ##
#         if _gen_new:
#             print(f'\n\nRUN_TIME_START: {RUN_TIME_START}\nRUN_TIME_END:   {get_time_now()}\n')
#             exit()

def go_select_read_write():
    # read requests: _set_gas=False
    ans = input("Start 'write' or 'read' request?\n 0 = write\n 1 = read\n > ")
    is_write = ans=='0'
    print(f' ans: "{ans}"; is_write={is_write}')
    return is_write

#------------------------------------------------------------#
#   DEFAULT SUPPORT                                          #
#------------------------------------------------------------#
READ_ME = f'''
    *DESCRIPTION*
        invoke any contract functions
         utilizes function hashes instead of contract ABI

    *NOTE* INPUT PARAMS...
        nil
        
    *EXAMPLE EXECUTION*
        $ python3 {__filename} -<nil> <nil>
        $ python3 {__filename}
'''

#ref: https://stackoverflow.com/a/1278740/2298002
def print_except(e, debugLvl=0):
    #print(type(e), e.args, e)
    if debugLvl >= 0:
        print('', cStrDivider, f' Exception Caught _ e: {e}', cStrDivider, sep='\n')
    if debugLvl >= 1:
        print('', cStrDivider, f' Exception Caught _ type(e): {type(e)}', cStrDivider, sep='\n')
    if debugLvl >= 2:
        print('', cStrDivider, f' Exception Caught _ e.args: {e.args}', cStrDivider, sep='\n')
    if debugLvl >= 3:
        exc_type, exc_obj, exc_tb = sys.exc_info()
        fname = os.path.split(exc_tb.tb_frame.f_code.co_filename)[1]
        strTrace = traceback.format_exc()
        print('', cStrDivider, f' type: {exc_type}', f' file: {fname}', f' line_no: {exc_tb.tb_lineno}', f' traceback: {strTrace}', cStrDivider, sep='\n')

def wait_sleep(wait_sec : int, b_print=True, bp_one_line=True): # sleep 'wait_sec'
    print(f'waiting... {wait_sec} sec')
    for s in range(wait_sec, 0, -1):
        if b_print and bp_one_line: print(wait_sec-s+1, end=' ', flush=True)
        if b_print and not bp_one_line: print('wait ', s, sep='', end='\n')
        time.sleep(1)
    if bp_one_line and b_print: print() # line break if needed
    print(f'waiting... {wait_sec} sec _ DONE')

def get_time_now(dt=True):
    if dt: return '['+datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[0:-4]+']'
    return '['+datetime.now().strftime("%H:%M:%S.%f")[0:-4]+']'

def read_cli_args():
    print(f'\nread_cli_args...\n # of args: {len(sys.argv)}\n argv lst: {str(sys.argv)}')
    for idx, val in enumerate(sys.argv): print(f' argv[{idx}]: {val}')
    print('read_cli_args _ DONE\n')
    return sys.argv, len(sys.argv)

if __name__ == "__main__":
    ## start ##
    RUN_TIME_START = get_time_now()
    print(f'\n\nRUN_TIME_START: {RUN_TIME_START}\n'+READ_ME)
    lst_argv_OG, argv_cnt = read_cli_args()

    ## exe ##
    try:
        # go_gen_addies(_enable=False, _gen_new=False)
        is_write = go_select_read_write() # read requests -> _set_gas=False
        go_user_inputs(_set_gas=is_write) # select chain, sender, gas (init web3)
        symb, contr_func_map, opt_sel_str = go_select_contract(_is_write=is_write)
        contr_address = go_input_contr_addr(symb)
        
        print('\n Begin function select loop ...')
        while True: # continue function selection progression until killed
            print('', cStrDivider_1, f"here we go! _ is_write={is_write} _ (to exit use: ctl+c) _ {get_time_now()}", sep='\n')
            func_select = go_select_func(contr_func_map)
            lst_func_params, value_in_wei = go_enter_func_params(func_select)
            lst_params = list(contr_func_map[func_select])
            lst_params.insert(2, lst_func_params)
            tup_params = (contr_address,lst_params[0],lst_params[1],lst_params[2],lst_params[3])
            try:
                if not is_write:
                    if lst_params[0] == _abi.BST_GET_ACCT_PAYOUTS_FUNC_HASH:
                        read_with_abi(contr_address, lst_params[0], lst_params[2])
                    else:
                        read_with_hash(*tup_params)
                else:
                    tup_params = tup_params + (value_in_wei,)
                    write_with_hash(*tup_params)
            except Exception as e:
                print_except(e, debugLvl=DEBUG_LEVEL)
            print(f'\n{symb}_ADDRESS: {contr_address}\nSENDER_ADDRESS: {W3_.SENDER_ADDRESS}\n func_select: {func_select}')

    except Exception as e:
        print_except(e, debugLvl=DEBUG_LEVEL)
    
    ## end ##
    print(f'\n\nRUN_TIME_START: {RUN_TIME_START}\nRUN_TIME_END:   {get_time_now()}\n')

print('', cStrDivider, f'# END _ {__filename}', cStrDivider, sep='\n')


# latest deployments...
# SwapDelegate_5: 0xA8d96d0c328dEc068Db7A7Ba6BFCdd30DCe7C254
# tLUSDst_0.1: 0xcBbbf66f27E128943436be8CF677bcd06a0C59dD
# tLUSDst_0.2: 0xB2165De24a2E8C19f3081Fe15bBf09f815942B75
# tLUSDst_0.3: 0x6C7F2CDB8a499D637f62022448258014e6dEC499
# tLUSDst_0.4: 0x014D7caE54F7fDd22eBac48C049F64271b84c8b4
# tLUSDst_1.1: 0x9e68d69bddf821a0ecb4f993c6430c3ecbae69fb
# AtropaMV_0.2: 0xb5d27e5f72A2c865674d54068176DA42140ED85A

