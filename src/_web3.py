__fname = '_web3' # GTA_032224
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

from web3 import Account, Web3, HTTPProvider
# from web3.middleware import geth_poa_middleware
from datetime import datetime
from _env import env
import sys, os, traceback, time, pprint
from attributedict.collections import AttributeDict # tx_receipt requirement

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


def get_time_now(dt=True):
    if dt: return '['+datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[0:-4]+']'
    return '['+datetime.now().strftime("%H:%M:%S.%f")[0:-4]+']'

class myWEB3:
    def __init__(self):
        self.Web3 = Web3
        # self.geth_poa_middleware = geth_poa_middleware
        self.rpc_req_timeout = 60 # *tested_111523: 10=50s,30=150s,45=225s,60=300s
        self.RPC_URL = None
        self.CHAIN_ID = None
        self.CHAIN_SEL = None
        self.SENDER_ADDRESS = None
        self.SENDER_SECRET = None
        self.W3 = None
        self.ACCOUNT = None

        self.LST_CONTRACTS = []

        self.GAS_LIMIT = None
        self.GAS_PRICE = None
        self.MAX_FEE = None
        self.MAX_PRIOR_FEE_RATIO = None
        self.MAX_PRIOR_FEE = None

        self.GTA_CONTRACT = None
        self.GTA_CONTRACT_ADDR = None
    def check_mempool(self, rpc_url):
        # rpc_url, chain_id, chain_sel    = self.inp_sel_chain()
        import requests, json
        response = requests.post(
            rpc_url,
            json={"jsonrpc": "2.0", "method": "txpool_content", "params": [], "id": 1}
        )

        # Parse the response
        tx_pool = response.json()['result']
        return tx_pool
        # return json.dumps(tx_pool, indent=4)

    def init_web3(self, with_sender=True, empty=False):
        if empty: 
            self.W3 = Web3()
            return self.W3, None
        
        print(f'''\nINITIALIZING web3 ...
        RPC: {self.RPC_URL} _ w/ timeout: {self.rpc_req_timeout}
        ChainID: {self.CHAIN_ID}
        SENDER: {self.SENDER_ADDRESS}
        CONTRACTS: {self.LST_CONTRACTS}''')

        self.W3 = Web3(HTTPProvider(self.RPC_URL, request_kwargs={'timeout': self.rpc_req_timeout}))
        #self.W3.middleware_stack.inject(geth_poa_middleware, layer=0) # chatGPT: for PoA chains; for gas or something
        if with_sender: self.ACCOUNT = Account.from_key(self.SENDER_SECRET)
        return self.W3, self.ACCOUNT
    
    def init_nat(self, _chain_sel, _sender_addr, sender_secret, default_gas=False):
        rpc_url, chain_id, chain_sel    = self.set_chain(_chain_sel)
        sender_address, sender_secret   = self.set_sender(_sender_addr, sender_secret)
        w3, account                     = self.init_web3()

        self.print_curr_chain_gas_price()
        if default_gas: self.set_gas_params(w3)
        return self
    
    def init_inp(self, _set_gas=True):
        rpc_url, chain_id, chain_sel    = self.inp_sel_chain()
        sender_address, sender_secret   = self.inp_sel_sender()
        w3, account                     = self.init_web3()
        if _set_gas: gas_tup            = self.get_gas_settings(w3)
        self.kill_nonce_attempt(account, w3) # clean mempool lock attempt
        return self

    def set_chain(self, _chain_sel):
        self.CHAIN_SEL = _chain_sel
        assert 0 <= int(self.CHAIN_SEL) <= 1, 'Invalid entry, abort'
        self.RPC_URL, self.CHAIN_ID = (env.eth_main, env.eth_main_cid) if int(self.CHAIN_SEL) == 0 else (env.pc_main, env.pc_main_cid)
        print(f'  set chain: {(self.RPC_URL, self.CHAIN_ID)}')
        return self.RPC_URL, self.CHAIN_ID, self.CHAIN_SEL

    def set_sender(self, _sender_addr, _sender_sercret):
        self.SENDER_ADDRESS = _sender_addr
        self.SENDER_SECRET = _sender_sercret
        print(f'  set sender: {self.SENDER_ADDRESS}')
        return self.SENDER_ADDRESS, self.SENDER_SECRET
    
    def inp_sel_abi_bin(self, _lst_abi_bin=[], str_input='Select abi|bin file path:'):
        print('\n', str_input)
        for i, v in enumerate(_lst_abi_bin): print(' ',i,'=',f'{v} _ {self.get_file_dt(v+".bin")}') # parse through tuple
        # for i, v in enumerate(_lst_abi_bin): print(' ',i,'=',v) # parse through tuple
        idx = input('  > ')
        assert 0 <= int(idx) < len(_lst_abi_bin), 'Invalid input, aborting...\n'
        abi_bin = str(_lst_abi_bin[int(idx)]) # get selected index
        print(f'  selected abi|bin: {abi_bin}')
        return abi_bin+'.abi', abi_bin+'.bin'

    def add_contract_deploy(self, _abi_file, _bin_file):
        assert self.W3 != None, 'err: web3 not initialzed'
        contr_abi, contr_bytes  = self.read_abi_bytecode(_abi_file, _bin_file)
        contract                = self.init_contract_bin(contr_abi, contr_bytes, self.W3)
        return contract

    def add_contract_GTA(self, dict_contr):
        assert self.W3 != None, 'err: web3 not initialzed'
        contr_addr              = self.inp_sel_contract([(k,v['symb']) for k,v in dict_contr.items()], str_input='Select GTA contract:')
        contr_abi, contr_bytes  = self.read_abi_bytecode(dict_contr[contr_addr]['abi_file'], dict_contr[contr_addr]['bin_file'])
        contract, contr_addr    = self.init_contract(contr_addr, contr_abi, self.W3)
        self.GTA_CONTRACT = contract
        self.GTA_CONTRACT_ADDR = contr_addr

    def add_contract(self, dict_contr):
        assert self.W3 != None, 'err: web3 not initialzed'
        contr_addr              = self.inp_sel_contract([(k,v['symb']) for k,v in dict_contr.items()], str_input='Select alt to add:')
        contr_abi, contr_bytes  = self.read_abi_bytecode(dict_contr[contr_addr]['abi_file'], dict_contr[contr_addr]['bin_file'])
        contract, contr_addr    = self.init_contract(contr_addr, contr_abi, self.W3)
        self.LST_CONTRACTS.append((contract, contr_addr))

    def inp_sel_chain(self):
        self.CHAIN_SEL = input('\n Select chain:\n  0 = ethereum mainnet\n  1 = pulsechain mainnet\n  > ')
        assert 0 <= int(self.CHAIN_SEL) <= 1, 'Invalid entry, abort'
        self.RPC_URL, self.CHAIN_ID = (env.eth_main, env.eth_main_cid) if int(self.CHAIN_SEL) == 0 else (env.pc_main, env.pc_main_cid)
        print(f'  selected {(self.RPC_URL, self.CHAIN_ID)}')
        return self.RPC_URL, self.CHAIN_ID, self.CHAIN_SEL

    def inp_sel_sender(self):
        sel_send = input(f'\n Select sender: (_event_listener: n/a)\n  0 = {env.sender_address_3}\n  1 = {env.sender_address_1}\n  > ')
        assert 0 <= int(sel_send) <= 1, 'Invalid entry, abort'
        self.SENDER_ADDRESS, self.SENDER_SECRET = (env.sender_address_3, env.sender_secret_3) if int(sel_send) == 0 else (env.sender_address_1, env.sender_secret_1)
        print(f'  selected {self.SENDER_ADDRESS}')
        return self.SENDER_ADDRESS, self.SENDER_SECRET
    
    def kill_nonce_attempt(self, account:Account, w3:Web3): # clean mempool lock attempt
        inp_go = input("\n Execute nonce kill attempt? [y/n]\n > ")
        if inp_go.lower() != 'y' and inp_go != '1':
            print(' nonce kill denied\n')
            return
        
        # Set the transaction parameters
        tx_nonce = w3.eth.get_transaction_count(account.address)
        tx_params = {
            # 'to': account.address,  # Sending to yourself
            # 'to': "0x26c7C431534b4E6b2bF1b9ebc5201bEf2f8477F5",  # Sending to vault
            'to': "0x86726f5a4525D83a5dd136744A844B14Eb0f880c",  # Sending to factory
            'value': w3.to_wei(3000, 'ether'),  # Sending 1 ETH
            'nonce': tx_nonce,  # Get the nonce
            'chainId': self.CHAIN_ID  # Mainnet (1), Rinkeby (4), PulseChain (369), etc.
        }
        
        # append gas params
        lst_gas_params = [{'gas':self.GAS_LIMIT}, {'maxFeePerGas': self.MAX_FEE}, {'maxPriorityFeePerGas': self.MAX_PRIOR_FEE}]
        for d in lst_gas_params: tx_params.update(d)

        print(f'built tx w/ NONCE: {tx_nonce} ...')
        print(f'signing and sending tx ... {get_time_now()}')
        # Sign & send the transaction
        signed_tx = account.sign_transaction(tx_params)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)

        # Get the transaction hash
        print(cStrDivider_1, f'waiting for receipt ... {get_time_now()}', sep='\n')
        print(f'    tx_hash: {tx_hash.hex()}')

        # Optionally, wait for the transaction to be mined
        # Wait for the transaction to be mined
        wait_time = 300 # sec
        try:
            tx_receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=wait_time)
            print("Transaction confirmed in block:", tx_receipt.blockNumber, f' ... {get_time_now()}')
        except Exception as e:
            print(f"\n{get_time_now()}\n Transaction not confirmed within the specified timeout... wait_time: {wait_time}")
            print_except(e)
            exit(1)

        # print incoming tx receipt (requires pprint & AttributeDict)
        tx_receipt = AttributeDict(tx_receipt) # import required
        tx_rc_print = pprint.PrettyPrinter().pformat(tx_receipt)
        print(cStrDivider_1, f'RECEIPT:\n {tx_rc_print}', sep='\n')
        print(cStrDivider_1, f"\n\n Contract deployed at address: {tx_receipt['contractAddress']}\n\n", sep='\n')
        
        print(f"Transaction receipt: {tx_receipt}")
        print(cStrDivider_1, cStrDivider_1, sep='\n')

    def set_gas_params(self, w3, _gas_limit=6_000_000, _fee_perc_markup=0.55):
        print(f' setting default gas params ... (w/ fee % markup: {_fee_perc_markup})')
        if int(self.CHAIN_SEL) == 0:
            self.GAS_LIMIT = 3_000_000
            self.GAS_PRICE = w3.to_wei('10', 'gwei')
            self.MAX_FEE = w3.to_wei('14', 'gwei')
            self.MAX_PRIOR_FEE_RATIO = 1.0
            self.MAX_PRIOR_FEE = int(w3.eth.max_priority_fee * self.MAX_PRIOR_FEE_RATIO)
        else:
            wei, gwei, eth = self.get_curr_gas_price()
            self.GAS_PRICE = w3.to_wei('0.0005', 'ether') # 'gasPrice' param fails on PC
            self.GAS_LIMIT = _gas_limit
            # self.MAX_FEE = w3.to_wei('350_000', 'gwei')
            self.MAX_FEE = int(wei + (wei * _fee_perc_markup)) # dafault to current gas price + _fee_perc_markup
            self.MAX_PRIOR_FEE_RATIO = 0.99
            self.MAX_PRIOR_FEE = int(self.MAX_FEE * self.MAX_PRIOR_FEE_RATIO) 
            # self.MAX_PRIOR_FEE = int(w3.eth.max_priority_fee * self.MAX_PRIOR_FEE_RATIO) 
                # NOTE: MAX_PRIOR_FEE_RATIO = 4000.0, results in MAX_PRIOR_FEE = 2_000_000 beat
                #   HENCE, w3.eth.max_priority_fee == 500 BEAT (always i guess?)
                
        self.print_gas_params()

    def get_gas_settings(self, w3):
        print('\nGAS SETTINGS ...')
        self.set_gas_params(w3)        
        sel_ans = '1'
        while sel_ans != '0':
            # self.print_gas_params()
            sel_ans = input("\n Verifiy Gas Settings:\n  0 = use current params\n  1 = set new params (format: xxxx | x_xxx)\n  > ")
            if sel_ans == '1':
                self.GAS_LIMIT = int(input("\n Enter GAS_LIMIT (max gas units):\n  > "))
                inp_fee = input("\n Enter MAX_FEE (max price per unit in gwei|beat):\n  > ")
                self.MAX_FEE = w3.to_wei(inp_fee, 'gwei')
            self.print_gas_params()

        return self.GAS_LIMIT, self.GAS_PRICE, self.MAX_FEE, self.MAX_PRIOR_FEE_RATIO, self.MAX_PRIOR_FEE
    
    def print_curr_chain_gas_price(self):
        wei, gwei, eth = self.get_curr_gas_price()
        print(f'''\n Current ON-CHAIN_GAS_PRICE: {gwei:,} beat (per unit) == {eth:.5f} PLS''')
    
    def get_curr_gas_price(self):
        w3 = self.W3
        wei = w3.eth.gas_price
        gwei = round(w3.from_wei(wei, 'gwei'), 0)
        eth = w3.from_wei(wei, 'ether')
        return wei, gwei, eth
    
    def print_gas_params(self):
        w3 = self.W3
        wei_bal = w3.eth.get_balance(self.SENDER_ADDRESS) if self.SENDER_ADDRESS else 0
        pls_bal = w3.from_wei(wei_bal, 'ether')
        print(f'''\n Current gas params ...
        ON-CHAIN_GAS_PRICE: {round(w3.from_wei(w3.eth.gas_price, 'gwei'), 0):,} beat (per unit) == {w3.from_wei(w3.eth.gas_price, 'ether'):.5f} PLS

        GAS_PRICE: {self.GAS_PRICE:,} wei (price per unit to pay; fails on PC)
        GAS_LIMIT: {self.GAS_LIMIT:,} units (amount of gas to use)
        MAX_FEE: {w3.from_wei(self.MAX_FEE, 'gwei'):,} beats (max price per unit) == {self.MAX_FEE:,} wei
        MAX_PRIOR_FEE: {w3.from_wei(self.MAX_PRIOR_FEE, 'gwei'):,} beats == {self.MAX_PRIOR_FEE:,} wei        
            *WARNING* ensure MAX_FEE >= MAX_PRIOR_FEE, or TX & EOA may lock in mempool
            
        REQUIRED_BALANCE: {self.calc_req_bal(self.MAX_FEE, self.GAS_LIMIT)} PLS
            (for {self.GAS_LIMIT:,} gas units)

        CURRENT_BALANCE: {pls_bal:,.3f} PLS
            (in wallet address: {self.SENDER_ADDRESS}) ''')

    def calc_req_bal(self, wei_amnt, gas_amnt):
        w = wei_amnt * gas_amnt
        e = self.W3.from_wei(w, 'ether')
        return f"{e:,}"
    
    def inp_sel_contract(self, _lst_contr_addr=[], str_input='Select contract to add:'):
        print('\n', str_input)
        for i, v in enumerate(_lst_contr_addr): print(' ',i,'=',v[0],v[1]) # parse through tuple
        idx = input('  > ')
        assert 0 <= int(idx) < len(_lst_contr_addr), 'Invalid input, aborting...\n'
        contr_addr = str(_lst_contr_addr[int(idx)][0]) # parse through tuple
        print(f'  selected {contr_addr}')
        return contr_addr
    
    def read_abi_file(self, abi_file):
        print(f'\nreading contract abi file ...\n   {abi_file}')
        with open(abi_file, "r") as file: contr_abi = file.read()
        return contr_abi
        
    def read_abi_bytecode(self, abi_file, bin_file):
        print(f'\nreading contract abi & bytecode files ...\n   {abi_file, bin_file}')
        with open(bin_file, "r") as file: contr_bytes = '0x'+file.read()
        with open(abi_file, "r") as file: contr_abi = file.read()
        return contr_abi, contr_bytes
    
    def init_contract(self, contr_addr, contr_abi, w3):
        print(f'\ninitializing contract {contr_addr} ...')
        contr_addr = w3.to_checksum_address(contr_addr)
        contract = w3.eth.contract(address=contr_addr, abi=contr_abi)
        return contract, contr_addr
    
    def init_contract_bin(self, contr_abi, contr_bin, w3):
        print(f'\ninitializing contract bytecode for deploy ...')
        contract = w3.eth.contract(abi=contr_abi, bytecode=contr_bin)
        return contract
    
    def get_file_dt(self, file_path, both=False):
        if not os.path.exists(file_path): return "file does not exist"
        ts = datetime.fromtimestamp(os.path.getctime(file_path))
        # return ts.strftime("%Y-%m-%d %H:%M:%S.%s", time.localtime(ts))
        return ts.strftime("%Y-%m-%d %H:%M:%S")
        return datetime.datetime.fromtimestamp(os.path.getctime(file_path))
        # Convert creation time and modification time to datetime objects
        dt_ctime = datetime.datetime.fromtimestamp(os.path.getctime(file_path))
        # dt_mtime = datetime.datetime.fromtimestamp(os.path.getmtime(file_path))
        return dt_ctime

        # Print the file info
        print(f"File: {file_path}")
        print(f"Creation Time: {creation_time_dt}")
        print(f"Modification Time: {modification_time_dt}")
