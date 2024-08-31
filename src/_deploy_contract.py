__fname = '_deploy_contract' # ported from 'defi-arb' (121023)
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
cStrDivider_1 = '#----------------------------------------------------------------#'

# CLI:
#   $ python3.10 _deploy_contract.py | tee ../bin/receipts/deploy_tBST_17_032424_2109.txt 
#------------------------------------------------------------#
#   IMPORTS                                                  #
#------------------------------------------------------------#
import sys, os, traceback, time, pprint, json
from datetime import datetime

# from web3 import Web3, HTTPProvider
# from web3.middleware import construct_sign_and_send_raw_middleware
# from web3.gas_strategies.time_based import fast_gas_price_strategy
# import env
import pprint
from attributedict.collections import AttributeDict # tx_receipt requirement
import _web3 # from web3 import Account, Web3, HTTPProvider

LST_CONTR_ABI_BIN = [
    "../bin/contracts/CallitLib",
    "../bin/contracts/CallitVault",
    "../bin/contracts/CallitDelegate",
    "../bin/contracts/CallitToken",
    "../bin/contracts/CallitFactory",
]

W3_ = None
ABI_FILE = None
BIN_FILE = None
CONTRACT = None

def init_web3():
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    # init W3_, user select abi to deploy, generate contract & deploy
    W3_ = _web3.myWEB3().init_inp()
    ABI_FILE, BIN_FILE, idx_contr = W3_.inp_sel_abi_bin(LST_CONTR_ABI_BIN) # returns .abi|bin
    CONTRACT = W3_.add_contract_deploy(ABI_FILE, BIN_FILE)
    contr_name = LST_CONTR_ABI_BIN[idx_contr].split('/')[-1]
    return contr_name

def estimate_gas(contract, contract_args=[]):
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    # Replace with your contract's ABI and bytecode
    # contract_abi = CONTR_ABI
    # contract_bytecode = CONTR_BYTES
    
    # Replace with your wallet's private key
    private_key = W3_.SENDER_SECRET

    # Create a web3.py contract object
    # contract = W3_.W3.eth.contract(abi=contract_abi, bytecode=contract_bytecode)

    # Set the sender's address from the private key
    sender_address = W3_.W3.eth.account.from_key(private_key).address

    # Estimate gas for contract deployment
    # gas_estimate = contract.constructor().estimateGas({'from': sender_address})
    gas_estimate = contract.constructor(*contract_args).estimate_gas({'from': sender_address})

    print(f"\nEstimated gas cost _ 0: {gas_estimate}")

    import statistics
    block = W3_.W3.eth.get_block("latest", full_transactions=True)
    gas_estimate = int(statistics.median(t.gas for t in block.transactions))
    gas_price = W3_.W3.eth.gas_price
    gas_price_eth = W3_.W3.from_wei(gas_price, 'ether')
    print(f"Estimated gas cost _ 1: {gas_estimate}")
    print(f" Current gas price: {gas_price_eth} ether (PLS) == {gas_price} wei")
    # Optionally, you can also estimate the gas price (in Gwei) using a gas price strategy
    # Replace 'fast' with other strategies like 'medium' or 'slow' as needed
    #gas_price = W3.eth.generateGasPrice(fast_gas_price_strategy)
    #print(f"Estimated gas price (Gwei): {W3.fromWei(gas_price, 'gwei')}")
    
    return input('\n (3) procced? [y/n]\n  > ') == 'y'

# note: params checked/set in priority order; 'def|max_params' uses 'mpf_ratio'
#   if all params == False, falls back to 'min_params=True' (ie. just use 'gas_limit')
def get_gas_params_lst(rpc_url, min_params=False, max_params=False, def_params=True):
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    # Estimate the gas cost for the transaction
    #gas_estimate = buy_tx.estimate_gas()
    gas_limit = W3_.GAS_LIMIT # max gas units to use for tx (required)
    gas_price = W3_.GAS_PRICE # price to pay for each unit of gas (optional?)
    max_fee = W3_.MAX_FEE # max fee per gas unit to pay (optional?)
    max_prior_fee = W3_.MAX_PRIOR_FEE # max fee per gas unit to pay for priority (faster) (optional)
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

# def generate_contructor():
#     constr_args = []
#     print()
#     while True:
#         arg = input(' Add constructor arg (use -1 to end):\n  > ')
#         if arg == '-1': break
#         if arg.isdigit(): arg = int(arg)
#         constr_args.append(arg)
#     return constr_args

