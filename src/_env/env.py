__fname = 'env'
__filename = __fname + '.py'
cStrDivider = '#================================================================#'
cStrDivider_1 = '#----------------------------------------------------------------#'
print('', cStrDivider, f'GO _ {__filename} -> starting IMPORTs & declaring globals', cStrDivider, sep='\n')
#============================================================================#
## log paths (should use same 'log' folder as access & error logs from nginx config)
#GLOBAL_PATH_DEV_LOGS = "/var/log/<project>/dev.log"
#GLOBAL_PATH_ISE_LOGS = "/var/log/<project>/ise.log"

GLOBAL_PATH_DEV_LOGS = "../logs/dev.log"
GLOBAL_PATH_ISE_LOGS = "../logs/ise.log"

#============================================================================#
## Misc smtp email requirements (eg_121019: inactive)
SES_SERVER = 'nil'
SES_PORT = 'nil'
SES_FROMADDR = 'nil'
SES_LOGIN = 'nil'
SES_PASSWORD = 'nil'

corp_admin_email = 'nil'
corp_recept_email = 'nil'
admin_email = 'nil'
post_receiver = 'nil'
post_receiver_2 = 'nil'

#============================================================================#
#============================================================================#
## .env support
import os
from read_env import read_env

try:
    #ref: https://github.com/sloria/read_env
    #ref: https://github.com/sloria/read_env/blob/master/read_env.py
    read_env() # recursively traverses up dir tree looking for '.env' file
except:
    print("#==========================#")
    print(" ERROR: no .env files found ")
    print("#==========================#")

# db support
dbHost = os.environ['DB_HOST']
dbName = os.environ['DB_DATABASE']
dbUser = os.environ['DB_USERNAME']
dbPw = os.environ['DB_PASSWORD']

# req_handler support
LST_KEYS_PLACEHOLDER = []

# s3 support (use for remote server)
ACCESS_KEY = os.environ['ACCESS_KEY']
SECRET_KEY = os.environ['SECRET_KEY']

# twitter support @SolAudits
CONSUMER_KEY_0 = os.environ['CONSUMER_KEY_0']
CONSUMER_SECRET_0 = os.environ['CONSUMER_SECRET_0']
ACCESS_TOKEN_0 = os.environ['ACCESS_TOKEN_0']
ACCESS_TOKEN_SECRET_0 = os.environ['ACCESS_TOKEN_SECRET_0']

# twitter support @BearSharesX
CONSUMER_KEY_1 = os.environ['CONSUMER_KEY_1']
CONSUMER_SECRET_1 = os.environ['CONSUMER_SECRET_1']
ACCESS_TOKEN_1 = os.environ['ACCESS_TOKEN_1']
ACCESS_TOKEN_SECRET_1 = os.environ['ACCESS_TOKEN_SECRET_1']

# openAI
OPENAI_KEY = os.environ['OPENAI_KEY']

# telegram
TOKEN_dev = os.environ['TG_TOKEN_DEV'] # (dev)
TOKEN_prod = os.environ['TG_TOKEN_PROD'] # (prod)
TOKEN_neo = os.environ['TG_TOKEN_NEO'] # (neo) @bs_neo_bot
TOKEN_trin = os.environ['TG_TOKEN_TRIN'] # (trinity) @bs_trinity_bot
TOKEN_trin_pay = os.environ['TG_TOKEN_TRIN_PAY'] # (trinityPay) @bs_trinity_pay_bot
TOKEN_morph = os.environ['TG_TOKEN_MORPH'] # @bs_morpheus_bot
TOKEN_oracle = os.environ['TG_TOKEN_ORACLE'] # @bs_oracle_bot

# LST_TG_TOKENS = [{'@TeddySharesBot':TOKEN_dev},
#                  {'@BearSharesBot':TOKEN_prod},
#                  {'@neo_bs_bot':TOKEN_neo},
#                  {'@bs_trinity_bot':TOKEN_trin},
#                  ]

#============================================================================#

# infura support
#ETH_MAIN_RPC_KEY = os.environ['ETH_MAIN_INFURA_KEY_0']
ETH_MAIN_RPC_KEY = os.environ['ETH_MAIN_INFURA_KEY_1']