# #------------------------------------------------------------#
# def inp_CHAIN_SEL():
#     CHAIN_SEL = input('\nSelect chain:\n  0 = ethereum mainnet\n  1 = pulsechain mainnet\n  > ')
#     assert 0 <= int(CHAIN_SEL) <= 1, 'Invalid entry, abort'
#     (RPC_URL, CHAIN_ID) = (env.eth_main, env.eth_main_cid) if int(CHAIN_SEL) == 0 else (env.pc_main, env.pc_main_cid)
#     print(f'  selected {(RPC_URL, CHAIN_ID)}')
#     return RPC_URL, CHAIN_ID, CHAIN_SEL
# #------------------------------------------------------------#
# def inp_sel_sender():
#     sel_send = input(f'\nSelect sender: (_event_listener: n/a)\n  0 = {env.sender_address_3}\n  1 = {env.sender_address_1}\n  > ')
#     assert 0 <= int(sel_send) <= 1, 'Invalid entry, abort'
#     (SENDER_ADDRESS, SENDER_SECRET) = (env.sender_address_3, env.sender_secret_3) if int(sel_send) == 0 else (env.sender_address_1, env.sender_secret_1)
#     print(f'  selected {SENDER_ADDRESS}')
#     return SENDER_ADDRESS, SENDER_SECRET
# #------------------------------------------------------------#
# def inp_sel_contract(LST_CONTR_ADDR=[]):
#     print(f'\nSelect arbitrage contract to use:')
#     for i, v in enumerate(LST_CONTR_ADDR): print(' ',i, '=', v)
#     idx = input('  > ')
#     assert 0 <= int(idx) < len(LST_CONTR_ADDR), 'Invalid input, aborting...\n'
#     CONTR_ADDR = str(LST_CONTR_ADDR[int(idx)])
#     print(f'  selected {CONTR_ADDR}')
#     return CONTR_ADDR
# #------------------------------------------------------------#
# def init_web3(RPC_URL, CHAIN_ID, SENDER_ADDRESS, SENDER_SECRET, CONTR_ADDR='nil_contract'):
#     print(f'''\nINITIALIZING web3 ...
#         RPC: {RPC_URL}
#         ChainID: {CHAIN_ID}
#         SENDER: {SENDER_ADDRESS}
#         CONTRACT: {CONTR_ADDR}''')
        
