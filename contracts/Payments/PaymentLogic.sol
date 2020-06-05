pragma solidity >=0.4.21 <0.7.0;
pragma experimental ABIEncoderV2;

import "../Stake/StakeLogic.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";


contract PaymentLogic is Initializable, StakeLogic {
    using BytesLib for bytes;
    struct Witness {
        address relayer;
        uint64 nonce;
        uint64 relayerFee;
        uint64 timestamp;
        Signature receiverSignature;
        Signature relayerSignature;
    }

    struct Signature {
        bytes32 hash;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Details {
        address sender;
        uint256 timestamp;
        uint256 amount;
    }

    mapping(bytes32 => Details) public unlockRequests; // bytes32 => (sender, timestamp, amount)

    event UnlockRequested(
        bytes32 id,
        address sender,
        uint256 time,
        uint256 amount
    );

    event UnlockRequestSealed(bytes32 id, bool changed);

    function initialize(address _token) public initializer {
        StakeLogic.initialize(_token);
    }

    function unlock(uint256 _amount) public returns (bytes32) {
        require(
            lockedBalances[msg.sender] >= _amount,
            "Amount exceeds lockedBalance"
        );
        bytes32 hash = keccak256(
            // solhint-disable-next-line not-rely-on-time
            abi.encode(msg.sender, block.timestamp, _amount)
        );
        unlockRequests[hash].sender = msg.sender;
        // solhint-disable-next-line not-rely-on-time
        unlockRequests[hash].timestamp = block.timestamp;
        unlockRequests[hash].amount = unlockRequests[hash].amount.add(_amount);
        // solhint-disable-next-line not-rely-on-time
        emit UnlockRequested(hash, msg.sender, block.timestamp, _amount);
        return hash;
    }

    function sealUnlockRequest(bytes32 _id) public returns (bool) {
        require(
            unlockRequests[_id].sender == msg.sender,
            "You cannot seal this request"
        );
        // solhint-disable-next-line not-rely-on-time
        if (unlockRequests[_id].timestamp + 86400 > block.timestamp) {
            emit UnlockRequestSealed(_id, false);
            return false;
        }

        lockedBalances[msg.sender] = lockedBalances[msg.sender].sub(
            unlockRequests[_id].amount
        );
        unlockedBalances[msg.sender] = unlockedBalances[msg.sender].add(
            unlockRequests[_id].amount
        );
        delete (unlockRequests[_id]);
        emit UnlockRequestSealed(_id, true);
        return true;
    }

    event PayWitness(address sender, uint256 amount, bool paid);

    function isWinning(bytes32 data) public pure returns (bool) {
        if (bytes1(data[0]) != bytes1(0)) {
            return (true);
        }
        return (false);
    }

    // function payForWitness(SignedWitness memory _signedWitness, uint256 _amount)
    //     public
    //     returns (bool)
    // {
    //     require(
    //         lockedBalances[msg.sender] >= _amount,
    //         "User doesn't have enough locked balance"
    //     );

    //     if (isWinning(_signedWitness.signature) == false) {
    //         emit PayWitness(msg.sender, _amount, false);
    //         return false;
    //     }

    //     lockedBalances[msg.sender] = lockedBalances[msg.sender].sub(
    //         _signedWitness.witness.relayerFraction * _amount
    //     );

    //     unlockedBalances[_signedWitness.witness
    //             .relayer] = unlockedBalances[_signedWitness.witness
    //             .relayer]
    //             .add(_signedWitness.witness.relayerFraction * _amount);

    //     emit PayWitness(msg.sender, _amount, true);
    //     return true;
    // }

    function payForWitness2(bytes calldata _witnessData)
        external
        returns (bool)
    {
        Witness memory witness = getWitness(_witnessData);

        address receiver = ecrecover(
            witness.receiverSignature.hash,
            witness.receiverSignature.v,
            witness.receiverSignature.r,
            witness.receiverSignature.s
        );
        address relayer = ecrecover(
            witness.relayerSignature.hash,
            witness.relayerSignature.v,
            witness.relayerSignature.r,
            witness.relayerSignature.s
        );

        require(receiver != address(0), "Receiver address should be valid");
        require(relayer != address(0), "Relayer address should be valid");

        require(
            lockedBalances[msg.sender] >= witness.relayerFee,
            "User doesn't have enough locked balance"
        );

        if (isWinning(witness.receiverSignature.r) == false) {
            emit PayWitness(msg.sender, witness.relayerFee, false);
            return false;
        }

        lockedBalances[msg.sender] = lockedBalances[msg.sender].sub(
            witness.relayerFee
        );

        unlockedBalances[witness.relayer] = unlockedBalances[witness.relayer]
            .add(witness.relayerFee);

        emit PayWitness(msg.sender, witness.relayerFee, true);
        return true;
    }

    function getWitness(bytes memory _witnessData)
        public
        returns (Witness memory witness)
    {
        address relayerAddress = _witnessData.slice(0, 20).toAddress(0);
        uint64 nonce = _witnessData.slice(20, 8).toUint64(0);
        uint64 relayerFee = _witnessData.slice(28, 8).toUint64(0);
        uint64 timestamp = _witnessData.slice(36, 8).toUint64(0);
        Signature memory receiver = getSignature(
            _witnessData.slice(0, 109),
            44
        );
        Signature memory relayer = getSignature(
            _witnessData.slice(0, 174),
            109
        );
        Witness memory witness = Witness(
            relayerAddress,
            nonce,
            relayerFee,
            timestamp,
            receiver,
            relayer
        );
        return witness;
    }

    function getSignature(bytes memory _data, uint256 dataLength)
        internal
        pure
        returns (Signature memory)
    {
        //Image prefix to be decided by the team
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 messageHash = keccak256(
            abi.encodePacked(_data.slice(0, dataLength))
        );
        bytes32 _hash1 = keccak256(abi.encodePacked(prefix, messageHash));
        uint8 _v1 = _data.slice(dataLength, 1).toUint8(0);
        bytes32 _r1 = _data.slice(dataLength + 1, 32).toBytes32(0);
        bytes32 _s1 = _data.slice(dataLength + 33, 32).toBytes32(0);
        Signature memory sig = Signature(_hash1, _v1, _r1, _s1);
        return sig;
    }

    uint256[50] private ______gap;
}