# wallet support
sender_address_0 = os.environ['PUBLIC_KEY_3']
sender_secret_0 = os.environ['PRIVATE_KEY_3']
sender_address_1 = os.environ['PUBLIC_KEY_4']
sender_secret_1 = os.environ['PRIVATE_KEY_4']
sender_address_2 = os.environ['PUBLIC_KEY_5']
sender_secret_2 = os.environ['PRIVATE_KEY_5']
sender_address_3 = os.environ['PUBLIC_KEY_6']
sender_secret_3 = os.environ['PRIVATE_KEY_6']

sender_addr_trinity = sender_address_1
sender_secr_trinity = sender_secret_1

#============================================================================#
## web3 constants
#============================================================================#
local_test = 'http://localhost:8545'
eth_main = f'https://mainnet.infura.io/v3/{ETH_MAIN_RPC_KEY}'
eth_test = f'https://goerli.infura.io/v3/'
pc_main = f'https://rpc.pulsechain.com'
eth_main_cid=1
pc_main_cid=369
bst_contr_addr = os.environ['BST_CONTR_ADDR']
bst_contr_symb = os.environ['BST_CONTR_SYMB']



#============================================================================#
## WALLET SERCRETS - * DO NOT COMMIT *
#============================================================================#
# wallets generated_[2024-04-24 23:32:10.85]
RAND_WALLET_CLI_INPUT_10_1 = "[0xF604D6eEB6bc6263112B59eAD8Fb15313186D932,0x5c5b73772d40e75B1Ce98dF201FE05AD1C63F591,0x6A6E1C5fa5B4D11Ea4025D05ed1f4146F0c11C3e,0xCb7F49b4bC56745b26DfA06F3370A66C705a7198,0x907b7f2D08023473F898bA5a55fdb090949A1A52,0x1541581e348243f7D499Ce4f877333459DfBf722,0xf749A586f406928760DD0549db9ab4eb54F20a7E,0x0592DA23b14D80Ce8C5cf2d6829D421F531C6E1f,0x2D0f20D3Db3b139899A9885799e9e1BeA61262f7,0xEa7061e46c1A84dBFEeDbA6C313d3702fA4d701B]"
# wallets generated_[2024-04-23 00:22:13.56]
RAND_WALLET_CLI_INPUT_10 = "[0xF72017Cbd553B109EA9085E1B3f6CDcfc7baaC52,0xdA0F4e39E4a5cd6c8a1f1681ad91eB41831683B3,0x4a2C5bb0b4cDafa8c4bE7113738fce369D4905d0,0x839AdF9C10C8a316Cd5FB9DB1A5D0eAb9394bc11,0x31877cc9a2D7B7eabBCD2D3c1dd676D44740a89c,0x7816F933Ca6E8f571A11D3aDFA44976b1c726C55,0xC378f72c82Ee2Ad2A385A74A146378221d649d08,0x2d2cA847545e40FacbeB45C8C0d692372F71C970,0x8A87cF2885F9c4e4369Bb0f7c41B0461400f7EC7,0x2f3569153d9272afeb84737B59D8D4C8E2a35361]"
RAND_WALLET_CLI_INPUT_20_1 = "[0x2BA9C7b55026491aC451BB8714250B00fbD4f6ED,0xD82F6e1705D169b41285bBA32cd3861Ea19Fa87b,0x9021875819eDa7BA8b430e17dC27A76Cc1e93499,0x3F7F8FB0bE31787Edbb2df5b30fEc888Cd4346Fd,0x4A482250E4E7a38aa0CD6d0d5bC08C21bE72573c,0x2438219f14427544BB666BBFA50d0b340d2f0689,0x292f0A930Dca86b28f4Ce2Db0305058C20127644,0xd3d6fB80A9558F9C8d4453b8DED7E6e46963ee71,0xDC7241E05C9D567254c690C4Bc6eCBE059c9a8E7,0x6B40DC734b71F6DbAa2ACe0113d66601908e928D]"
RAND_WALLET_CLI_INPUT_20_0 = "[0xAF807991C00ab98D3f2777f51c0b62B02e36a7AD,0x2Bab6ba791Fb4Ebad81daF03b5D0d7d02A8BB97c,0xaA5D992D69C342235845e0649A793F615645a422,0x93d018Ae743Dc6F120104979aC3E5875eC24f012,0x7c59197c540860D69291356991A193eB22f7E508,0x637C4a9420A3dD9702c43E1dD85F901A13cCD6e5,0xeB2266d97d827f3e2D793845915E8DdbaF4d680c,0xF75EC26446ee5a59C158691Fc1A1c4F403A3BC01,0x335f85D2944079f5bbD927BAD9C2B906fF44FC1b,0x75c4F7EA25fEe88C54D9e34C97AD64e858de4246]"
# wallets generated_[2024-04-20 19:50:18.38]
RAND_WALLET_CLI_INPUT = "[0x56F76E1CfeD37230667c1a5a882A3AF6Ad192a23,0x6D9E49F3ebfC6cd79BAEE70Ef41d19933C029CCD,0x6eDb254999F8C3B5F5F13b30979c7770F3376f71,0x3d8A1aD5d4b40fec6c71283Bf4485BC340087CeD,0x46D7b8325c573627A2b506EBaed19F1a3964138D,0x452B5daa480193e03ca3E22B93eAE6E2083Ed425,0xcCcdfC722714743f08962c3e8370957ed880C17B,0xE1F918DC10D9e40a0fb80c0B547c210B761FdaD7,0xbfc4DA072d9Df9DaEe1BBB85D10813C40f30575A,0xd40383446acD649f20Ab1d17e75F3875D30B25D9]"

