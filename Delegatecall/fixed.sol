// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// FIX: We separate proxy storage and logic storage using the EIP-1967 Unstructured Storage pattern.
// We also ensure that sensitive functions in the logic contract have proper access control.

contract SecuredLib {
    address public owner;

    // The logic contract needs to be initialized securely
    function initialize() public {
        require(owner == address(0), "Already initialized");
        owner = msg.sender;
    }

    // Now, not just anyone can take ownership. 
    // They must pass an authorization check (or we just remove the backdoor).
    function updateOwner(address _newOwner) public {
        require(msg.sender == owner, "Only owner can update");
        owner = _newOwner;
    }
}

contract SecuredProxy {
    // We do NOT declare state variables directly here like 'address public owner;'
    // Instead, we use specific, random storage slots to hold our proxy data.
    // This entirely prevents storage collisions.

    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    constructor(address _implementation) {
        _setAdmin(msg.sender);
        _setImplementation(_implementation);
    }

    // Helper to write the admin address to the specific slot
    function _setAdmin(address _admin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, _admin)
        }
    }

    // Helper to read the admin address from the specific slot
    function getAdmin() public view returns (address admin) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }
    }

    function _setImplementation(address _implementation) private {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, _implementation)
        }
    }

    function getImplementation() public view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    // Only the proxy admin can upgrade the logic contract
    function upgradeTo(address _newImplementation) external {
        require(msg.sender == getAdmin(), "Not admin");
        _setImplementation(_newImplementation);
    }

    receive() external payable {}

    fallback() external payable {
        address _impl = getImplementation();
        require(_impl != address(0), "Implementation not set");

        // The delegatecall is now safer because:
        // 1. The proxy's vital variables (admin, implementation) are hidden in random slots.
        // 2. The logic contract's state starts at slot 0 without colliding with the proxy.
        // 3. The logic contract itself is secured (no unprotected pwn() function).
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}
