// // SPDX-License-Identifier: MIT

// pragma solidity =0.8.10;

// import "@openzeppelin/contracts/token/erc20/IERC20.sol";
// import "@openzeppelin/contracts/token/erc20/extensions/IERC20Metadata.sol";
// import "@openzeppelin/contracts/utils/Context.sol";
// import "@bonga-bera-capital/bera-storage/interfaces/IBeraStorage.sol";
// import "@bonga-bera-capital/bera-storage/contracts/mixins/BeraStorageMixin.sol";

// import "../BeraERC20.sol";

// contract MyEternalERC20 is BeraStorageMixin, BeraERC20 {

//     constructor(string memory name_, string memory symbol_, address storageAddress) 
//         BeraERC20(name_, symbol_) 
//         BeraStorageMixin(storageAddress)
//     {
//         return;
//     }

//     function BeraStorage() internal view virtual override returns(IBeraStorage) {
//         return BeraStorage_;
//     }

// } 