# full _gen_pls_key.py outputs
RAND_WALLETS_10_1 = [{'address': '0xF604D6eEB6bc6263112B59eAD8Fb15313186D932',
                    'secretKey': 'fe19b953a2d166e2d6bcfc26df88a1367d0b3f87d5544701695832e79afa0440',
                    'seedPhrase': 'news umbrella pact skate earth fragile cloth globe fox claw '
                                    'gospel ordinary range lucky print honey senior flower genuine '
                                    'patch fury dove bag foot',
                    'seedPhraseLength': 24},
                    {'address': '0x5c5b73772d40e75B1Ce98dF201FE05AD1C63F591',
                    'secretKey': '17e159e65cc93bda0e7d45b405ef7fdd25ec828d2aa5e52354f4e7cc6a6185e0',
                    'seedPhrase': 'doctor guilt ancient supreme audit fuel artist tip cheese '
                                    'sense alley bacon tone pave cricket anxiety correct unveil '
                                    'execute what taste dune tool slim',
                    'seedPhraseLength': 24},
                    {'address': '0x6A6E1C5fa5B4D11Ea4025D05ed1f4146F0c11C3e',
                    'secretKey': '7d90a590d6f435692f8ad010a84c874fd699737803a9626c58e4d627a2382789',
                    'seedPhrase': 'amount miss tunnel drop day snack tomato blind citizen '
                                    'business gorilla shine that alone april adult rebuild test '
                                    'course girl lab cushion carry combine',
                    'seedPhraseLength': 24},
                    {'address': '0xCb7F49b4bC56745b26DfA06F3370A66C705a7198',
                    'secretKey': '42d8fa0034bb8648e7e538ddd3ea598c57bd442630c3c68337084d4c5e49fa3d',
                    'seedPhrase': 'never solid little finger gown thumb knife used violin '
                                    'garbage casino window antique empty cart danger quit split '
                                    'gossip tornado pudding iron million luggage',
                    'seedPhraseLength': 24},
                    {'address': '0x907b7f2D08023473F898bA5a55fdb090949A1A52',
                    'secretKey': '86ae4735b625c30ba596bec16b2b558a151a96c60d80cba8f19a84d720872d65',
                    'seedPhrase': 'few matter senior cup holiday rhythm true east exotic wink '
                                    'possible video hole friend expire owner laugh lion moment '
                                    'message stem ability lyrics eager',
                    'seedPhraseLength': 24},
                    {'address': '0x1541581e348243f7D499Ce4f877333459DfBf722',
                    'secretKey': 'cad33b334f6a660528cdacdcd2d0a07855a086157434a1b2f1431fa4c8874d37',
                    'seedPhrase': 'exclude tank van juice wild sting assume cushion address '
                                    'sister volume rule drama trade you athlete about tonight sun '
                                    'report deputy valve fall viable',
                    'seedPhraseLength': 24},
                    {'address': '0xf749A586f406928760DD0549db9ab4eb54F20a7E',
                    'secretKey': '442f84eb63c0b0a2d7bf77fd061578ba65ff09e0d9303b6bd72486e853e6b510',
                    'seedPhrase': 'decrease royal clinic special trim sad smile boil gauge silly '
                                    'fit say test powder include smooth road february flock '
                                    'remember flight into royal glide',
                    'seedPhraseLength': 24},
                    {'address': '0x0592DA23b14D80Ce8C5cf2d6829D421F531C6E1f',
                    'secretKey': '0a422be5945a8fcc1b3ed6f66a1338484159b8d7ba36668575497a80a07d85ff',
                    'seedPhrase': 'begin achieve mule veteran bitter glare horror talent crime '
                                    'estate false tip present denial ski action lake pipe vehicle '
                                    'able option donkey ivory what',
                    'seedPhraseLength': 24},
                    {'address': '0x2D0f20D3Db3b139899A9885799e9e1BeA61262f7',
                    'secretKey': 'b94d7aff852bead61a0475ff46d557fd8e70ba186c5e08dd2177b4f938f9b9c3',
                    'seedPhrase': 'vivid boost wedding train banana library labor awesome '
                                    'thought soft entire shadow winter defense shallow false open '
                                    'kitchen sweet future beauty lounge benefit dice',
                    'seedPhraseLength': 24},
                    {'address': '0xEa7061e46c1A84dBFEeDbA6C313d3702fA4d701B',
                    'secretKey': 'fce7299093a35229ccb086bab44e6925a12bc658847a50b0a15a3c6668e08786',
                    'seedPhrase': 'long pulp story extra grace weasel company person clarify '
                                    'captain gate call again hazard talent slim member column game '
                                    'focus moment gorilla rotate claw',
                    'seedPhraseLength': 24}]
