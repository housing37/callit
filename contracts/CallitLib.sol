// SPDX-License-Identifier: UNLICENSED
// inherited contracts
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol"; // deploy

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

pragma solidity ^0.8.20;
library CallitLib {
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);

    /* -------------------------------------------------------- */
    /* PUBLIC - DEX QUOTE SUPPORT                                    
    /* -------------------------------------------------------- */
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenLowMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address) {
        // traverse _stables & select stable w/ the lowest market value
        uint256 curr_high_tok_val = 0;
        address curr_low_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the most when swapped 'from' WPLS
            //  the more USD stable received for 1 WPLS ~= the less overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (uint8 rtrIdx, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_high_tok_val) {
                curr_high_tok_val = tok_val;
                curr_low_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_low_val_stable;
    }
    
    // NOTE: *WARNING* _stables could have duplicates (from 'whitelistStables' set by keeper)
    function _getStableTokenHighMarketValue(address[] memory _stables, address[] memory _routers) external view returns (address) {
        // traverse _stables & select stable w/ the highest market value
        uint256 curr_low_tok_val = 0;
        address curr_high_val_stable = address(0x0);
        for (uint8 i=0; i < _stables.length;) {
            address stable_addr = _stables[i];
            if (stable_addr == address(0)) { continue; }

            // get quote for this stable (traverses 'uswapV2routers')
            //  looking for the stable that returns the least when swapped 'from' WPLS
            //  the less USD stable received for 1 WPLS ~= the more overall market value that stable has
            address[] memory wpls_stab_path = new address[](2);
            wpls_stab_path[0] = TOK_WPLS;
            wpls_stab_path[1] = stable_addr;
            (uint8 rtrIdx, uint256 tok_val) = _best_swap_v2_router_idx_quote(wpls_stab_path, 1 * 10**18, _routers);
            if (tok_val >= curr_low_tok_val) {
                curr_low_tok_val = tok_val;
                curr_high_val_stable = stable_addr;
            }

            // NOTE: unchecked, never more than 255 (_stables)
            unchecked {
                i++;
            }
        }
        return curr_high_val_stable;
    }

    // uniswap v2 protocol based: get router w/ best quote in 'uswapV2routers'
    function _best_swap_v2_router_idx_quote(address[] memory path, uint256 amount, address[] memory _routers) public view returns (uint8, uint256) {
        uint8 currHighIdx = 37;
        uint256 currHigh = 0;
        for (uint8 i = 0; i < _routers.length;) {
            uint256[] memory amountsOut = IUniswapV2Router02(_routers[i]).getAmountsOut(amount, path); // quote swap
            if (amountsOut[amountsOut.length-1] > currHigh) {
                currHigh = amountsOut[amountsOut.length-1];
                currHighIdx = i;
            }

            // NOTE: unchecked, never more than 255 (_routers)
            unchecked {
                i++;
            }
        }

        return (currHighIdx, currHigh);
    }
    // uniwswap v2 protocol based: get quote and execute swap
    function _swap_v2_wrap(address[] memory path, address router, uint256 amntIn, address outReceiver, bool fromETH) external returns (uint256) {
        require(path.length >= 2, 'err: path.length :/');
        uint256 amntOutQuote = _swap_v2_quote(path, router, amntIn);
        uint256 amntOut = _swap_v2(router, path, amntIn, amntOutQuote, outReceiver, fromETH); // approve & execute swap
                
        // verifiy new balance of token received
        uint256 new_bal = IERC20(path[path.length -1]).balanceOf(outReceiver);
        require(new_bal >= amntOut, " _swap: receiver bal too low :{ ");
        
        return amntOut;
    }

    /* -------------------------------------------------------- */
    /* PRIVATE - DEX QUOTE SUPPORT                                    
    /* -------------------------------------------------------- */
    function _swap_v2_quote(address[] memory _path, address _dexRouter, uint256 _amntIn) private view returns (uint256) {
        uint256[] memory amountsOut = IUniswapV2Router02(_dexRouter).getAmountsOut(_amntIn, _path); // quote swap
        return amountsOut[amountsOut.length -1];
    }
    // v2: solidlycom, kyberswap, pancakeswap, sushiswap, uniswap v2, pulsex v1|v2, 9inch
    function _swap_v2(address router, address[] memory path, uint256 amntIn, uint256 amntOutMin, address outReceiver, bool fromETH) private returns (uint256) {
        IUniswapV2Router02 swapRouter = IUniswapV2Router02(router);
        
        IERC20(address(path[0])).approve(address(swapRouter), amntIn);
        uint deadline = block.timestamp + 300;
        uint[] memory amntOut;
        if (fromETH) {
            amntOut = swapRouter.swapExactETHForTokens{value: amntIn}(
                            amntOutMin,
                            path, //address[] calldata path,
                            outReceiver, // to
                            deadline
                        );
        } else {
            amntOut = swapRouter.swapExactTokensForTokens(
                            amntIn,
                            amntOutMin,
                            path, //address[] calldata path,
                            outReceiver, //  The address that will receive the output tokens after the swap. 
                            deadline
                        );
        }
        return uint256(amntOut[amntOut.length - 1]); // idx 0=path[0].amntOut, 1=path[1].amntOut, etc.
    }

    /* -------------------------------------------------------- */
    /* PUBLIC
    /* -------------------------------------------------------- */
    function _perc_total_supply_owned(address _token, address _account) external view returns (uint64) {
        uint256 accountBalance = IERC20(_token).balanceOf(_account);
        uint256 totalSupply = IERC20(_token).totalSupply();

        // Prevent division by zero by checking if totalSupply is greater than zero
        require(totalSupply > 0, "Total supply must be greater than zero");

        // Calculate the percentage (in basis points, e.g., 1% = 100 basis points)
        uint256 percentage = (accountBalance * 10000) / totalSupply;

        return _uint64_from_uint256(percentage); // Returns the percentage in basis points (e.g., 500 = 5%)
    }
    function _isAddressInArray(address _addr, address[] memory _addrArr) external pure returns(bool) {
        for (uint8 i = 0; i < _addrArr.length;){ // max array size = 255 (uin8 loop)
            if (_addrArr[i] == _addr)
                return true;
            unchecked {i++;}
        }
        return false;
    }
    function _genTokenNameSymbol(address _maker, uint256 _markNum, uint16 _resultNum, string calldata _nameSeed, string calldata _symbSeed) external pure returns(string memory, string memory) { 
        // Concatenate to form symbol & name
        // string memory last4 = _getLast4Chars(_maker);
        // Convert the last 2 bytes (4 characters) of the address to a string
        bytes memory addrBytes = abi.encodePacked(_maker);
        bytes memory last4 = new bytes(4);

        last4[0] = addrBytes[18];
        last4[1] = addrBytes[19];
        last4[2] = addrBytes[20];
        last4[3] = addrBytes[21];

        // return string(last4);
        string memory tokenSymbol = string(abi.encodePacked(_nameSeed, last4, _markNum, string(abi.encodePacked(_resultNum))));
        string memory tokenName = string(abi.encodePacked(_symbSeed, " ", last4, "-", _markNum, "-", string(abi.encodePacked(_resultNum))));
        return (tokenName, tokenSymbol);
    }
    function _validNonWhiteSpaceString(string calldata _s) external pure returns(bool) {
        for (uint8 i=0; i < bytes(_s).length;) {
            if (bytes(_s)[i] != 0x20) {
                // Found a non-space character, return true
                return true; 
            }
            unchecked {
                i++;
            }
        }

        // found string with all whitespaces as chars
        return false;
    }
    function _generateAddressHash(address host, string memory uid) external pure returns (address) {
        // Concatenate the address and the string, and then hash the result
        bytes32 hash = keccak256(abi.encodePacked(host, uid));

        // LEFT OFF HERE ... is this a bug? 'uint160' ? shoudl be uint16? 
        address generatedAddress = address(uint160(uint256(hash)));
        return generatedAddress;
    }
    function _perc_of_uint64(uint32 _perc, uint64 _num) external pure returns (uint64) {
        require(_perc <= 10000, 'err: invalid percent');
        // return _perc_of_uint64_unchecked(_perc, _num);
        return (_num * uint64(_perc * 100)) / 1000000; // chatGPT equation
    }
    function _perc_of_uint64_unchecked(uint32 _perc, uint64 _num) external pure returns (uint64) {
        // require(_perc <= 10000, 'err: invalid percent');
        // uint32 aux_perc = _perc * 100; // Multiply by 100 to accommodate decimals
        // uint64 result = (_num * uint64(aux_perc)) / 1000000; // chatGPT equation
        // return result; // uint64 max USD: ~18T -> 18,446,744,073,709.551615 (6 decimals)

        // NOTE: more efficient with no local vars allocated
        return (_num * uint64(uint32(_perc) * 100)) / 1000000; // chatGPT equation
    }
    function _uint64_from_uint256(uint256 value) public pure returns (uint64) {
        require(value <= type(uint64).max, "Value exceeds uint64 range");
        uint64 convertedValue = uint64(value);
        return convertedValue;
    }
    function _normalizeStableAmnt(uint8 _fromDecimals, uint256 _usdAmnt, uint8 _toDecimals) external pure returns (uint256) {
        require(_fromDecimals > 0 && _toDecimals > 0, 'err: invalid _from|toDecimals');
        if (_usdAmnt == 0) return _usdAmnt; // fix to allow 0 _usdAmnt (ie. no need to normalize)
        if (_fromDecimals == _toDecimals) {
            return _usdAmnt;
        } else {
            if (_fromDecimals > _toDecimals) { // _fromDecimals has more 0's
                uint256 scalingFactor = 10 ** (_fromDecimals - _toDecimals); // get the diff
                return _usdAmnt / scalingFactor; // decrease # of 0's in _usdAmnt
            }
            else { // _fromDecimals has less 0's
                uint256 scalingFactor = 10 ** (_toDecimals - _fromDecimals); // get the diff
                return _usdAmnt * scalingFactor; // increase # of 0's in _usdAmnt
            }
        }
    }
    function _addAddressToArraySafe(address _addr, address[] memory _arr, bool _safe) external pure returns (address[] memory) {
        // NOTE: no require checks needed
        return _addAddressToArraySafe_p(_addr, _arr, _safe);
    }
    function _remAddressFromArray(address _addr, address[] memory _arr) external pure returns (address[] memory) {
        // NOTE: no require checks needed
        return _remAddressFromArray_p(_addr, _arr);
    }

    /* -------------------------------------------------------- */
    /* PRIVATE
    /* -------------------------------------------------------- */
    function _getLast4Chars(address _addr) private pure returns (string memory) {
        // Convert the last 2 bytes (4 characters) of the address to a string
        bytes memory addrBytes = abi.encodePacked(_addr);
        bytes memory last4 = new bytes(4);

        last4[0] = addrBytes[18];
        last4[1] = addrBytes[19];
        last4[2] = addrBytes[20];
        last4[3] = addrBytes[21];

        return string(last4);
    }
    function _addAddressToArraySafe_p(address _addr, address[] memory _arr, bool _safe) private pure returns (address[] memory) {
        if (_addr == address(0)) { return _arr; }

        // safe = remove first (no duplicates)
        if (_safe) { _arr = _remAddressFromArray_p(_addr, _arr); }

        // perform add to memory array type w/ static size
        address[] memory _ret = new address[](_arr.length+1);
        for (uint i=0; i < _arr.length;) { _ret[i] = _arr[i]; unchecked {i++;}}
        _ret[_ret.length-1] = _addr;
        return _ret;
    }
    function _remAddressFromArray_p(address _addr, address[] memory _arr) private pure returns (address[] memory) {
        if (_addr == address(0) || _arr.length == 0) { return _arr; }
        
        // NOTE: remove algorithm does NOT maintain order & only removes first occurance
        for (uint i = 0; i < _arr.length;) {
            if (_addr == _arr[i]) {
                _arr[i] = _arr[_arr.length - 1];
                assembly { // reduce memory _arr length by 1 (simulate pop)
                    mstore(_arr, sub(mload(_arr), 1))
                }
                return _arr;
            }

            unchecked {i++;}
        }
        return _arr;
    }
}