// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Agricrowd {
    struct Project {
        address investee; // Metamask address of the investee
        uint256 fundingGoalUSD; // Funding goal for the project in USD
        uint256 fundingGoalETH; // Funding goal for the project in ETH
        uint256 amountFundedUSD; // Total amount funded so far in USD
        uint256 amountFundedETH; // Total amount funded so far in ETH
        uint256 amountDonatedUSD; // Total amount donated so far in USD
        uint256 amountDonatedETH; // Total amount donated so far in ETH
        mapping(address => uint256) funds; // Mapping of investor addresses to their contributions
        mapping(address => uint256) donations; //Mapping of investor addresses to their donations
    }

    mapping(address => uint[]) public investeeProjects; // Mapping of investee addresses to their project IDs
    mapping(uint => Project) public projects; // Mapping of project IDs to projects
    uint256 public numProjects; // Total number of projects
    AggregatorV3Interface internal s_ethUsdPriceFeed; // Chainlink ETH/USD price feed contract
    uint256 public ethUsdPriceDecimal = 10 ** 18; // 18 decimal places for Chainlink ETH/USD price feed
    uint256 public constant PLATFORM_COMMISSION_PERCENT = 5; // Platform commission percentage
    address private immutable i_platformOwner;
    uint256 public totalCommission;

    event ProjectCreated(
        uint projectId,
        address investee,
        uint fundingGoalUSD,
        uint fundingGoalETH
    );
    event ProjectFunded(uint projectId, address investor, uint amount);
    event ProjectDonated(uint projectId, address invesotr, uint amount);

    //event CommissionWithdrawn(address indexed recipient, uint amount);

    constructor(address _ethUsdPriceFeedAddress) {
        s_ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddress);
        i_platformOwner = msg.sender;
    }

    // Function to create a new project
    function createProject(uint _fundingGoalETH) external {
        uint projectId = numProjects++;
        Project storage newProject = projects[projectId];
        newProject.investee = msg.sender;
        newProject.fundingGoalUSD = ethToUsd(_fundingGoalETH);
        newProject.fundingGoalETH = _fundingGoalETH; // Convert USD to ETH
        newProject.amountFundedUSD = 0;
        newProject.amountFundedETH = 0;
        investeeProjects[msg.sender].push(projectId);
        emit ProjectCreated(
            projectId,
            msg.sender,
            newProject.fundingGoalUSD,
            _fundingGoalETH
        );
    }

    // Function to fund a project
    function fundProject(uint projectId) external payable {
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        require(msg.value > 0, "Funding amount must be greater than 0");

        // Calculate platform commission
        uint platformCommission = (msg.value * PLATFORM_COMMISSION_PERCENT) /
            100;
        uint fundedAmountAfterCommission = msg.value - platformCommission;

        // Update project data
        project.amountFundedETH += fundedAmountAfterCommission;
        project.amountFundedUSD += ethToUsd(fundedAmountAfterCommission);
        project.funds[msg.sender] += fundedAmountAfterCommission;

        // Update total commission
        totalCommission += platformCommission;

        // Transfer platform commission to platform address
        payable(i_platformOwner).transfer(platformCommission);

        emit ProjectFunded(projectId, msg.sender, fundedAmountAfterCommission);
    }

    // Function to donate a project
    function donateProject(uint projectId) external payable {
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        require(msg.value > 0, "Donation amount must be greater than 0");
        project.amountDonatedETH += msg.value;
        project.amountDonatedUSD += ethToUsd(msg.value);
        project.donations[msg.sender] += msg.value;

        emit ProjectDonated(projectId, msg.sender, msg.value);
    }

    // Function to withdraw funds once funding goal is reached
    function withdrawFunds(uint projectId) external {
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        require(
            project.amountFundedETH >= project.fundingGoalETH,
            "Funding goal not reached"
        );
        require(
            msg.sender == project.investee,
            "Only project owner can withdraw funds"
        );

        // Transfer funds to project owner
        uint amountToWithdraw = project.amountFundedETH;
        project.amountFundedETH = 0; // Reset project's amount funded
        project.amountFundedUSD = 0; // Reset project's amount funded in USD
        payable(project.investee).transfer(amountToWithdraw);
    }

    /*
    // Function to withdraw commission fees
    function withdrawCommission() external {
        require(
            msg.sender == i_platformOwner,
            "Only platform owner can withdraw commission"
        );
        require(totalCommission > 0, "No commission available to withdraw");

        uint commissionToWithdraw = totalCommission;
        totalCommission = 0; // Reset total commission after withdrawal

        payable(i_platformOwner).transfer(commissionToWithdraw);

        emit CommissionWithdrawn(i_platformOwner, commissionToWithdraw);
    }
    */

    // Function to get the total commission amount
    function getTotalCommissionAmount() external view returns (uint256) {
        return totalCommission;
    }

    // Function to convert USD to ETH
    function usdToEth(uint _usdAmount) internal view returns (uint) {
        (, int price, , , ) = s_ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH/USD price");
        uint ethAmount = (uint(price) * _usdAmount) / ethUsdPriceDecimal;
        return ethAmount;
    }

    // Function to convert ETH to USD
    function ethToUsd(uint _ethAmount) internal view returns (uint) {
        (, int price, , , ) = s_ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH/USD price");
        uint usdAmount = (_ethAmount * ethUsdPriceDecimal) / uint(price);
        return usdAmount;
    }

    // Function to get details of a project
    function getProjectDetails(
        uint projectId
    ) external view returns (address, uint, uint, uint, uint, uint, uint) {
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        return (
            project.investee,
            project.fundingGoalUSD,
            project.amountFundedUSD,
            project.fundingGoalETH,
            project.amountFundedETH,
            project.amountDonatedUSD,
            project.amountDonatedETH
        );
    }

    // Function to get projects created by an investee
    function getInvesteeProjects(
        address investee
    ) external view returns (uint[] memory) {
        return investeeProjects[investee];
    }

    function getPriceFeed() external view returns (AggregatorV3Interface) {
        return s_ethUsdPriceFeed;
    }

    function getPlatformOwner() external view returns (address) {
        return i_platformOwner;
    }
}
