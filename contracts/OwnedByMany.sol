pragma solidity ^0.4.11;

/// @dev `OwnedByMany` is a base level contract that assigns owners that can be
///  later changed
contract OwnedByMany {

    mapping(address => bool) public owners;

	/// @dev  only addresses in owners can call a function with this modifier
    modifier onlyOwner() {
        require(owners[msg.sender]);
        _;
    }

    /// @notice The Constructor assigns the message sender as an owner
    constructor() public {
	    owners[msg.sender] = true;
    }

    /// @param addr  The address of the new owner
    function addOwner(address addr) public onlyOwner {
	    owners[addr] = true;
    }

    /// @param addr  The address of the owner to be removed
	function removeOwner(address addr) public onlyOwner {
	    require(msg.sender != addr);
		owners[addr] = false;
	}
}
