/* SPDX-License-Identifier: MIT */
pragma solidity =0.8.10;

/* Package Imports */
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {PRBMathUD60x18} from "@hifi-finance/prb-math/contracts/PRBMathUD60x18.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BeraERC20InterestBearing is ERC20 {
    using PRBMathUD60x18 for uint256;

    uint256 internal _totalSupplyInternal; // UD60x18
    uint256 internal _scalingFactorBase; // UD60x18
    uint256 internal _blockOfLastRateUpdate;
    uint256 internal _compoundingPeriodsPerYear;
    uint256 internal _apr; // UD60x18
    uint256 internal _apy; // UD60x18

    mapping(address => uint256) private internalBalances;
    mapping(address => mapping(address => uint256)) private approvedInternalBalances;

    constructor(string memory inName, string memory inSymbol) ERC20(inName, inSymbol) {
        _blockOfLastRateUpdate = block.number;
        _scalingFactorBase = 1e18;
    }

    //=================================================================================================================
    // Public Functions
    //=================================================================================================================
        
    uint256 internal constant BLOCKS_PER_YEAR = 2_308_380; 

    function scalingFactor() public view returns (uint256) {
        return
            _scalingFactorBase.mul(
                (1e18 + interestPerPeriod()).pow((relativeCurrentBlock()) / blocksPerCompoundingPeriod())
            );
    }

    function apr() public view returns (uint256) {
        return _apr;
    }

    //=================================================================================================================
    // External Functions
    //=================================================================================================================

    function updateApr(uint256 newApr) external virtual {
        _blockOfLastRateUpdate = block.number;
        _scalingFactorBase = scalingFactor();
        _apr = newApr;
    }

    function apy() external view returns (uint256) {
        return (1e18 + interestPerPeriod()).pow(periodsPerYear().fromUint()) - 1e18;
    }

    //=================================================================================================================
    // Internal Functions
    //=================================================================================================================

    function relativeCurrentBlock() internal view returns (uint256) {
        return block.number - _blockOfLastRateUpdate;
    }

    function interestPerPeriod() internal view returns (uint256) {
        return apr().div(periodsPerYear().fromUint());
    }

    function periodsPerYear() internal view returns (uint256) {
        return _compoundingPeriodsPerYear;
    }

    function blocksPerCompoundingPeriod() internal view returns (uint256) {
        return BLOCKS_PER_YEAR / _compoundingPeriodsPerYear;
    }

    function internalValueOf(uint256 amount) internal view returns (uint256) {
        return amount.div(scalingFactor());
    }

    function internalBalanceOf(address user) internal view returns (uint256) {
        return internalBalances[user];
    }

    //=================================================================================================================
    // ERC20 Overrides
    //=================================================================================================================

    function totalSupply() public view override(ERC20) returns (uint256) {
        return _totalSupplyInternal.mul(scalingFactor());
    }

    function balanceOf(address user) public view override returns (uint256) {
        return (internalBalanceOf(user).mul(scalingFactor()));
    }

    function _mint(address inUser, uint256 inAmount) internal override(ERC20) {
        internalBalances[inUser] = internalBalances[inUser] + internalValueOf(inAmount);
        _totalSupplyInternal = _totalSupplyInternal + inAmount;
    }

    function _burnFrom(address inUser, uint256 inAmount) internal {
        internalBalances[inUser] = internalBalances[inUser] - internalValueOf(inAmount);
        _totalSupplyInternal = _totalSupplyInternal - inAmount;
    }

    function transfer(address toUser, uint256 inAmount) public override returns (bool) {
        uint256 internalValue = internalValueOf(inAmount);
        internalBalances[msg.sender] = internalBalances[msg.sender] - internalValue;
        internalBalances[toUser] = internalBalances[toUser] + internalValue;
        emit Transfer(msg.sender, toUser, inAmount);
        return true;
    }

    function allowance(address inOwner, address inSpender) public view override returns (uint256) {
        return approvedInternalBalances[inOwner][inSpender];
    }

    function transferFrom(
        address fromUser,
        address toUser,
        uint256 inAmount
    ) public override returns (bool) {
        approvedInternalBalances[fromUser][msg.sender] = approvedInternalBalances[fromUser][msg.sender] - inAmount;
        emit Approval(fromUser, msg.sender, approvedInternalBalances[fromUser][msg.sender]);

        uint256 internalAmount = internalValueOf(inAmount);
        internalBalances[fromUser] = internalBalances[fromUser] - internalAmount;
        internalBalances[toUser] = internalBalances[toUser] + internalAmount;
        emit Transfer(fromUser, toUser, inAmount);
        return true;
    }

    function approve(address inSpender, uint256 inAmount) public override returns (bool) {
        approvedInternalBalances[msg.sender][inSpender] = inAmount;
        emit Approval(msg.sender, inSpender, inAmount);
        return true;
    }

    function _approve(
        address inOwner,
        address inSpender,
        uint256 inAmount
    ) internal virtual override {
        approvedInternalBalances[inOwner][inSpender] = inAmount;
        emit Approval(inOwner, inSpender, inAmount);
    }

    function increaseAllowance(address inSpender, uint256 addedValue) public override returns (bool) {
        uint256 internalAmount = internalValueOf(addedValue);
        approvedInternalBalances[msg.sender][inSpender] =
            approvedInternalBalances[msg.sender][inSpender] +
            internalAmount;
        emit Approval(msg.sender, inSpender, approvedInternalBalances[msg.sender][inSpender]);
        return true;
    }

    function decreaseAllowance(address inSpender, uint256 subtractedValue) public override returns (bool) {
        uint256 internalAmount = internalValueOf(subtractedValue);
        uint256 oldValue = approvedInternalBalances[msg.sender][inSpender];
        if (subtractedValue < oldValue) {
            approvedInternalBalances[msg.sender][inSpender] = 0;
        } else {
            approvedInternalBalances[msg.sender][inSpender] = oldValue - internalAmount;
        }
        emit Approval(msg.sender, inSpender, approvedInternalBalances[msg.sender][inSpender]);
        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20) {
        super._afterTokenTransfer(from, to, amount);
    }
}
