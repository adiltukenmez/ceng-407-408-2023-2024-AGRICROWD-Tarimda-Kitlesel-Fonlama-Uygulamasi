// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Agricrowd {
    struct Project {
        address investee; // Metamask address of the investee
        string projectName; // Name of the project
        uint256 fundingGoalUSD; // Funding goal for the project in USD
        uint256 fundingGoalETH; // Funding goal for the project in ETH
        uint256 amountFundedUSD; // Total amount funded so far in USD
        uint256 amountFundedETH; // Total amount funded so far in ETH
        uint256 amountDonatedUSD; // Total amount donated so far in USD
        uint256 amountDonatedETH; // Total amount donated so far in ETH
        uint256 rewardPercentage; // Reward Percentage of the Project
        mapping(address => uint256) funds; // Mapping of investor addresses to their contributions
        mapping(address => uint256) donations; // Mapping of investor addresses to their donations
        address[] funders; // Array to store addresses of funders
        address[] donors; // Array to store addresses of donors
    }

    mapping(address => uint[]) public investeeProjects; // Mapping of investee addresses to their project IDs
    mapping(uint => Project) public projects; // Mapping of project IDs to projects
    mapping(string => uint) public objectIdToProjectId; // Mapping of MongoDB ObjectId to smart contract project ID
    mapping(address => uint256) public totalRewards; // Total rewards earned by funders
    uint256 public numProjects; // Total number of projects
    AggregatorV3Interface internal s_ethUsdPriceFeed; // Chainlink ETH/USD price feed contract
    uint256 public ethUsdPriceDecimal = 10 ** 18; // 18 decimal places for Chainlink ETH/USD price feed
    uint256 public constant PLATFORM_COMMISSION_PERCENT = 5; // Platform commission percentage
    address private immutable i_platformOwner;
    uint256 public totalCommission;

    event ProjectCreated(
        uint projectId,
        address investee,
        string projectName,
        uint fundingGoalUSD,
        uint fundingGoalETH,
        uint256 rewardPercentage
    );

    event ProjectFunded(uint projectId, address investor, uint amount);
    event ProjectDonated(uint projectId, address invesotr, uint amount);
    event RewardSent(address funder, uint reward);

    constructor(address _ethUsdPriceFeedAddress) {
        s_ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeedAddress);
        i_platformOwner = msg.sender;
    }

    // Function to create a new project
    function createProject(string memory mongoDbObjectId, string memory _projectName, uint _fundingGoalETH, uint256 _rewardPercentage) external {
        uint projectId = numProjects++;
        Project storage newProject = projects[projectId];
        newProject.investee = msg.sender;
        newProject.projectName = _projectName; // Store project name
        newProject.fundingGoalUSD = ethToUsd(_fundingGoalETH);
        newProject.fundingGoalETH = _fundingGoalETH;
        newProject.amountFundedUSD = 0;
        newProject.amountFundedETH = 0;
        newProject.rewardPercentage = _rewardPercentage; // Store reward percentage
        investeeProjects[msg.sender].push(projectId);
        emit ProjectCreated(
            projectId,
            msg.sender,
            _projectName,
            newProject.fundingGoalUSD,
            _fundingGoalETH,
            _rewardPercentage
        );

        objectIdToProjectId[mongoDbObjectId] = projectId;
    }

    // Function to fund a project
    function fundProject(string memory mongoDbObjectId) external payable {
        uint projectId = objectIdToProjectId[mongoDbObjectId];
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        require(msg.value > 0, "Funding amount must be greater than 0");

        // Calculate platform commission
        uint platformCommission = (msg.value * PLATFORM_COMMISSION_PERCENT) / 100;
        uint fundedAmountAfterCommission = msg.value - platformCommission;

        // Update project data
        project.amountFundedETH += fundedAmountAfterCommission;
        project.amountFundedUSD += ethToUsd(fundedAmountAfterCommission);
        project.funds[msg.sender] += fundedAmountAfterCommission;
        
        // Add funder to the list if not already added
        if (project.funds[msg.sender] == fundedAmountAfterCommission) {
            project.funders.push(msg.sender);
        }

        // Update total commission
        totalCommission += platformCommission;

        // Transfer platform commission to platform address
        payable(i_platformOwner).transfer(platformCommission);

        emit ProjectFunded(projectId, msg.sender, fundedAmountAfterCommission);
    }

    // Function to donate a project
    function donateProject(string memory mongoDbObjectId) external payable {
        uint projectId = objectIdToProjectId[mongoDbObjectId];
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        require(msg.value > 0, "Donation amount must be greater than 0");

        // Update project data
        project.amountDonatedETH += msg.value;
        project.amountDonatedUSD += ethToUsd(msg.value);
        project.donations[msg.sender] += msg.value;

        // Add donor to the list if not already added
        if (project.donations[msg.sender] == msg.value) {
            project.donors.push(msg.sender);
        }

        // Also update the funded amounts since a donation is considered a form of funding
        project.amountFundedETH += msg.value;
        project.amountFundedUSD += ethToUsd(msg.value);

        emit ProjectDonated(projectId, msg.sender, msg.value);
    }

    // Function to withdraw funds once funding goal is reached
    function withdrawFunds(string memory mongoDbObjectId) external {
        uint projectId = objectIdToProjectId[mongoDbObjectId];
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
        payable(project.investee).transfer(amountToWithdraw);
    }

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
        string memory mongoDbObjectId
    ) external view returns (
        address investee, 
        uint fundingGoalUSD, 
        uint amountFundedUSD, 
        uint fundingGoalETH, 
        uint amountFundedETH, 
        uint amountDonatedUSD, 
        uint amountDonatedETH,
        address[] memory funders,
        address[] memory donors
    ) {
        uint projectId = objectIdToProjectId[mongoDbObjectId];
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        return (
            project.investee,
            project.fundingGoalUSD,
            project.amountFundedUSD,
            project.fundingGoalETH,
            project.amountFundedETH,
            project.amountDonatedUSD,
            project.amountDonatedETH,
            project.funders,
            project.donors
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

    // Function to get funders and their funds for a project
    function getFundersAndFunds(string memory mongoDbObjectId) external view returns (address[] memory, uint[] memory) {
        uint projectId = objectIdToProjectId[mongoDbObjectId];
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        uint numFunders = project.funders.length;
        address[] memory funders = new address[](numFunders);
        uint[] memory funds = new uint[](numFunders);
        for (uint i = 0; i < numFunders; i++) {
            address funder = project.funders[i];
            uint amountFunded = project.funds[funder];
            funders[i] = funder;
            funds[i] = amountFunded;
        }
        return (funders, funds);
    }

    // Function to send rewards to funders
    function sendReward(string memory mongoDbObjectId) external payable {
        uint projectId = objectIdToProjectId[mongoDbObjectId];
        require(projectId < numProjects, "Invalid project ID");
        Project storage project = projects[projectId];
        require(msg.sender == project.investee, "Only project owner can send rewards");
        require(project.amountFundedETH >= project.fundingGoalETH, "Funding goal not reached");

        // Calculate total reward amount needed
        uint totalRewardAmount = 0;
        for (uint i = 0; i < project.funders.length; i++) {
            address funder = project.funders[i];
            uint fundAmount = project.funds[funder];
            uint rewardAmount = (fundAmount * project.rewardPercentage) / 100; 
            totalRewards[funder] += rewardAmount;
            totalRewardAmount += (fundAmount + rewardAmount);
        }

        // Ensure the project owner sent enough ETH to cover the total rewards  
        require(msg.value >= totalRewardAmount, "Insufficient reward amount sent by project owner");

        // Distribute rewards to funders
        for (uint i = 0; i < project.funders.length; i++) {
            address funder = project.funders[i];
            uint fundAmount = project.funds[funder];
            uint rewardAmount = (fundAmount * project.rewardPercentage) / 100;
            payable(funder).transfer(fundAmount + rewardAmount);
        }

        // If there's any excess ETH sent by the project owner, refund it
        uint excessAmount = msg.value - totalRewardAmount;
        if (excessAmount > 0) {
            payable(project.investee).transfer(excessAmount);
        }
    }

    // Function to get investments made by a specific address
    function getInvestmentsByAddress(address investor) external view returns (string[] memory, uint[] memory, uint[] memory, string[] memory) {
        uint[] memory amounts = new uint[](numProjects);
        uint[] memory rewards = new uint[](numProjects);
        string[] memory projectNames = new string[](numProjects);
        string[] memory objectIds = new string[](numProjects);

        uint count = 0;
        for (uint i = 0; i < numProjects; i++) {
            Project storage project = projects[i];
            if (project.funds[investor] > 0) {
                amounts[count] = project.funds[investor];
                rewards[count] = (project.funds[investor] * project.rewardPercentage) / 100; // Calculate reward directly in the return statement
                projectNames[count] = project.projectName;
                count++;
            }
        }

        // Trim arrays to actual size
        assembly {
            mstore(amounts, count)
            mstore(rewards, count)
            mstore(projectNames, count)
        }

        return (objectIds, amounts, rewards, projectNames);
    }
}

