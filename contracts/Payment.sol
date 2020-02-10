pragma solidity ^0.6.1;
pragma experimental ABIEncoderV2;
import "./Token.sol";

contract Payment{
    string public id;
    Token public token;

    struct Witness{
        address relayer; // peer.publicKey (in DATA.md)
        uint256 relayerFraction; // relayerFraction (in DATA.md)
        bytes relayerSignature; // self.privKey (in DATA.md)
    }

    struct SignedWitness{
        Witness[] witnessList;
        bytes signature;
    }

    Witness[] public witness;

    constructor(address _token) public {
        token = Token(_token);
    }

    struct Details{
        address sender;
        uint timestamp;
        uint256 amount;
    }

    event BalanceChanged(
        address sender
    );

    event UnlockRequested(
        address sender,
        uint time,
        uint256 amount
    );

    event UnlockRequestSealed(
        bytes32 id,
        bool changed
    );

    event Withdraw(
        address sender,
        uint256 amount,
        bool withdrawn
    );

    mapping(address => uint) public lockedBalances;
    mapping(bytes32 => Details) public unlockRequests; // string => (sender, timestamp, amount)
    mapping(address => uint) public unlockedBalances;


    function addEscrow(uint256 _amount) public{
        require(token.balanceOf(msg.sender) >= _amount,"Insufficient balance");
        token.approveContract(address(this), msg.sender, _amount);
    	lockedBalances[msg.sender] += _amount;
    	token.transferFrom(msg.sender, address(this), _amount);
    	emit BalanceChanged(msg.sender);
    }

    bytes32[] public allHashes;

    function unlock(uint256 _amount) public returns(bytes32){
        require(lockedBalances[msg.sender] >= _amount, "Amount exceeds lockedBalance");
        bytes32 hash = keccak256(abi.encode(msg.sender,block.timestamp, _amount));
    	unlockRequests[hash].sender = msg.sender;
        unlockRequests[hash].timestamp = block.timestamp;
        unlockRequests[hash].amount = _amount;
        allHashes.push(hash);
        emit UnlockRequested(msg.sender, block.timestamp, _amount);
    	return hash;
    }

    function sealUnlockRequest(bytes32 _id) public returns(bool){
        require(unlockRequests[_id].sender == msg.sender, "You cannot seal this request");

    	if(unlockRequests[_id].timestamp + 86400 > block.timestamp){
            emit UnlockRequestSealed(_id, false);
            return false;
        }
    	lockedBalances[msg.sender] -= unlockRequests[_id].amount;
    	unlockedBalances[msg.sender] += unlockRequests[_id].amount;
    	delete(unlockRequests[_id]);
        emit UnlockRequestSealed(_id, true);
    	return true;
    }

    function withdraw(uint256 _amount) public{
    	require(_amount <= unlockedBalances[msg.sender], "Amount greater than the unlocked amount");
    	unlockedBalances[msg.sender] -= _amount;
    	token.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount, true);
    }

    event PayWitness(
        address sender,
        uint256 amount,
        bool paid
    );

    function isWinning(bytes memory _witnessSignature) public pure returns(bool){
        if(byte(_witnessSignature[0]) == byte(0)){
            return(true);
        }
        return(false);
    }

    function payForWitness(SignedWitness memory _signedWitness, uint256 _amount) public returns(bool){

        require(lockedBalances[msg.sender] >= _amount, "User doesn't have enough locked balance");

    	if(isWinning(_signedWitness.signature) == false) {
            emit PayWitness(msg.sender, _amount, false);
            return false;
        }

        for(uint i = 0; i < _signedWitness.witnessList.length; i++){
    		lockedBalances[msg.sender] -= _signedWitness.witnessList[i].relayerFraction*_amount;

    		unlockedBalances[_signedWitness.witnessList[i].relayer] += _signedWitness.witnessList[i].relayerFraction*_amount;
        }

        emit PayWitness(msg.sender, _amount, true);
        return true;

    }

}