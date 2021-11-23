/* SPDX-License-Identifier: MIT */

pragma solidity =0.8.10;

abstract contract BeraERC20Keys {
    //=================================================================================================================
    // Declarations
    //=================================================================================================================

    _erc_20_keys internal erc_20_keys = _erc_20_keys("erc20.totalsupply", "erc20.balance");

    //=================================================================================================================
    // Definitions
    //=================================================================================================================

    struct _erc_20_keys {
        bytes totalsupply;
        bytes balance;
    }
}