def main():
    import _keeper
    global W3_, ABI_FILE, BIN_FILE, CONTRACT
    contr_name = init_web3()
    print(f'\nDEPLOYING bytecode: {BIN_FILE}')
    print(f'DEPLOYING abi: {ABI_FILE}')
    assert input('\n (1) procced? [y/n]\n  > ') == 'y', "aborted...\n"

    # constr_args, = generate_contructor(f'{contr_name}.constructor(...)') # 0x78b48b71C8BaBd02589e3bAe82238EC78966290c
    constr_args, _ = _keeper.go_enter_func_params(f'{contr_name}.constructor(...)')
    print(f'  using "constructor({", ".join(map(str, constr_args))})"')
    assert input(f'\n (2) procced? [y/n] _ {get_time_now()}\n  > ') == 'y', "aborted...\n"

    # proceed = estimate_gas(CONTRACT, constr_args) # (3) proceed? [y/n]
    # assert proceed, "\ndeployment canceled after gas estimate\n"

    print('\ncalculating gas ...')
    tx_nonce = W3_.W3.eth.get_transaction_count(W3_.SENDER_ADDRESS)
    tx_params = {
        'chainId': W3_.CHAIN_ID,
        'nonce': tx_nonce,
    }
    lst_gas_params = get_gas_params_lst(W3_.RPC_URL, min_params=False, max_params=True, def_params=True)
    for d in lst_gas_params: tx_params.update(d) # append gas params

    print(f'building tx w/ NONCE: {tx_nonce} ...')
    # constructor_tx = CONTRACT.constructor().build_transaction(tx_params)
    constructor_tx = CONTRACT.constructor(*constr_args).build_transaction(tx_params)

    print(f'signing and sending tx ... {get_time_now()}')
    # Sign and send the transaction # Deploy the contract
    tx_signed = W3_.W3.eth.account.sign_transaction(constructor_tx, private_key=W3_.SENDER_SECRET)
    tx_hash = W3_.W3.eth.send_raw_transaction(tx_signed.rawTransaction)

    print(cStrDivider_1, f'waiting for receipt ... {get_time_now()}', sep='\n')
    print(f'    tx_hash: {tx_hash.hex()}')

    # Wait for the transaction to be mined
    wait_time = 300 # sec
    try:
        tx_receipt = W3_.W3.eth.wait_for_transaction_receipt(tx_hash, timeout=wait_time)
        print("Transaction confirmed in block:", tx_receipt.blockNumber, f' ... {get_time_now()}')
    # except W3_.W3.exceptions.TransactionNotFound:    
    #     print(f"Transaction not found within the specified timeout... wait_time: {wait_time}", f' ... {get_time_now()}')
    # except W3_.W3.exceptions.TimeExhausted:
    #     print(f"Transaction not confirmed within the specified timeout... wait_time: {wait_time}", f' ... {get_time_now()}')
    except Exception as e:
        print(f"\n{get_time_now()}\n Transaction not confirmed within the specified timeout... wait_time: {wait_time}")
        print_except(e)
        exit(1)

    # print incoming tx receipt (requires pprint & AttributeDict)
    tx_receipt = AttributeDict(tx_receipt) # import required
    tx_rc_print = pprint.PrettyPrinter().pformat(tx_receipt)
    print(cStrDivider_1, f'RECEIPT:\n {tx_rc_print}', sep='\n')
    print(cStrDivider_1, f"\n\n Contract deployed at address: {tx_receipt['contractAddress']}\n\n", sep='\n')

