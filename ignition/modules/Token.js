const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("Token", (m) => {
  const token = m.contract("XRPEFTToken");

  m.call(token, "decimals", []);

  return { token };

});
