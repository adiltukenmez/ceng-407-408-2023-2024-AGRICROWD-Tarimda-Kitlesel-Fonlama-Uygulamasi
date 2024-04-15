const { ethers, deployments, getNamedAccounts } = require("hardhat");
const { assert, expect } = require("chai");
const { developmentChains } = require("../../helper-hardhat-config");

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Agricrowd", function () {
          let agricrowd;
          let deployer;
          let mockV3Aggregator;
          const sendValue = ethers.parseEther("2"); // 2 ETH

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer;
              const contracts = await deployments.fixture(["all"]);

              const signer = await ethers.getSigner(deployer);
              const agricrowdAddress = contracts["Agricrowd"].address;
              agricrowd = await ethers.getContractAt(
                  "Agricrowd",
                  agricrowdAddress,
                  signer,
              );
              mockV3Aggregator = contracts["MockV3Aggregator"];
          });

          describe("constructor", async function () {
              it("sets the aggregator addresses correctly", async function () {
                  const response = await agricrowd.getPriceFeed();
                  assert.equal(response, mockV3Aggregator.address);
              });
          });

          describe("createProject", async function () {
              it("should create a project with valid funding goal", async function () {
                  await agricrowd.createProject(ethers.parseEther("1000"));
                  const projectDetails = await agricrowd.getProjectDetails(0);
                  assert.equal(projectDetails[0], deployer);
                  assert.equal(projectDetails[3], ethers.parseEther("1000"));
              });
          });

          describe("fundProject", async function () {
              beforeEach(async function () {
                  await agricrowd.createProject(ethers.parseEther("1000"));
              });

              it("should fund a project successfully", async function () {
                  await agricrowd
                      .connect(await ethers.getSigner(deployer))
                      .fundProject(0, { value: sendValue });
                  const projectDetails = await agricrowd.getProjectDetails(0);
                  assert.equal(
                      projectDetails[4].toString(),
                      ethers.parseEther("1.9").toString(),
                  );
              });
          });

          describe("donateProject", async function () {
              beforeEach(async function () {
                  await agricrowd.createProject(ethers.parseEther("1000"));
              });

              it("should donate a project successfully", async function () {
                  await agricrowd
                      .connect(await ethers.getSigner(deployer))
                      .donateProject(0, { value: sendValue });
                  const projectDetails = await agricrowd.getProjectDetails(0);
                  assert.equal(
                      projectDetails[6].toString(),
                      ethers.parseEther("2").toString(),
                  );
              });
          });

          describe("withdrawFunds", async function () {
              beforeEach(async function () {
                  await agricrowd.createProject(ethers.parseEther("1000"));
                  await agricrowd
                      .connect(await ethers.getSigner(deployer))
                      .fundProject(0, { value: sendValue });
              });

              it("should allow project owner to withdraw funds", async function () {
                  // Increase funding until the funding goal is reached
                  const fundingGoal = ethers.parseEther("1000");
                  while (true) {
                      const projectDetails =
                          await agricrowd.getProjectDetails(0);
                      if (projectDetails[4] >= fundingGoal) break;
                      await agricrowd
                          .connect(await ethers.getSigner(deployer))
                          .fundProject(0, { value: sendValue });
                  }

                  // Withdraw funds
                  const initialBalance =
                      await ethers.provider.getBalance(deployer);
                  await agricrowd.withdrawFunds(0);
                  const finalBalance =
                      await ethers.provider.getBalance(deployer);
                  assert.isAbove(finalBalance, initialBalance);
              });
          });

          /*
          describe("withdrawCommission", async function () {
              it("should allow platform owner to withdraw commission", async function () {
                  const initialBalance =
                      await ethers.provider.getBalance(deployer);
                  await agricrowd.createProject(ethers.utils.parseEther("1000"));
                  await agricrowd
                      .connect(await ethers.getSigner(deployer))
                      .fundProject(0, { value: sendValue });
                  await agricrowd.withdrawCommission();
                  const finalBalance =
                      await ethers.provider.getBalance(deployer);
                  assert.isAbove(finalBalance, initialBalance);
              });

              it("should revert if non-owner tries to withdraw commission", async function () {
                  await expect(
                      agricrowd.withdrawCommission(),
                  ).to.be.revertedWith(
                      "Only platform owner can withdraw commission",
                  );
              });

              it("should revert if there is no commission to withdraw", async function () {
                  await expect(
                      agricrowd
                          .connect(await ethers.getSigner(deployer))
                          .withdrawCommission(),
                  ).to.be.revertedWith("No commission available to withdraw");
              });
          })
          */
      });
