const GovernorAlpha = artifacts.require("GovernorAlpha.sol");
const Timelock = artifacts.require("Timelock.sol");
// const Comp = artifacts.require("Comp.sol");
const CompProxy = artifacts.require("CompProxy.sol");
const CompLogic = artifacts.require("CompLogic.sol");
const web3Utils = require("web3-utils");
const ethJsUtil = require("ethereumjs-util");
const Web3 = require("web3");

module.exports = async function (deployer, network, accounts) {
  // only for testing, change when the networks change
  if (network == "development") {
    const web3 = new Web3("http://127.0.0.1:8545/");

    let guardianAddress = accounts[5];
    let compAdmin = accounts[4];
    let bridge = accounts[11];
    let transactionCount = await web3.eth.getTransactionCount(guardianAddress);
    var futureAddress = ethJsUtil.bufferToHex(
      ethJsUtil.generateAddress(guardianAddress, transactionCount)
    );
    console.log("pre-generated governor alpha address", futureAddress);
    let timelockAdmin = futureAddress;

    let delay = new web3Utils.BN("259200");
    // only for testing
    await deployer
      .deploy(Timelock, timelockAdmin, delay)
      .then(function () {
        return deployer.deploy(CompLogic);
      })
      .then(function (compLogic) {
        return deployer.deploy(CompProxy, compLogic.address);
      })
      // .then(function () {
      //   return deployer.deploy(Comp, compAdmin, bridge);
      // })
      .then(function () {
        return deployer.deploy(
          GovernorAlpha,
          Timelock.address,
          CompProxy.address,
          guardianAddress,
          {from: guardianAddress}
        );
      })
      .then(function () {
        console.log("*****************************************");
        console.log("Timelock.address", Timelock.address);
        console.log("CompProxy.address", CompProxy.address);
        console.log("GovernorAlpha.address", GovernorAlpha.address);
        console.log("compAdmin", compAdmin);
        console.log("guardianAddress", guardianAddress);
        console.log("timelockAdmin", timelockAdmin);
        console.log("delay", delay);
        console.log("*****************************************");
        return;
      });
  } else if (network == "private") {
    // console.log(accounts);
    // const web3 = new Web3("http://68.183.87.16:8545/");
    // let guardianAddress = accounts[2];
    // let compAdmin = accounts[1];
    // let transactionCount = await web3.eth.getTransactionCount(guardianAddress);
    // var futureAddress = ethJsUtil.bufferToHex(
    //   ethJsUtil.generateAddress(guardianAddress, transactionCount)
    // );
    // console.log("pre-generated governor alpha address", futureAddress);
    // let timelockAdmin = futureAddress;
    // let delay = new web3Utils.BN("259200");
    // await deployer
    //   .deploy(Timelock, timelockAdmin, delay)
    //   .then(function () {
    //     return deployer.deploy(Comp, compAdmin);
    //   })
    //   .then(function () {
    //     return deployer.deploy(
    //       GovernorAlpha,
    //       Timelock.address,
    //       Comp.address,
    //       guardianAddress,
    //       {from: guardianAddress}
    //     );
    //   })
    //   .then(function () {
    //     console.log("*****************************************");
    //     console.log(
    //       "Timelock.address",
    //       Timelock.address,
    //       "(Timelock contract)"
    //     );
    //     console.log(
    //       "Pond.address",
    //       Comp.address,
    //       "(The erc20 token for governance)"
    //     );
    //     console.log(
    //       "GovernorAlpha.address",
    //       GovernorAlpha.address,
    //       "(Governance Contract)"
    //     );
    //     console.log(
    //       "pondAdmin",
    //       compAdmin,
    //       "erc20 admin address. all the erc20 tokens are currently in this address"
    //     );
    //     console.log(
    //       "guardianAddress",
    //       guardianAddress,
    //       "governance contract's admin"
    //     );
    //     console.log(
    //       "timelockAdmin",
    //       timelockAdmin,
    //       "At time of deployment is same as GovernonAlpha address"
    //     );
    //     console.log("delay", delay);
    //     console.log("*****************************************");
    //     return;
    //   });
  }
};