RAND_WALLETS_10 = [{'address': '0xF72017Cbd553B109EA9085E1B3f6CDcfc7baaC52',
                    'secretKey': 'd9b51b182786822e924f48d2808d0ae77f16fa544206e1e0d78b04860fbf5d73',
                    'seedPhrase': 'slow doctor jewel pig receive admit vote spawn one shoe '
                                    'please author consider crazy twist oil crawl solution '
                                    'scorpion mail girl confirm aerobic rather',
                    'seedPhraseLength': 24},
                    {'address': '0xdA0F4e39E4a5cd6c8a1f1681ad91eB41831683B3',
                    'secretKey': '64653ac57eb4178e733ae1faa8e3a798a11baa9a5e78706d825400a18a75b6cd',
                    'seedPhrase': 'staff veteran question hair sound where demand humor buffalo '
                                    'cart post woman alpha place soccer cliff oyster begin fortune '
                                    'canyon minor wheat eyebrow element',
                    'seedPhraseLength': 24},
                    {'address': '0x4a2C5bb0b4cDafa8c4bE7113738fce369D4905d0',
                    'secretKey': 'ae7a5dfeaea007aae889c2e8e05f69ce761cb95b891cf2b01cdf0f1dd45a5ad9',
                    'seedPhrase': 'music noise brother shock exchange window twin panic fossil '
                                    'quit amused stem tube check unusual damage begin enroll '
                                    'silver critic expose notable use business',
                    'seedPhraseLength': 24},
                    {'address': '0x839AdF9C10C8a316Cd5FB9DB1A5D0eAb9394bc11',
                    'secretKey': 'd24bb25d580fd4eea58235ad18e07b18753fd36447ad0b99800ce7af177558cb',
                    'seedPhrase': 'bulb latin cannon fork ginger can useless height squeeze '
                                    'purpose soldier there frown taste diet mixture insect swear '
                                    'holiday ritual jar hazard smile scatter',
                    'seedPhraseLength': 24},
                    {'address': '0x31877cc9a2D7B7eabBCD2D3c1dd676D44740a89c',
                    'secretKey': 'd977f628fd48bf9205260091686f9aed4f2bb17a6291dc9f4900152adb4aae76',
                    'seedPhrase': 'lunch security balance elephant giggle purse improve soft '
                                    'material frost craft tribe bicycle cross scissors version '
                                    'next regular online bargain mention friend exchange thing',
                    'seedPhraseLength': 24},
                    {'address': '0x7816F933Ca6E8f571A11D3aDFA44976b1c726C55',
                    'secretKey': '80ed90012a6fd510b98c7f3c7f487dca62d32c1b21fbd8073c0f63a48b628fdb',
                    'seedPhrase': 'hobby valid group eternal index better frost fade stove '
                                    'jaguar arrive choice average misery web sibling picnic volume '
                                    'column deliver surprise brain typical grape',
                    'seedPhraseLength': 24},
                    {'address': '0xC378f72c82Ee2Ad2A385A74A146378221d649d08',
                    'secretKey': '23d4eabc8256809ced4a5a8e58e05918b65a07681d69317a1512011ff67dbe3a',
                    'seedPhrase': 'family hospital stool oblige soap crash make identify bleak '
                                    'soccer bread food kite enforce coconut dilemma radio promote '
                                    'father street moon jump like flush',
                    'seedPhraseLength': 24},
                    {'address': '0x2d2cA847545e40FacbeB45C8C0d692372F71C970',
                    'secretKey': '8eeabf915497861d1c725b2df522eac9fe87b3630b21c745da4b80d4a64c1f47',
                    'seedPhrase': 'helmet emotion cage exist spoil resource vault mean absorb '
                                    'planet museum prefer chronic deputy genre ranch leisure rib '
                                    'adult surprise cigar current stone trash',
                    'seedPhraseLength': 24},
                    {'address': '0x8A87cF2885F9c4e4369Bb0f7c41B0461400f7EC7',
                    'secretKey': '48808e54204593da1b0e96e1620299300fec6113ed01a94a83788af5cb196f5d',
                    'seedPhrase': 'distance slam month blur tag turn artist alien scale suspect '
                                    'magic legal tonight movie flat blind relax much dynamic '
                                    'awkward silver upper outside window',
                    'seedPhraseLength': 24},
                    {'address': '0x2f3569153d9272afeb84737B59D8D4C8E2a35361',
                    'secretKey': 'ab67b3178e2862355522453d82e24d6454a1159ef55bc9a3589b9b4eea2dea37',
                    'seedPhrase': 'provide symbol game auto powder frozen ribbon clever rent '
                                    'test brisk tobacco lazy color jazz alter unknown zebra toilet '
                                    'ability guilt ceiling unable cricket',
                    'seedPhraseLength': 24}]
