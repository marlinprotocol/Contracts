const ProxyC = artifacts.require("Proxy.sol")
const Logic = artifacts.require("Logic.sol")
const Logic2 = artifacts.require("Logic2.sol")

const initValue = 50;

var LogicContract;
var LogicContract2;
var ProxyContract;

contract("Capacity", function (accounts) {
    it("Deploy Logic/Logic2/Proxy Contracts", function(){
        return Logic.deployed().then(function(instance){
            LogicContract = instance;
            return;
        })
        .then(function(){
            return Logic2.deployed().then(function(instance){
                LogicContract2 = instance;
            })
        })
        .then(function(){
            return ProxyC.deployed(LogicContract.address).then(function(instance){
                ProxyContract = instance;
                return;
            }) 
        })
        .then(async function(){
            let tempProxy = await Logic.at(ProxyContract.address);
            return tempProxy.initialize(initValue).then(function(result){
                return;
            })
        })
    })
    
    it("Check Storage", function(){
        return Logic.at(ProxyContract.address).then( async function(instance){
            let value = await instance.get.call();
            assert.equal(value, initValue, "Value fetched from proxy should be equal to initValue")
            return;
        })
        .then(function(){
            return LogicContract.get.call().then(function(value){
                assert.equal(value, 0, "value store in logic contract state should be zero");
                return;
            })
        })
    })
    it("Update Logic Contract address and check values/storages", function(){
        return ProxyContract.updateLogic(LogicContract2.address).then(function(result){
            return;
        })
        .then(function(){
            return Logic.at(ProxyContract.address).then( async function(instance){
                let value = await instance.get.call();
                assert.equal(value, 2*initValue, "Value should be twice(logic2 is written like that)")
                return;
            })
        })
        .then(function(){
            return LogicContract2.get.call().then(function(value){
                assert.equal(value, 0, "value store in logic2 contract state should be zero");
                return;
            })
        })
    })
})
