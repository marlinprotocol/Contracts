pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";

contract ClusterRegistry is Initializable, Ownable {

    using SafeMath for uint256;

    uint256 constant UINT256_MAX = ~uint256(0);

    struct Cluster {
        uint256 commission;
        address rewardAddress;
        address clientKey;
        bytes32 networkId; // keccak256("ETH") // token ticker for anyother chain in place of ETH
        Status status;
    }

    struct Lock {
        uint256 unlockBlock;
        uint256 iValue;
    }

    mapping(address => Cluster) clusters;

    mapping(bytes32 => Lock) public locks;
    mapping(bytes32 => uint256) public lockWaitTime;
    bytes32 constant COMMISSION_LOCK_SELECTOR = keccak256("COMMISSION_LOCK");
    bytes32 constant SWITCH_NETWORK_LOCK_SELECTOR = keccak256("SWITCH_NETWORK_LOCK");
    bytes32 constant UNREGISTER_LOCK_SELECTOR = keccak256("UNREGISTER_LOCK");

    enum Status{NOT_REGISTERED, REGISTERED}

    mapping(address => address) public clientKeys;

    event ClusterRegistered(
        address cluster, 
        bytes32 networkId, 
        uint256 commission, 
        address rewardAddress, 
        address clientKey
    );
    event CommissionUpdateRequested(address cluster, uint256 commissionAfterUpdate, uint256 effectiveBlock);
    event CommissionUpdated(address cluster, uint256 updatedCommission, uint256 updatedAt);
    event RewardAddressUpdated(address cluster, address updatedRewardAddress);
    event NetworkSwitchRequested(address cluster, bytes32 networkId, uint256 effectiveBlock);
    event NetworkSwitched(address cluster, bytes32 networkId, uint256 updatedAt);
    event ClientKeyUpdated(address cluster, address clientKey);
    event ClusterUnregisterRequested(address cluster, uint256 effectiveBlock);
    event ClusterUnregistered(address cluster, uint256 updatedAt);
    event LockTimeUpdated(bytes32 selector, uint256 prevLockTime, uint256 updatedLockTime);

    function initialize(bytes32[] memory _selectors, uint256[] memory _lockWaitTimes, address _owner) 
        public 
        initializer
    {
        require(
            _selectors.length == _lockWaitTimes.length,
            "CR:I-Invalid params"
        );
        for(uint256 i=0; i < _selectors.length; i++) {
            lockWaitTime[_selectors[i]] = _lockWaitTimes[i];
            emit LockTimeUpdated(_selectors[i], 0, _lockWaitTimes[i]);
        }
        super.initialize(_owner);
    }

    function updateLockWaitTime(bytes32 _selector, uint256 _updatedWaitTime) public onlyOwner {
        emit LockTimeUpdated(_selector, lockWaitTime[_selector], _updatedWaitTime);
        lockWaitTime[_selector] = _updatedWaitTime; 
    }

    function register(
        bytes32 _networkId, 
        uint256 _commission, 
        address _rewardAddress, 
        address _clientKey
    ) public returns(bool) {
        // This happens only when the data of the cluster is registered or it wasn't registered before
        require(
            !isClusterValid(msg.sender), 
            "CR:R-Cluster is already registered"
        );
        require(_commission <= 100, "CR:R-Commission more than 100%");
        require(clientKeys[_clientKey] ==  address(0), "CR:R - Client key is already used");
        clusters[msg.sender].commission = _commission;
        clusters[msg.sender].rewardAddress = _rewardAddress;
        clusters[msg.sender].clientKey = _clientKey;
        clusters[msg.sender].networkId = _networkId;
        clusters[msg.sender].status = Status.REGISTERED;

        clientKeys[_clientKey] = msg.sender;
        
        emit ClusterRegistered(msg.sender, _networkId, _commission, _rewardAddress, _clientKey);
    }

    function updateCluster(uint256 _commission, bytes32 _networkId, address _rewardAddress, address _clientKey) public {
        if(_networkId != bytes32(0)) {
            switchNetwork(_networkId);
        }
        if(_rewardAddress != address(0)) {
            updateRewardAddress(_rewardAddress);
        }
        if(_clientKey != address(0)) {
            updateClientKey(_clientKey);
        }
        if(_commission != UINT256_MAX) {
            updateCommission(_commission);
        }
    }

    function updateCommission(uint256 _commission) public {
        require(
            isClusterValid(msg.sender),
            "CR:UCM-Cluster not registered"
        );
        require(_commission <= 100, "CR:UCM-Commission more than 100%");
        bytes32 lockId = keccak256(abi.encodePacked(COMMISSION_LOCK_SELECTOR, msg.sender));
        uint256 unlockBlock = locks[lockId].unlockBlock;
        require(
            unlockBlock < block.number, 
            "CR:UCM-Commission update in progress"
        );
        if(unlockBlock != 0) {
            uint256 currentCommission = locks[lockId].iValue;
            clusters[msg.sender].commission = currentCommission;
            emit CommissionUpdated(msg.sender, currentCommission, unlockBlock);
        }
        uint256 updatedUnlockBlock = block.number.add(lockWaitTime[COMMISSION_LOCK_SELECTOR]);
        locks[lockId] = Lock(updatedUnlockBlock, _commission);
        emit CommissionUpdateRequested(msg.sender, _commission, updatedUnlockBlock);
    }

    function switchNetwork(bytes32 _networkId) public {
        require(
            isClusterValid(msg.sender),
            "CR:SN-Cluster not registered"
        );
        bytes32 lockId = keccak256(abi.encodePacked(SWITCH_NETWORK_LOCK_SELECTOR, msg.sender));
        uint256 unlockBlock = locks[lockId].unlockBlock;
        require(
            unlockBlock < block.number,
            "CR:SN-Network switch in progress"
        );
        if(unlockBlock != 0) {
            bytes32 currentNetwork = bytes32(locks[lockId].iValue);
            clusters[msg.sender].networkId = currentNetwork;
            emit NetworkSwitched(msg.sender, currentNetwork, unlockBlock);
        }
        uint256 updatedUnlockBlock = block.number.add(lockWaitTime[SWITCH_NETWORK_LOCK_SELECTOR]);
        locks[lockId] = Lock(updatedUnlockBlock, uint256(_networkId));
        emit NetworkSwitchRequested(msg.sender, _networkId, updatedUnlockBlock);
    }

    function updateRewardAddress(address _rewardAddress) public {
        require(
            isClusterValid(msg.sender),
            "CR:URA-Cluster not registered"
        );
        clusters[msg.sender].rewardAddress = _rewardAddress;
        emit RewardAddressUpdated(msg.sender, _rewardAddress);
    }

    function updateClientKey(address _clientKey) public {
        // TODO: Add delay to client key updates as well
        require(
            isClusterValid(msg.sender),
            "CR:UCK-Cluster not registered"
        );
        require(clientKeys[_clientKey] ==  address(0), "CR:UCK - Client key is already used");
        delete clientKeys[clusters[msg.sender].clientKey];
        clusters[msg.sender].clientKey = _clientKey;
        clientKeys[_clientKey] = msg.sender;
        emit ClientKeyUpdated(msg.sender, _clientKey);
    }

    function unregister() public {
        require(
            clusters[msg.sender].status != Status.NOT_REGISTERED,
            "CR:UR-Cluster not registered"
        );
        bytes32 lockId = keccak256(abi.encodePacked(UNREGISTER_LOCK_SELECTOR, msg.sender));
        uint256 unlockBlock = locks[lockId].unlockBlock;
        require(
            unlockBlock < block.number,
            "CR:UR-Unregistration already in progress"
        );
        if(unlockBlock != 0) {
            clusters[msg.sender].status = Status.NOT_REGISTERED;
            emit ClusterUnregistered(msg.sender, unlockBlock);
            delete clientKeys[clusters[msg.sender].clientKey];
            delete locks[lockId];
            delete locks[keccak256(abi.encodePacked(COMMISSION_LOCK_SELECTOR, msg.sender))];
            delete locks[keccak256(abi.encodePacked(SWITCH_NETWORK_LOCK_SELECTOR, msg.sender))];
            return;
        }
        uint256 updatedUnlockBlock = block.number.add(lockWaitTime[UNREGISTER_LOCK_SELECTOR]);
        locks[lockId] = Lock(updatedUnlockBlock, 0);
        emit ClusterUnregisterRequested(msg.sender, updatedUnlockBlock);
    }

    function isClusterValid(address _cluster) public returns(bool) {
        bytes32 lockId = keccak256(abi.encodePacked(UNREGISTER_LOCK_SELECTOR, _cluster));
        uint256 unlockBlock = locks[lockId].unlockBlock;
        if(unlockBlock != 0 && unlockBlock < block.number) {
            clusters[_cluster].status = Status.NOT_REGISTERED;
            delete clientKeys[clusters[_cluster].clientKey];
            emit ClusterUnregistered(_cluster, unlockBlock);
            delete locks[lockId];
            delete locks[keccak256(abi.encodePacked(COMMISSION_LOCK_SELECTOR, msg.sender))];
            delete locks[keccak256(abi.encodePacked(SWITCH_NETWORK_LOCK_SELECTOR, msg.sender))];
            return false;
        }
        return (clusters[_cluster].status != Status.NOT_REGISTERED);    // returns true if the status is registered
    }

    function getCommission(address _cluster) public returns(uint256) {
        bytes32 lockId = keccak256(abi.encodePacked(COMMISSION_LOCK_SELECTOR, _cluster));
        uint256 unlockBlock = locks[lockId].unlockBlock;
        if(unlockBlock != 0 && unlockBlock < block.number) {
            uint256 currentCommission = locks[lockId].iValue;
            clusters[_cluster].commission = currentCommission;
            emit CommissionUpdated(_cluster, currentCommission, unlockBlock);
            delete locks[lockId];
            return currentCommission;
        }
        return clusters[_cluster].commission;
    }

    function getNetwork(address _cluster) public returns(bytes32) {
        bytes32 lockId = keccak256(abi.encodePacked(SWITCH_NETWORK_LOCK_SELECTOR, _cluster));
        uint256 unlockBlock = locks[lockId].unlockBlock;
        if(unlockBlock != 0 && unlockBlock < block.number) {
            bytes32 currentNetwork = bytes32(locks[lockId].iValue);
            clusters[msg.sender].networkId = currentNetwork;
            emit NetworkSwitched(msg.sender, currentNetwork, unlockBlock);
            delete locks[lockId];
            return currentNetwork;
        }
        return clusters[_cluster].networkId;
    }

    function getRewardAddress(address _cluster) public view returns(address) {
        return clusters[_cluster].rewardAddress;
    }

    function getClientKey(address _cluster) public view returns(address) {
        return clusters[_cluster].clientKey;
    }

    function getCluster(address _cluster) public returns(
        uint256 commission, 
        address rewardAddress, 
        address clientKey, 
        bytes32 networkId, 
        bool isValidCluster
    ) {
        return (
            getCommission(_cluster), 
            clusters[_cluster].rewardAddress, 
            clusters[_cluster].clientKey, 
            getNetwork(_cluster), 
            isClusterValid(_cluster)
        );
    }

    function addClientKeys(address[] memory _clusters) public onlyOwner {
        for(uint256 i=0; i < _clusters.length; i++) {
            address _clientKey = clusters[_clusters[i]].clientKey;
            require(_clientKey != address(0), "CR:ACK - Cluster has invalid client key");
            clientKeys[_clientKey] = _clusters[i];
        }
    }
}