#------------------------------------------------------------#
#   DEFAULT SUPPORT                                          #
#------------------------------------------------------------#
READ_ME = f'''
    *DESCRIPTION*
        deploy contract to chain
         selects .abi & .bin from ../bin/contracts/

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
        main()
    except Exception as e:
        print_except(e, debugLvl=0)
    
    ## end ##
    print(f'\n\nRUN_TIME_START: {RUN_TIME_START}\nRUN_TIME_END:   {get_time_now()}\n')

print('', cStrDivider, f'# END _ {__filename}', cStrDivider, sep='\n')


# deploy log (082024):
# address public LIB_ADDR = address(0x657428d6E3159D4a706C00264BD0DdFaf7EFaB7e); // CallitLib v1.0
# address public VAULT_ADDR = address(0xAbF4E00b848E06bb11Df56f54e81B47D5A584e50); // CallitVault v0.1
# address public VAULT_ADDR = address(0xa8667527F00da10cadE9533952e069f5209273c2); // CallitVault v0.4
#       Gas Used / Limit: 5,497,528 / 12,000,000
# address public VAULT_ADDR = address(0xd6b7Fea23aD710037E3bA6b7850A8243Fb675eC2); // CallitVault v0.7
#       Gas Used / Limit: 5,378,694 / 25,000,000
#   GAS_LIMIT: 25,000,000 units
#   MAX_FEE: 200,000 beats
#   MAX_PRIOR_FEE: 24,000 beats
# address public LIB_ADDR = address(0x59183aDaF0bB8eC0991160de7445CC5A7c984f67); // CallitLib v0.4
# address public VAULT_ADDR = address(0xd6698958e15EBc21b1C947a94ad93c476492878a); // CallitVault v0.10
# address public DELEGATE_ADDR = address(0x2945E11a5645f9f4304D4356753f29D37dB2F656); // CallitDelegate v0.4
# address public CALL_ADDR = address(0x711DD234082fD5392b9DE219D7f5aDf03a857961); // CallitToken v0.3

# address public LIB_ADDR = address(0x59183aDaF0bB8eC0991160de7445CC5A7c984f67); // CallitLib v0.4
# address public VAULT_ADDR = address(0x03539AF4E8DC28E05d23FF97bB36e1578Fec6082); // CallitVault v0.12
# address public DELEGATE_ADDR = address(0xCEDaa5E3D2FFe1DA3D37BdD8e1AeF5D7B98BdcEB); // CallitDelegate v0.6
# address public CALL_ADDR = address(0xCbc5bC00294383a63551206E7b3276ABcf65CD33); // CallitToken v0.5

# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0x1E96e984B48185d63449d86Fb781E298Ac12FB49); // CallitVault v0.13
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0x26c7C431534b4E6b2bF1b9ebc5201bEf2f8477F5); // CallitVault v0.14
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0xb39EF1b589B4409e9EEE6BDd37c7C63c7095c41a); // CallitVault v0.15
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

#--------------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0xBA3ED9c7433CFa213289123f3b266D56141e674B); // CallitVault v0.16
# address public DELEGATE_ADDR = address(0x8d823038d8a77eEBD8f407094464f0e911A571fe); // CallitDelegate v0.7
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

#--------------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0x0f87803348386c38334dD898b10CD7857Dc40599); // CallitLib v0.5
# address public VAULT_ADDR = address(0x1985fF1eDa386e43224F6fAb3e5A8829911A3DFa); // CallitVault v0.19 (wiped)
# address public DELEGATE_ADDR = address(0x0061e3F653cEc349e52A516db992b1b2e8cC795F); // CallitDelegate v0.12
# address public CALL_ADDR = address(0x35BEDeA0404Bba218b7a27AEDf3d32E08b1dD34F); // CallitToken v0.6
# address public FACT_ADDR = address(0x86726f5a4525D83a5dd136744A844B14Eb0f880c); // CallitFactory v0.18

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xD85b3FE914BC1cE98f9e79C6ac847DA090ce709e); // CallitLib v0.7
# address public VAULT_ADDR = address(0xD3B393E6279ED74fC447292F80C41634ee0c1B6C); // CallitVault v0.20 (wiped)
# address public DELEGATE_ADDR = address(0xaFc6d7D0e4A4494b3c2FAad365fb5DEC0345eb6F); // CallitDelegate v0.13
# address public CALL_ADDR = address(0x781DebCbF5cb15fFF1944Fd6B1E8193365AE7046); // CallitToken v0.7
# address public FACT_ADDR = address(0x39327e074a2A65F6eE4bf9D3DdC89105eFe15e7E); // CallitFactory v0.19

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0x9c673684999f8432e53C0E8906c5a51Ab7a025c3); // CallitLib v0.8
# address public VAULT_ADDR = address(0xc98ef085E50C74083115E2EdC65416b846A079A6); // CallitVault v0.21 (wiped)
# address public DELEGATE_ADDR = address(0xB3a3602ae7A94852Cf1022250Ac6e5b21C51068b); // CallitDelegate v0.14
# address public CALL_ADDR = address(0x295862D4F7E13fd1981Bc22cB3a3c47180Da2358); // CallitToken v0.8
# address public FACT_ADDR = address(0xD4d9bA09DBB97889e7A15eCb7c1FeE8366ed3428); // CallitFactory v0.20

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xEf2ED160EfF99971804D4630e361D9B155Bc7c0E); // CallitLib v0.9
# address public VAULT_ADDR = address(0xc98ef085E50C74083115E2EdC65416b846A079A6); // CallitVault v0.21 (wiped)
# address public DELEGATE_ADDR = address(0xB3a3602ae7A94852Cf1022250Ac6e5b21C51068b); // CallitDelegate v0.14
# address public CALL_ADDR = address(0x295862D4F7E13fd1981Bc22cB3a3c47180Da2358); // CallitToken v0.8
# address public FACT_ADDR = address(0xD4d9bA09DBB97889e7A15eCb7c1FeE8366ed3428); // CallitFactory v0.20

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xEf2ED160EfF99971804D4630e361D9B155Bc7c0E); // CallitLib v0.9
# address public VAULT_ADDR = address(0x3B3fec46400885e766D5AFDCd74085db92608E1E); // CallitVault v0.22 (wiped)
# address public DELEGATE_ADDR = address(0x2E175DBC91c9a50424BF29A023E5eEDB47b6dB94); // CallitDelegate v0.15
# address public CALL_ADDR = address(0x628dF5Ec8885eDbf0D95e3702Ced54862EaA770c); // CallitToken v0.10
# address public FACT_ADDR = address(0x7683DF731Efc78708cDe3aa0B01089b13606358E); // CallitFactory v0.23

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xEf2ED160EfF99971804D4630e361D9B155Bc7c0E); // CallitLib v0.9
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23
# address public DELEGATE_ADDR = address(0x17E66C5629943AB17497bf56cc77A5FB83DbC565); // CallitDelegate v0.16
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x69F65544e92c7E099170a85078dfAcAF8381436d); // CallitFactory v0.24

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xAb2ce52Ed5C3952a1A36F17f2C7c59984866d753); // CallitLib v0.14
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23
# address public DELEGATE_ADDR = address(0x17E66C5629943AB17497bf56cc77A5FB83DbC565); // CallitDelegate v0.16
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x69F65544e92c7E099170a85078dfAcAF8381436d); // CallitFactory v0.24

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xAb2ce52Ed5C3952a1A36F17f2C7c59984866d753); // CallitLib v0.14
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23
# address public DELEGATE_ADDR = address(0x7c5A1eE5963e791018e2B4AcCD4E77dcC97a969F); // CallitDelegate v0.17
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x69F65544e92c7E099170a85078dfAcAF8381436d); // CallitFactory v0.24

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xAb2ce52Ed5C3952a1A36F17f2C7c59984866d753); // CallitLib v0.14
# address public VAULT_ADDR = address(0x30cD1A302193C776f0570Ec590f1D4dA3042cAc4); // CallitVault v0.23
# address public DELEGATE_ADDR = address(0x7c5A1eE5963e791018e2B4AcCD4E77dcC97a969F); // CallitDelegate v0.17
# address public CALL_ADDR = address(0xBdefa6d27A22A6A376859e78E9bAe8E9ED445C5c); // CallitToken v0.11
# address public FACT_ADDR = address(0x233d822548b71545d706Fe0Fef3796b58e9141A5); // CallitFactory v0.25

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public VAULT_ADDR = address(0x8f006f5aE5145d44E113752fA1cD5a40289efB70); // CallitVault v0.25
# address public DELEGATE_ADDR = address(0x2e96d9Ac0129645C67CF986171083b4743660E6f); // CallitDelegate v0.20
# address public CALL_ADDR = address(0xf5Ad4e325C9E953fc890C7f00b4DC2E16C56F533); // CallitToken v0.12
# address public FACT_ADDR = address(0xa72fcf6C1F9ebbBA50B51e2e0081caf3BCEa69aA); // CallitFactory v0.28

#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(0xD0B9031dD3914d3EfCD66727252ACc8f09559265); // CallitLib v0.15
# address public VAULT_ADDR = address(); // CallitVault v0.25
# address public DELEGATE_ADDR = address(); // CallitDelegate v0.20
# address public CALL_ADDR = address(); // CallitToken v0.12
# address public FACT_ADDR = address(); // CallitFactory v0.28


#-----------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------#
# address public LIB_ADDR = address(); // CallitLib v0.7
# address public VAULT_ADDR = address(); // CallitVault v0.20
# address public DELEGATE_ADDR = address(); // CallitDelegate v0.13
# address public CALL_ADDR = address(); // CallitToken v0.7
# address public FACT_ADDR = address(); // CallitFactory v0.19


#--------------------------------------------------------------------------------------------------------------#
#--------------------------------------------------------------------------------------------------------------#
# tmark_0 1029945 1724958296 1724959296 1724960296 ["tl_1", "tl_2", "tl_2"] ["td_1", "td_2", "td_2"]
# tmark_0 1029945 1724958296 1724959296 1724960296 ["tl_1","tl_2","tl_2"] ["td_1","td_2","td_2"]
# tmark_0 1029945 1724958296 1724959296 1724960296 [tl_1,tl_2,tl_2] [td_1,td_2,td_2]
# tmark_0 1029945 1724958296 1724959296 1724960296 [0xtl_1,0xtl_2,0xtl_2] [0xtd_1,0xtd_2,0xtd_2]
# tmark_0
# 1039332
# 1693191781
# 1693192781
# 1693193781
# ["tl_1", "tl_2", "tl_2"]
# ["td_1", "td_2", "td_2"]


