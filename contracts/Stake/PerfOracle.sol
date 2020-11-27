pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "./ClusterRegistry.sol";

contract PerfOracle is Ownable {

    mapping(address => uint256) clusterRewards;

    uint256 rewardPerEpoch;
    uint256 payoutDenomination;

    address clusterRegistryAddress;
    ERC20 MPOND;

    uint256 public currentEpoch;

    modifier onlyClusterRegistry() {
        require(msg.sender == clusterRegistryAddress);
        _;
    }

    constructor(
        address _owner, 
        address _clusterRegistryAddress, 
        uint256 _rewardPerEpoch, 
        address _MPONDAddress,
        uint256 _payoutDenomination) 
        public 
        Ownable() 
    {
        initialize(_owner);
        clusterRegistryAddress = _clusterRegistryAddress;
        rewardPerEpoch = _rewardPerEpoch;
        MPOND = ERC20(_MPONDAddress);
        payoutDenomination = _payoutDenomination;
    }

    function feed(address[] memory _clusters, uint256[] memory _payouts) public onlyOwner {
        for(uint256 i=0; i < _clusters.length; i++) {
            clusterRewards[_clusters[i]] += rewardPerEpoch*_payouts[i]/payoutDenomination;
        }
    }

    // only cluster registry is necessary because the rewards 
    // should be updated in the cluster registry against the cluster
    function claimReward(address _cluster) public onlyClusterRegistry returns(uint256) {
        uint256 pendingRewards = clusterRewards[_cluster];
        if(pendingRewards > 0) {
            transferRewards(clusterRegistryAddress, pendingRewards);
            delete clusterRewards[_cluster];
        }
        return pendingRewards;
    }

    function transferRewards(address _to, uint256 _amount) internal {
        MPOND.transfer(_to, _amount);
    }
}