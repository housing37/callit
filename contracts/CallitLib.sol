// SPDX-License-Identifier: UNLICENSED
// inherited contracts
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // deploy
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// local _ $ npm install @openzeppelin/contracts
import "./node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./node_modules/@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "./ICallitLib.sol";

pragma solidity ^0.8.20;
library CallitLib {
    string public constant tVERSION = '1.0';
    address public constant TOK_WPLS = address(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);

    /* -------------------------------------------------------- */
    /* PUBLIC
    /* -------------------------------------------------------- */
    function _logMarketResultReview(address _maker, uint256 _markNum, ICallitLib.MARKET_REVIEW[] memory _makerReviews, bool _resultAgree) external view returns(ICallitLib.MARKET_REVIEW memory, uint64, uint64) {
        uint64 agreeCnt = 0;
        uint64 disagreeCnt = 0;
        uint64 reviewCnt = _uint64_from_uint256(_makerReviews.length);
        if (reviewCnt > 0) {
            agreeCnt = _makerReviews[reviewCnt-1].agreeCnt;
            disagreeCnt = _makerReviews[reviewCnt-1].disagreeCnt;
        }

        agreeCnt = _resultAgree ? agreeCnt+1 : agreeCnt;
        disagreeCnt = !_resultAgree ? disagreeCnt+1 : disagreeCnt;
        return (ICallitLib.MARKET_REVIEW(msg.sender, _resultAgree, _maker, _markNum, agreeCnt, disagreeCnt), agreeCnt, disagreeCnt);
    }
    // LEFT OFF HERE ... this needs to be changed around to match current design
    //  i think votes_held shoudl be an input parma and don't deal with decimals at all
    function _validVoteCount(uint256 _voterCallBal, uint64 _votesEarned, uint256 _voterLockTime, uint256 _markCreateTime) external pure returns(uint64) {
        // if indeed locked && locked before _mark start time, calc & return active vote count
        if (_voterLockTime > 0 && _voterLockTime <= _markCreateTime) {
            uint64 votes_earned = _votesEarned; // note: EARNED_CALL_VOTES stores uint64 type
            uint64 votes_held = _uint64_from_uint256(_voterCallBal);
            uint64 votes_active = votes_held >= votes_earned ? votes_earned : votes_held;
            return votes_active;
        }
        else
            return 0; // return no valid votes
    }
    function _addressIsMarketMakerOrCaller(address _addr, address _markMaker, address[] memory _resultOptionTokens) external view returns(bool, bool) {
        bool is_maker = _markMaker == _addr; // true = found maker
        bool is_caller = false;
        for (uint16 i = 0; i < _resultOptionTokens.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            is_caller = IERC20(_resultOptionTokens[i]).balanceOf(_addr) > 0; // true = found caller
            unchecked {i++;}
        }

        return (is_maker, is_caller);
    }
    function _getWinningVoteIdxForMarket(uint64[] memory _resultTokenVotes) external pure returns(uint16) {
        // travers mark.resultTokenVotes for winning idx
        //  NOTE: default winning index is 0 & ties will settle on lower index
        uint16 idxCurrHigh = 0;
        for (uint16 i = 0; i < _resultTokenVotes.length;) { // NOTE: MAX_RESULTS is type uint16 max = ~65K -> 65,535
            if (_resultTokenVotes[i] > _resultTokenVotes[idxCurrHigh])
                idxCurrHigh = i;
            unchecked {i++;}
        }
        return idxCurrHigh;
    }
    function _getAmountsForInitLP(uint256 _usdAmntLP, uint256 _resultOptionCnt, uint32 _tokPerUsd) external pure returns(uint64, uint256) {
        require (_usdAmntLP > 0 && _resultOptionCnt > 0 && _tokPerUsd > 0, ' uint == 0 :{} ');
        return (_uint64_from_uint256(_usdAmntLP / _resultOptionCnt), uint256((_usdAmntLP / _resultOptionCnt) * _tokPerUsd));
    }
    function _calculateTokensToMint(address _pairAddr, uint256 _usdTargetPrice) external view returns (uint256) {
        // NOTE: _usdTargetPrice should already be normalized/matched to decimals of reserve1 in _pairAddress

        // Assuming reserve0 is token and reserve1 is USD
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(_pairAddr).getReserves();

        uint256 usdCurrentPrice = uint256(reserve1) * 1e18 / uint256(reserve0);
        require(_usdTargetPrice < usdCurrentPrice, "Target price must be less than current price.");

        // Calculate the amount of tokens to mint
        uint256 tokensToMint = (uint256(reserve1) * 1e18 / _usdTargetPrice) - uint256(reserve0);

        return tokensToMint;
    }
    // Option 1: Estimate the price using reserves
    // function _estimateLastPriceForTCK(address _pairAddress, address _pairStable) private view returns (uint256) {
    function _estimateLastPriceForTCK(address _pairAddress) external view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(_pairAddress).getReserves();
        
        // Assuming token0 is the ERC20 token and token1 is the paired asset (e.g., ETH or a stablecoin)
        uint256 price = reserve1 * 1e18 / reserve0; // 1e18 for consistent decimals if token1 is ETH or a stablecoin
        
        // convert to contract '_usd_decimals()'
        // uint64 price_ret = CALLIT_LIB._uint64_from_uint256(CALLIT_LIB._normalizeStableAmnt(USD_STABLE_DECIMALS[_pairStable], price, _usd_decimals()));
        // return price_ret;
        return price;
    }
    function _perc_total_supply_owned(address _token, address _account) external view returns (uint64) {
        uint256 accountBalance = IERC20(_token).balanceOf(_account);
        uint256 totalSupply = IERC20(_token).totalSupply();

        // Prevent division by zero by checking if totalSupply is greater than zero
        require(totalSupply > 0, "Total supply must be greater than zero");

        // Calculate the percentage (in basis points, e.g., 1% = 100 basis points)
        uint256 percentage = (accountBalance * 10000) / totalSupply;

        return _uint64_from_uint256(percentage); // Returns the percentage in basis points (e.g., 500 = 5%)
    }
    // note: migrate to CallitLib
    function _deductFeePerc(uint64 _net_usdAmnt, uint16 _feePerc, uint64 _usdAmnt) external pure returns(uint64) {
        require(_feePerc <= 10000, ' invalid fee perc :p '); // 10000 = 100.00%
        return _net_usdAmnt - _perc_of_uint64(_feePerc, _usdAmnt);
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
    function _perc_of_uint64(uint32 _perc, uint64 _num) public pure returns (uint64) {
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