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

# Example usage
# bin_file_path = 'YourContract.bin'  # Replace with the path to your .bin file


# Example usage
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
