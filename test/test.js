const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("XRPEFTToken", function () {
  let Token, token, owner, addr1, addr2;

  beforeEach(async function () {
    // Deploy contract
    [owner, addr1, addr2, taxWallet, teamWallet] = await ethers.getSigners();
    Token = await ethers.getContractFactory("XRPEFTToken");
    token = await Token.deploy(owner.address);

    // Initial setup
    await token.updateTaxWallet(taxWallet.address);
  });

  it("Should set the correct name and symbol", async function () {
    expect(await token.name()).to.equal("XRP ETF Token");
    expect(await token.symbol()).to.equal("XRPETF");
  });

  it("Should mint total supply to owner and team wallet", async function () {
    const totalSupply = await token.totalSupply();
    const ownerBalance = await token.balanceOf(owner.address);
    const teamWalletBalance = await token.balanceOf(teamWallet.address);

    expect(totalSupply).to.equal(ethers.utils.parseEther("1000000000"));
    expect(ownerBalance).to.equal(ethers.utils.parseEther("950000000"));
    expect(teamWalletBalance).to.equal(ethers.utils.parseEther("50000000"));
  });

  it("Should allow transfers between accounts", async function () {
    await token.transfer(addr1.address, ethers.utils.parseEther("100"));
    const addr1Balance = await token.balanceOf(addr1.address);
    expect(addr1Balance).to.equal(ethers.utils.parseEther("100"));
  });

  it("Should enforce trading restrictions when trading is disabled", async function () {
    await expect(
      token
        .connect(addr1)
        .transfer(addr2.address, ethers.utils.parseEther("50"))
    ).to.be.revertedWith("Trading is not enabled");
  });

  it("Should enable trading and allow transfers", async function () {
    await token.enableTrading();
    await token
      .connect(addr1)
      .transfer(addr2.address, ethers.utils.parseEther("50"));
    const addr2Balance = await token.balanceOf(addr2.address);
    expect(addr2Balance).to.equal(ethers.utils.parseEther("50"));
  });

  it("Should calculate fees for transfers to AMM pairs", async function () {
    await token.enableTrading();
    await token.transfer(addr1.address, ethers.utils.parseEther("100"));

    // Simulate a transfer with buy tax
    await token
      .connect(addr1)
      .transfer(addr2.address, ethers.utils.parseEther("100"));
    const addr2Balance = await token.balanceOf(addr2.address);
    const fee = ethers.utils.parseEther("2.5"); // 2.5% buy tax

    expect(addr2Balance).to.equal(ethers.utils.parseEther("97.5"));
    const taxWalletBalance = await token.balanceOf(taxWallet.address);
    expect(taxWalletBalance).to.equal(fee);
  });

  it("Should allow whitelisting and exclude wallets from fees", async function () {
    await token.whiteListWallet(addr1.address);
    const isWhitelisted = await token._isExcludedFromFee(addr1.address);
    expect(isWhitelisted).to.be.true;

    // Whitelisted wallet should not be charged fees
    await token.transfer(addr1.address, ethers.utils.parseEther("100"));
    await token
      .connect(addr1)
      .transfer(addr2.address, ethers.utils.parseEther("100"));
    const addr2Balance = await token.balanceOf(addr2.address);
    expect(addr2Balance).to.equal(ethers.utils.parseEther("100"));
  });

  it("Should allow updating buy and sell taxes", async function () {
    await token.updateTax(300, 600);
    const buyTax = await token.buyTax();
    const sellTax = await token.sellTax();

    expect(buyTax).to.equal(300); // 3%
    expect(sellTax).to.equal(600); // 6%
  });

  it("Should allow enabling and disabling fee burn", async function () {
    await token.enableFeeBurn();
    expect(await token.feeBurnEnabled()).to.be.true;

    await token.disableFeeBurn();
    expect(await token.feeBurnEnabled()).to.be.false;
  });

  it("Should withdraw BNB from the contract", async function () {
    await addr1.sendTransaction({
      to: token.address,
      value: ethers.utils.parseEther("1"),
    });

    const contractBalance = await ethers.provider.getBalance(token.address);
    expect(contractBalance).to.equal(ethers.utils.parseEther("1"));

    await token.withdrawBNB();
    const newContractBalance = await ethers.provider.getBalance(token.address);
    expect(newContractBalance).to.equal(0);
  });

  it("Should withdraw BEP20 tokens from the contract", async function () {
    // Deploy a mock token and transfer some to the contract
    const MockToken = await ethers.getContractFactory("MockToken");
    const mockToken = await MockToken.deploy();
    await mockToken.transfer(token.address, ethers.utils.parseEther("100"));

    const contractMockBalance = await mockToken.balanceOf(token.address);
    expect(contractMockBalance).to.equal(ethers.utils.parseEther("100"));

    await token.withdrawBEP20(mockToken.address);
    const newContractMockBalance = await mockToken.balanceOf(token.address);
    expect(newContractMockBalance).to.equal(0);
  });
});