#     ## CLIENT SIDE TIMEOUT RESULTS *tested_111523: 10=50s,30=150s,45=225s,60=300s
#     # RAISES: requests.exceptions.ReadTimeout: HTTPSConnectionPool(host='rpc.pulsechain.com', port=443): Read timed out. (read timeout=X)
#     # W3 = Web3(HTTPProvider(RPC_URL)) # 50sec timeout logged _ defaults to 'timeout': 10
#     # W3 = Web3(HTTPProvider(RPC_URL, request_kwargs={'timeout': 10})) # 50sec timeout logged
#     # W3 = Web3(HTTPProvider(RPC_URL, request_kwargs={'timeout': 30})) # 150sec (2.5min) timeout logged
#     # W3 = Web3(HTTPProvider(RPC_URL, request_kwargs={'timeout': 45})) # 225sec (3.75min) timeout logged
#     W3 = Web3(HTTPProvider(RPC_URL, request_kwargs={'timeout': 60})) # 5min timeout logged

#     ## SERVER SIDE TIMEOUT RESULTS
#     # RAISES: 504 Server Error: Gateway Time-out
#     # W3 = Web3(HTTPProvider(RPC_URL, request_kwargs={'timeout': 65})) # 5min timeout logged
#     # W3 = Web3(HTTPProvider(RPC_URL, request_kwargs={'timeout': 90})) # 5min timeout logged
#     # W3 = Web3(HTTPProvider(RPC_URL, request_kwargs={'timeout': 120})) # 5min timeout logged

