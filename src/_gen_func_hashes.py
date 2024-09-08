__fname = '_gen_func_hashes' # ported from '_deploye_contract.py' (090724)
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

import json
import _web3 # from web3 import Account, Web3, HTTPProvider
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
def print_function_details(abi_file_path):
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
        # print(formatted_string)d
    print("",cStrDivider_1, "FORMAT: _abi.py ...", cStrDivider_1, sep='\n')
    print("{", *lst_form_abi, "}", sep='\n')
    print("",cStrDivider_1, "FORMAT: readable ...", cStrDivider_1, sep='\n')
    print("{", *lst_form_print, "}", sep='\n')
    print(cStrDivider_1, cStrDivider_1, sep='\n')

# Example usage
contr_name = init_web3()
print_function_details(ABI_FILE)