RAND_WALLETS_20 = [{'address': '0x2BA9C7b55026491aC451BB8714250B00fbD4f6ED',
                'secretKey': '97c59e6702f0165d4c9fecadb74254f29770addf31325cd1c1d92ddba26c5504',
                'seedPhrase': 'kingdom tooth broccoli panther flush lazy lens reopen world '
                                'gentle fluid ecology zoo various topic suggest unaware buzz '
                                'dance behind hurry theory enforce pact',
                'seedPhraseLength': 24},
                {'address': '0xD82F6e1705D169b41285bBA32cd3861Ea19Fa87b',
                'secretKey': '32effc5cac8c920d113a60c1e903ce8684858d9119bf93e57cc8016a55aa47bc',
                'seedPhrase': 'neck know illness prison spider ability subway split still '
                                'worth disorder box mass hawk huge rose moment crystal equal '
                                'current ivory bread obscure round',
                'seedPhraseLength': 24},
                {'address': '0x9021875819eDa7BA8b430e17dC27A76Cc1e93499',
                'secretKey': '2b95865690cdd5de7dd471c60b026d299a47a10d869edc0a38f994d196b4d2e8',
                'seedPhrase': 'squirrel leave since thunder joke crash pet almost movie '
                                'cycle angle announce happy music modify excite session ski '
                                'soda typical group depth manual leopard',
                'seedPhraseLength': 24},
                {'address': '0x3F7F8FB0bE31787Edbb2df5b30fEc888Cd4346Fd',
                'secretKey': '2d121b06166660a9cf8d58d73cd9445282417c11855ae2180697a720b92312b8',
                'seedPhrase': 'auction crack era brand mosquito chef surround fever wish two '
                                'universe cabin begin tackle cactus twist inject device adapt '
                                'glance yellow cage buffalo permit',
                'seedPhraseLength': 24},
                {'address': '0x4A482250E4E7a38aa0CD6d0d5bC08C21bE72573c',
                'secretKey': '318e1aaf0b8b510a75760b620037121cfe1419235bf160f8bed190d1538eb277',
                'seedPhrase': 'large village remove attract slim add air embark away rally '
                                'wall universe coil holiday glow liquid fatal culture pattern '
                                'match surge estate update armor',
                'seedPhraseLength': 24},
                {'address': '0x2438219f14427544BB666BBFA50d0b340d2f0689',
                'secretKey': 'fe2c7aa8fbab625411972ce42b5dbefee73fafb693a4ba661f4a2e2c04b75415',
                'seedPhrase': 'name seed must identify mushroom car craft abuse rent ocean '
                                'until goose satisfy ethics stumble recycle year wine brother '
                                'ginger swarm risk citizen pull',
                'seedPhraseLength': 24},
                {'address': '0x292f0A930Dca86b28f4Ce2Db0305058C20127644',
                'secretKey': 'a7f634e49f3324ad2dc77b72908ba597fa6911d6cf954c34d8b8c0b1c175c3f1',
                'seedPhrase': 'casino apple flee sport quiz vapor pitch legal kit lunch help '
                                'chef tongue lock emotion explain couple sense display foil '
                                'turn lunch mule book',
                'seedPhraseLength': 24},
                {'address': '0xd3d6fB80A9558F9C8d4453b8DED7E6e46963ee71',
                'secretKey': 'f0ea7b77260173c21397ac67a021b155c2f92f367fb0b57647d4ec2914e1e659',
                'seedPhrase': 'aware turn palace mad edit fish pigeon twist stay valley wise '
                                'choose large clown baby want choice dinner menu payment apart '
                                'invest hold wood',
                'seedPhraseLength': 24},
                {'address': '0xDC7241E05C9D567254c690C4Bc6eCBE059c9a8E7',
                'secretKey': '8d1dac76eee1faa12f766c2597a8b21c96e3e6b7ea811ce04a510c108d4ff390',
                'seedPhrase': 'success direct metal narrow butter castle venture fold '
                                'involve warm rent assault dad fortune select repair snap '
                                'pudding utility spoon absent jungle logic hungry',
                'seedPhraseLength': 24},
                {'address': '0x6B40DC734b71F6DbAa2ACe0113d66601908e928D',
                'secretKey': 'f27d3f1d9677a6486c30205b5b2fed763922e971e13c8e0de34bfe97a84d8bbe',
                'seedPhrase': 'square craft sad song faith pave legend trap expect laugh mix '
                                'lawsuit cheese diary rose into miracle topic yellow mother '
                                'praise useless slide intact',
                'seedPhraseLength': 24},
                {'address': '0xAF807991C00ab98D3f2777f51c0b62B02e36a7AD',
                'secretKey': '4c35b941f9829eed4878cd1c8769dc868049a30eac9db2e9e28a415ed8f86cd7',
                'seedPhrase': 'two arm join crowd copper cry marine eager candy appear wide '
                                'have throw copy allow essence lock street off useful fox '
                                'chief waste scene',
                'seedPhraseLength': 24},
                {'address': '0x2Bab6ba791Fb4Ebad81daF03b5D0d7d02A8BB97c',
                'secretKey': 'd4f83c65050bbee0b16021d9c56b614002384c7ac3d72540c70456cc16b9893c',
                'seedPhrase': 'heart client amateur pepper knife fringe industry final '
                                'nature flee drastic below river memory champion ability wise '
                                'pave woman phrase swarm plunge flip pyramid',
                'seedPhraseLength': 24},
                {'address': '0xaA5D992D69C342235845e0649A793F615645a422',
                'secretKey': '045babf04732939357309658e22c005d633afa059677c700df93c5ff2fdafa99',
                'seedPhrase': 'juice body keep cushion vicious ugly innocent tortoise '
                                'dismiss law gaze scheme sheriff prepare stone very sample '
                                'palm need wrestle hammer cruise eye close',
                'seedPhraseLength': 24},
                {'address': '0x93d018Ae743Dc6F120104979aC3E5875eC24f012',
                'secretKey': '98b1183ba3d49579e2d34374d6dfc874cd1e64522f79c8121ba63e6218a3d12f',
                'seedPhrase': 'kit defy clerk left air draft shy because enhance erupt aunt '
                                'document impact viable margin tonight master begin throw '
                                'system slim surface also december',
                'seedPhraseLength': 24},
                {'address': '0x7c59197c540860D69291356991A193eB22f7E508',
                'secretKey': 'ae9b655d85406754fc7d1025f080a258c3512ea27df4825f089dcd4a3890e45c',
                'seedPhrase': 'exhaust outer real runway orphan surge insane beauty buyer '
                                'page carbon fine deal concert mystery situate volume chunk '
                                'crop mean shift road popular noodle',
                'seedPhraseLength': 24},
                {'address': '0x637C4a9420A3dD9702c43E1dD85F901A13cCD6e5',
                'secretKey': 'b9f29eb55e6edf68b7b3fc7ac3242e5b1b341a6ba4525459922c80e50836313d',
                'seedPhrase': 'lift sure improve require worry digital allow tomato devote '
                                'adult orient heart inquiry lobster hover approve favorite '
                                'cook satisfy various toe beef apple scheme',
                'seedPhraseLength': 24},
                {'address': '0xeB2266d97d827f3e2D793845915E8DdbaF4d680c',
                'secretKey': 'bd2b5587b7b605657c602938f0fff19b19864c198f5c344f49ddaf0066aecb22',
                'seedPhrase': 'close hold nest angry cable such term grocery kite bamboo '
                                'same unit guess entry true poverty width eternal shaft vendor '
                                'fatigue roast differ coil',
                'seedPhraseLength': 24},
                {'address': '0xF75EC26446ee5a59C158691Fc1A1c4F403A3BC01',
                'secretKey': '4e90ee6f8cc8d09ed23e494a9f863c04a654a644b0a856c91b52846bdcb76ab8',
                'seedPhrase': 'tornado crunch lion spin mule tornado style vacant bacon '
                                'armed food ship tunnel release foil cereal satisfy later '
                                'surge small solution sun sort differ',
                'seedPhraseLength': 24},
                {'address': '0x335f85D2944079f5bbD927BAD9C2B906fF44FC1b',
                'secretKey': '612864f6217ff4a823c7ca4f9bb51ab6a334f7d5c129fe3c988939b8f207ee67',
                'seedPhrase': 'van error sell answer apology tiger country gravity mansion '
                                'volcano hunt valley twice disease valley coil wagon symbol '
                                'cotton knee grab ride sausage current',
                'seedPhraseLength': 24},
                {'address': '0x75c4F7EA25fEe88C54D9e34C97AD64e858de4246',
                'secretKey': '032040a37c112812e12bd86501e4d79ceb1e660c8b233d8e6bc879b0dd061876',
                'seedPhrase': 'pilot arch index group ethics tonight pull glue feature '
                                'broken similar split estate forward draft cruise exit best '
                                'blush marine proof coyote assume grace',
                'seedPhraseLength': 24}]