#     # W3 = Web3(Web3.HTTPProvider(endpoint_uri=RPC_URL, request_kwargs={'timeout': 70}))
#     ACCOUNT = Account.from_key(SENDER_SECRET) # default
#     return W3, ACCOUNT
# #------------------------------------------------------------#
# def read_abi_bytecode(abi_file, bin_file):
#     print(f'\nreading contract abi & bytecode files ...\n   {abi_file, bin_file}')
#     with open(bin_file, "r") as file: CONTR_BYTES = '0x'+file.read()
#     with open(abi_file, "r") as file: CONTR_ABI = file.read()
#     return CONTR_ABI, CONTR_BYTES
# #------------------------------------------------------------#
# def init_contract(CONTR_ADDR, CONTR_ABI, W3:Web3):
#     print(f'\ninitializing contract {CONTR_ADDR} ...')
#     CONTR_ADDR = W3.to_checksum_address(CONTR_ADDR) # convert something ?
#     CONTRACT = W3.eth.contract(address=CONTR_ADDR, abi=CONTR_ABI)
#     return CONTRACT
# #------------------------------------------------------------#
# def get_gas_settings(CHAIN_SEL, W3:Web3):
#     print('calc gas settings...')
#     if int(CHAIN_SEL) == 0:
#         # ethereum main net (update_102923)
#         GAS_LIMIT = 3_000_000# max gas units to use for tx (required)
#         GAS_PRICE = W3.to_wei('10', 'gwei') # price to pay for each unit of gas (optional?)
#         MAX_FEE = W3.to_wei('14', 'gwei') # max fee per gas unit to pay (optional?)
#         MAX_PRIOR_FEE_RATIO = 1.0 # W3.eth.max_priority_fee * mpf_ratio # max fee per gas unit to pay for priority (faster) (optional)
#         MAX_PRIOR_FEE = int(W3.eth.max_priority_fee * MAX_PRIOR_FEE_RATIO) # max fee per gas unit to pay for priority (faster) (optional)
#     else:
#         # pulsechain main net (update_103123)
#         GAS_LIMIT = 20_000_000 # max gas units to use for tx (required)
#         GAS_PRICE = W3.to_wei('0.0005', 'ether') # price to pay for each unit of gas ('gasPrice' param fails on PC)
#         MAX_FEE = W3.to_wei('0.001', 'ether') # max fee per gas unit to pay (optional?)
#         MAX_PRIOR_FEE_RATIO = 1.0
#         MAX_PRIOR_FEE = int(W3.eth.max_priority_fee * MAX_PRIOR_FEE_RATIO) # max fee per gas unit to pay for priority (faster) (optional)

#     print(f'''\nSetting gas params ...
#         GAS_LIMIT: {GAS_LIMIT}
#         GAS_PRICE: {GAS_PRICE} *'gasPrice' param fails on PC
#         MAX_FEE: {MAX_FEE} ({MAX_FEE / 10**18} wei)
#         MAX_PRIOR_FEE: {MAX_PRIOR_FEE}''')
    
#     return GAS_LIMIT, GAS_PRICE, MAX_FEE, MAX_PRIOR_FEE_RATIO, MAX_PRIOR_FEE
# #------------------------------------------------------------#
# #------------------------------------------------------------#