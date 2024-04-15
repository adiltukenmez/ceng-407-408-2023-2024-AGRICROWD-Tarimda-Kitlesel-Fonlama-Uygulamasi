const { getNamedAccounts, ethers } = require("hardhat");

async function main() {
    const { deployer } = await getNamedAccounts();
    const agricrowd = await ethers.getContract("Agricrowd", deployer);

    // Replace the project ID with the actual ID of the project you want to fund
    const projectId = 0; // Example project ID
    const fundingAmount = ethers.utils.parseEther("0.1"); // Amount to fund (0.1 ETH in this case)

    console.log(`Funding Project ${projectId}...`);
    const transactionResponse = await agricrowd.fundProject(projectId, {
        value: fundingAmount,
    });
    await transactionResponse.wait(1);
    console.log("Project Funded Successfully!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
