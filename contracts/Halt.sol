pragma solidity ^0.4.11;

import './OwnedByMany.sol';

contract Halt is OwnedByMany {

    bool public halted = true;

    modifier notHalted() {
        require(!halted);
        _;
    }

    modifier isHalted() {
        require(halted);
        _;
    }

    /// @notice function Emergency situation that requires
    /// @notice contribution period to stop or not.
    function setHalt(bool halt)
        public
        onlyOwner
    {
        halted = halt;
    }
}
