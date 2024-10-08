__fname = '_gen_func_hashes' # ported from '_deploye_contract.py' (090724)
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

import json, sys
import _web3 # from web3 import Account, Web3, HTTPProvider
from datetime import datetime
DEBUG_LEVEL = 0
w3 = None
W3_ = None
ABI_FILE = None
BIN_FILE = None
CONTRACT = None
LST_CONTR_ABI_BIN = [
    # "../bin/contracts/CallitTicket", # deployed from CallitConfig
    "../bin/contracts/CallitLib",
    "../bin/contracts/CallitVault",
    "../bin/contracts/CallitDelegate",
    "../bin/contracts/CallitToken",
    "../bin/contracts/CallitFactory",
    "../bin/contracts/CallitVoter",
    "../bin/contracts/CallitMarket",
    "../bin/contracts/CallitConfig",
]

# Function to calculate the selector from a function signature
def get_function_selector(function_signature):
    # Calculate the keccak256 (SHA-3) hash of the function signature
    function_selector = w3.keccak(text=function_signature).hex()[:10]  # First 4 bytes
    return function_selector

# Load the ABI from a JSON file
def load_abi(file_path):
    with open(file_path, 'r') as abi_file:
        abi = json.load(abi_file)
    return abi

def init_web3():
    global w3, W3_, ABI_FILE, BIN_FILE, CONTRACT
    # init W3_, user select abi to deploy, generate contract & deploy
    W3_ = _web3.myWEB3().init_inp(_set_gas=False, _kill_nonce=False)
    w3 = W3_.W3
    ABI_FILE, BIN_FILE, idx_contr = W3_.inp_sel_abi_bin(LST_CONTR_ABI_BIN) # returns .abi|bin
    # CONTRACT = W3_.add_contract_deploy(ABI_FILE, BIN_FILE)
    contr_name = LST_CONTR_ABI_BIN[idx_contr].split('/')[-1]
    return contr_name


# Extract function signatures, input types, and return types from the ABI
def extract_function_details(abi):
    function_details = {}
    for item in abi:
        if item['type'] == 'function':
            # Create the function signature (e.g., "transfer(address,uint256)")
            inputs = ','.join([input['type'] for input in item['inputs']])
            function_signature = f"{item['name']}({inputs})"
            
            # Extract input types
            input_types = [input['type'] for input in item['inputs']]
            
            # Extract return types
            return_types = [output['type'] for output in item['outputs']]
            
            # Calculate function selector
            selector = get_function_selector(function_signature)
            
            function_details[function_signature] = [selector, input_types, return_types]
    
    return function_details

# Print function details in the desired format
def get_function_details(abi_file_path, _contr_name="nil_contr_name"):
    abi = load_abi(abi_file_path)
    function_details = extract_function_details(abi)
    lst_form_abi = []
    lst_form_print = []
    for function_signature, details in function_details.items():
        selector, input_types, return_types = details
        formatted_string = f'   "{function_signature}": ["{selector}", {input_types}, {return_types}],'
        formatted_print = f'    "{selector}": "{function_signature}" -> "{return_types}",'
        lst_form_abi.append(formatted_string)
        lst_form_print.append(formatted_print)

    return lst_form_abi, lst_form_print

# Function to calculate bytecode size from the .bin file
def calculate_bytecode_size(bin_file_path):
    # Read the bytecode from the .bin file
    with open(bin_file_path, 'r') as bin_file:
        bytecode = bin_file.read().strip()
    
    # The bytecode is in hexadecimal, each byte is represented by 2 hex digits
    bytecode_size = len(bytecode) // 2  # Each 2 hex characters represent 1 byte
    
    # print(f"Bytecode size: {bytecode_size} bytes")
    return bytecode_size

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
        contr_name = init_web3()
        lst_form_abi, lst_form_print = get_function_details(ABI_FILE, contr_name)
        bytecode_size = calculate_bytecode_size(BIN_FILE)

        # // ref: https://ethereum.org/en/history
        # //  code size limit = 24576 bytes (a limit introduced in Spurious Dragon _ 2016)
        # //  code size limit = 49152 bytes (a limit introduced in Shanghai _ 2023)
        str_limits = f"limits: 24576 bytes & 49152 bytes"
        print("",cStrDivider_1, f"FORMAT: _abi.py ... {contr_name} => {bytecode_size} bytes _ {str_limits}", cStrDivider_1, sep='\n')
        print("{", *lst_form_abi, "}", sep='\n')
        print("",cStrDivider_1, f"FORMAT: readable ... {contr_name} => {bytecode_size} bytes _ {str_limits}", cStrDivider_1, sep='\n')
        print("{", *lst_form_print, "}", sep='\n')
        print("",cStrDivider_1, f"all compiled file sizes in LST_CONTR_ABI_BIN _ {str_limits}", cStrDivider_1, sep='\n')
        for s in LST_CONTR_ABI_BIN:
            bin_file_path = s + '.bin'
            bytecode_size = calculate_bytecode_size(bin_file_path)
            print(bytecode_size, bin_file_path)
        print(cStrDivider_1, cStrDivider_1, sep='\n')

    except Exception as e:
        print_except(e, debugLvl=DEBUG_LEVEL)
    
    ## end ##
    print(f'\n\nRUN_TIME_START: {RUN_TIME_START}\nRUN_TIME_END:   {get_time_now()}\n')

print('', cStrDivider, f'# END _ {__filename}', cStrDivider, sep='\n')