RAND_WALLETS = [{'address': '0x56F76E1CfeD37230667c1a5a882A3AF6Ad192a23',
				'secretKey': '7c966eae2b5eedb77d4baa3f51fbd089fd4ac58eb640d9eb24df2645db88629e',
				'seedPhrase': 'lyrics dust plate figure swamp paddle spatial skill surge '
								'illegal account journey ramp exile find muffin cousin summer '
								'badge dumb month unique sun bright',
				'seedPhraseLength': 24},
				{'address': '0x6D9E49F3ebfC6cd79BAEE70Ef41d19933C029CCD',
				'secretKey': '2afa498eb2898e208baaf1d2338e0c69775002fe0a72b12d3cbc322d2b4d2dc3',
				'seedPhrase': 'awful fetch sponsor join soft marriage grocery crawl deliver '
								'sword asthma sense zone cube siege ignore trip ghost uncover '
								'math crime jaguar man fuel',
				'seedPhraseLength': 24},
				{'address': '0x6eDb254999F8C3B5F5F13b30979c7770F3376f71',
				'secretKey': 'c994e26d535f48feaa3ffc7f72d6324d713cd2e30d714dfe2397fc0f84e146cb',
				'seedPhrase': 'ship umbrella minor jealous final draft chuckle embark give '
								'police cart neglect record estate candy diesel neglect hour '
								'utility pig inner normal drum rather',
				'seedPhraseLength': 24},
				{'address': '0x3d8A1aD5d4b40fec6c71283Bf4485BC340087CeD',
				'secretKey': '11cc43b81187a94b5a8dd9064a47495f9e672395170acc1fa877424eeb72f661',
				'seedPhrase': 'boring stove caution firm credit pulp bleak price series '
								'enforce wave marriage kitten payment zebra fault multiply '
								'barrel journey leisure matter monitor magic vicious',
				'seedPhraseLength': 24},
				{'address': '0x46D7b8325c573627A2b506EBaed19F1a3964138D',
				'secretKey': '76fb81f0d17aa2bf1ef3364ac9acedbd815612dec16d8a66482f8ab9b1282e08',
				'seedPhrase': 'holiday bronze story affair sell crush fluid moment snow '
								'slide select purpose matter jaguar industry oil perfect same '
								'rude captain demise tray copy citizen',
				'seedPhraseLength': 24},
				{'address': '0x452B5daa480193e03ca3E22B93eAE6E2083Ed425',
				'secretKey': '0d63113245f067a18684fac2b57ab0b5f159993af25999a62c6d85a2fa9cb68b',
				'seedPhrase': 'squeeze primary movie purchase horse wrestle nurse enable two '
								'random divorce length tonight mutual spoon smart later snap '
								'twist zoo bundle legend wolf bind',
				'seedPhraseLength': 24},
				{'address': '0xcCcdfC722714743f08962c3e8370957ed880C17B',
				'secretKey': 'e1814c54087886fd9816a4ca89d7bb85314f815359b31fa96c709b3764051931',
				'seedPhrase': 'earn hand budget search angry village buyer latin alert '
								'orchard toast world shoe solid pony ticket claw document toss '
								'accident lemon shove vehicle language',
				'seedPhraseLength': 24},
				{'address': '0xE1F918DC10D9e40a0fb80c0B547c210B761FdaD7',
				'secretKey': 'c993fff9f6cb09bc7d3ec336eea2c391155dce3ef944e553044ec3735148fb2d',
				'seedPhrase': 'correct luggage renew until choose jeans bracket candy vocal '
								'casual noise cave peace liquid height noble custom annual '
								'eight illegal spray phrase picnic dust',
				'seedPhraseLength': 24},
				{'address': '0xbfc4DA072d9Df9DaEe1BBB85D10813C40f30575A',
				'secretKey': 'c23cbd87d2c085ebcdfb8803fb6a218af3a89822e673ca78c8fb9bdd3dba2edd',
				'seedPhrase': 'tired visual deposit best comfort battle receive able result '
								'pause skin allow upgrade girl dinosaur symptom devote game '
								'subway estate unlock drastic thumb hope',
				'seedPhraseLength': 24},
				{'address': '0xd40383446acD649f20Ab1d17e75F3875D30B25D9',
				'secretKey': '90cab72dd002660b7603717a3a5c68e7481e171655b1eea24d9fe6eb153b1022',
				'seedPhrase': 'inherit canyon stem cup lion beauty apple boss keen aim write '
								'kid forum turtle shield bomb lab trophy tuition benefit '
								'unusual swallow purity deposit',
				'seedPhraseLength': 24}]