const { deployments, ethers, getNamedAccounts } = require("hardhat");
const { assert, expect } = require("chai");

describe("FundMe", function () {
    // the code breaks if I add "async" before function keyword. Don't know why, will search about this.
    let fundMe;
    let deployer;
    let mockV3Aggregator;
    const sendValue = ethers.parseEther("1"); // 1 ETH
    beforeEach(async function () {
        deployer = (await getNamedAccounts()).deployer;
        const contracts = await deployments.fixture(["all"]);

        const signer = await ethers.getSigner(deployer);
        const fundMeAddress = contracts["FundMe"].address;
        fundMe = await ethers.getContractAt("FundMe", fundMeAddress, signer);
        mockV3Aggregator = contracts["MockV3Aggregator"];
    });

    describe("constructor", async function () {
        it("sets the aggregator addresses correctly", async function () {
            const response = await fundMe.priceFeed();
            assert.equal(response, mockV3Aggregator.address);
        });
    });

    describe("fund", async function () {
        it("Fails if you don't send enough ETH", async function () {
            await expect(fundMe.fund()).to.be.revertedWith(
                "Didn't send enough ETH!",
            );
        });
        it("Uptades the amount funded data structure", async function () {
            await fundMe.fund({ value: sendValue });
            const response = await fundMe.addressToAmountFunded(deployer);
            assert.equal(response.toString(), sendValue.toString());
        });
        it("Adds funder to array of funders", async function () {
            await fundMe.fund({ value: sendValue });
            const funder = await fundMe.funders(0);
            assert.equal(funder, deployer);
        });
    });
    describe("withdraw", async function () {
        beforeEach(async function () {
            await fundMe.fund({ value: sendValue }); // This will send money to our contract befor testing the withdraw function
        });

        it("Withdraw ETH from a single founder", async function () {
            // Arrange
            const startingFundMeBalance = await ethers.provider.getBalance(
                fundMe.target, //.address
            );
            const startingDeployerBalance =
                await ethers.provider.getBalance(deployer);
            // Act
            const transactionResponse = await fundMe.withdraw();
            const transactionReceipt = await transactionResponse.wait(1);
            const { gasUsed, gasPrice } = transactionReceipt;
            const gasCost = gasUsed * gasPrice;
            const endingFundMeBalance = await ethers.provider.getBalance(
                fundMe.target,
            );
            const endingDeployerBalance =
                await ethers.provider.getBalance(deployer);
            // gasCost

            // Assert
            assert.equal(endingFundMeBalance, 0);
            assert.equal(
                startingFundMeBalance + startingDeployerBalance,
                endingDeployerBalance + gasCost,
            );
        });
    });
});
