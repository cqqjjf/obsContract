const FomoInvest = artifacts.require("FomoInvest");

module.exports = function(deployer) {
  deployer.deploy(FomoInvest, "0x748805809ee80adf15ecf3ad80feb0c99bc27b4b");
};
