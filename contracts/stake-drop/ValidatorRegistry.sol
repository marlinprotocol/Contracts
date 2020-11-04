pragma solidity >=0.4.21 <0.7.0;

import "./StandardOracle.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";


contract ValidatorRegistry is StandardOracle {
    mapping(uint256 => mapping(bytes32 => bool)) validators;
    mapping(uint256 => bool) freezeValidators;
    mapping(uint256 => uint256) freezeTime;

    event AddValidator(uint256 indexed, bytes32 indexed);
    event RemoveValidator(uint256 indexed, bytes32 indexed);
    event FreezeValidatorEpoch(uint256 indexed);

    function isFrozen(uint256 _epoch) public view returns (bool) {
        if (freezeTime[_epoch] == 0) {
            return false;
        }
        return true;
    }

    function isValidator(uint256 _epoch, bytes32 _address)
        public
        view
        returns (bool)
    {
        return validators[_epoch][_address];
    }

    function getEpochEndTime(uint256 _epoch) public view returns (uint256) {
        // require(_epoch > 0 , "Epoch should be greater than zero");
        return freezeTime[_epoch];
    }

    function addValidator(uint256 _epoch, bytes32 _validatorAddress)
        public
        onlySource
        isEpochNotFrozen(_epoch)
        returns (bool)
    {
        if (validators[_epoch][_validatorAddress]) {
            return false;
        }
        validators[_epoch][_validatorAddress] = true;
        emit AddValidator(_epoch, _validatorAddress);
        return true;
    }

    function addValidatorsBulk(uint256 _epoch, bytes32[] memory _validators)
        public
        onlySource
        returns (bool)
    {
        for (uint256 index = 0; index < _validators.length; index++) {
            bool result = addValidator(_epoch, _validators[index]);
            require(result, "Failed adding bulk validators");
        }
        return true;
    }

    function removeValidator(uint256 _epoch, bytes32 _validatorAddress)
        public
        onlySource
        isEpochNotFrozen(_epoch)
        returns (bool)
    {
        validators[_epoch][_validatorAddress] = false;
        emit RemoveValidator(_epoch, _validatorAddress);
        return true;
    }

    function freezeEpoch(uint256 _epoch)
        public
        onlySource
        isEpochNotFrozen(_epoch)
        returns (bool)
    {
        freezeValidators[_epoch] = true;
        freezeTime[_epoch] = block.timestamp;
        emit FreezeValidatorEpoch(_epoch);
        return true;
    }

    modifier isEpochNotFrozen(uint256 _epoch) {
        require(
            freezeValidators[_epoch] == false,
            "Epoch should not be frozen for adding validators"
        );
        _;
    }
}